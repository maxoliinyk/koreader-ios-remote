//
//  VolumeButtonExperiment.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import AVFoundation
import MediaPlayer
import Observation
import RemoteCore
import SwiftUI
import UIKit

enum VolumeCaptureMode: String, CaseIterable, Identifiable {
    case rawButtons = "Raw Buttons"
    case centered = "Keep Centered"
    case systemVolume = "System Volume"

    var id: Self { self }

    var detail: String {
        switch self {
        case .rawButtons:
            "Uses private UIKit button events. System volume should stay fixed, and presses should still work at 0% and 100%."
        case .centered:
            "Uses public volume observation, then returns volume to 50% after each press so neither limit is reached."
        case .systemVolume:
            "Uses public volume observation and changes the real volume. Presses cannot be detected past 0% or 100%."
        }
    }
}

enum NowPlayingButtonStyle: String, CaseIterable, Identifiable {
    case tracks = "Previous / Next"
    case tenSeconds = "10-Second Arrows"

    var id: Self { self }
}

@MainActor
@Observable
final class VolumeButtonExperiment: NSObject {
    private(set) var isRunning = false
    private(set) var privateCaptureEnabled = false
    private(set) var outputVolume = AVAudioSession.sharedInstance().outputVolume
    private(set) var lastInput = "None"
    private(set) var lastResult = "Idle"
    private(set) var volumeEventCount = 0
    private(set) var remoteCommandCount = 0

    var volumeMode: VolumeCaptureMode = .rawButtons {
        didSet { if isRunning { applyVolumeMode() } }
    }
    var nowPlayingStyle: NowPlayingButtonStyle = .tracks {
        didSet {
            if isRunning {
                installRemoteCommands()
                publishNowPlayingState()
            }
        }
    }

    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored private var audioNotificationTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var buttonNotificationTokens: [NSObjectProtocol] = []
    @ObservationIgnored private var remoteCommandTokens: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var expectedProgrammaticVolume: Float?
    @ObservationIgnored private var adjustmentGeneration = 0
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private let client = KindleClient()
    @ObservationIgnored private let storage = PairingStore()
    @ObservationIgnored let systemVolumeView: MPVolumeView = {
        let view = MPVolumeView(frame: .zero)
        view.alpha = 0.01
        return view
    }()

    func start() {
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try startAudioEngine()
            installVolumeObservation(session)
            installAudioNotifications(session)
            isRunning = true
            applyVolumeMode()
            installRemoteCommands()
            publishNowPlayingState()
            outputVolume = session.outputVolume
            lastResult = "Session active — lock the phone and test"
        } catch {
            stop()
            lastResult = "Start failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        setPrivateCapture(false)
        observation = nil
        audioNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        audioNotificationTokens.removeAll()
        removeRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        player.stop()
        engine.stop()
        engine.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    func send(_ action: RemoteAction, source: String) {
        lastInput = source
        Task { await perform(action, source: source) }
    }

    private func perform(_ action: RemoteAction, source: String) async {
        do {
            guard let configuration = try storage.load() else {
                lastResult = "Pair KOReader in the normal app first"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            _ = try await client.send(action, using: configuration)
            let name = action == .nextPage ? "Next" : "Previous"
            lastResult = "\(name) sent from \(source)"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            lastResult = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func startAudioEngine() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frameCount: AVAudioFrameCount = 44_100
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let samples = buffer.floatChannelData?[0] {
            for frame in 0..<Int(frameCount) {
                samples[frame] = sin(Float(frame) * 2 * .pi * 220 / 44_100) * 0.000_001
            }
        }
        if player.engine == nil { engine.attach(player) }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        try engine.start()
        player.play()
    }

    private func applyVolumeMode() {
        switch volumeMode {
        case .rawButtons:
            setPrivateCapture(true)
        case .centered:
            setPrivateCapture(false)
            recenterSystemVolume()
        case .systemVolume:
            setPrivateCapture(false)
        }
    }

    private func installVolumeObservation(_ session: AVAudioSession) {
        observation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
            let oldValue = change.oldValue ?? 0
            let newValue = change.newValue ?? oldValue
            Task { @MainActor in
                guard let self else { return }
                self.outputVolume = newValue
                if let expected = self.expectedProgrammaticVolume, abs(newValue - expected) < 0.01 {
                    self.expectedProgrammaticVolume = nil
                    return
                }
                guard newValue != oldValue, self.volumeMode != .rawButtons else {
                    return
                }

                let wentUp = newValue > oldValue
                let action: RemoteAction = wentUp ? .nextPage : .previousPage
                let source = wentUp ? "Volume Up" : "Volume Down"
                self.volumeEventCount += 1
                self.lastInput = source
                if self.volumeMode == .centered { self.recenterSystemVolume() }
                await self.perform(action, source: source)
            }
        }
    }

    private func recenterSystemVolume() {
        systemVolumeView.layoutIfNeeded()
        let slider = findVolumeSlider(in: systemVolumeView)
        let currentValue = slider?.value ?? outputVolume
        guard abs(currentValue - 0.5) > 0.001 else { return }

        adjustmentGeneration += 1
        let generation = adjustmentGeneration
        expectedProgrammaticVolume = 0.5
        if let slider {
            slider.setValue(0.5, animated: false)
            slider.sendActions(for: .valueChanged)
        } else if !setSystemVolumeUsingPrivateFallback(0.5) {
            lastResult = "No system volume setter is available"
            expectedProgrammaticVolume = nil
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            if adjustmentGeneration == generation { expectedProgrammaticVolume = nil }
        }
    }

    private func findVolumeSlider(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider { return slider }
        for subview in view.subviews {
            if let slider = findVolumeSlider(in: subview) { return slider }
        }
        return nil
    }

    private func setSystemVolumeUsingPrivateFallback(_ value: Float) -> Bool {
        let player = MPMusicPlayerController.systemMusicPlayer
        for selectorName in ["setVolumePrivate:", "setVolume:"] {
            let selector = NSSelectorFromString(selectorName)
            guard player.responds(to: selector), let implementation = player.method(for: selector) else {
                continue
            }
            typealias Setter = @convention(c) (AnyObject, Selector, Float) -> Void
            unsafeBitCast(implementation, to: Setter.self)(player, selector, value)
            return true
        }
        return false
    }

    private func setPrivateCapture(_ enabled: Bool) {
        guard enabled != privateCaptureEnabled else { return }
        let selector = NSSelectorFromString("setWantsVolumeButtonEvents:")
        guard UIApplication.shared.responds(to: selector),
              let implementation = UIApplication.shared.method(for: selector) else {
            lastResult = "Private volume-button selector is unavailable"
            privateCaptureEnabled = false
            return
        }

        typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
        unsafeBitCast(implementation, to: Setter.self)(UIApplication.shared, selector, enabled)
        enabled ? installPrivateButtonNotifications() : removePrivateButtonNotifications()
        privateCaptureEnabled = enabled
    }

    private func installPrivateButtonNotifications() {
        removePrivateButtonNotifications()
        let center = NotificationCenter.default
        let inputs: [(String, String, RemoteAction)] = [
            ("_UIApplicationVolumeUpButtonDownNotification", "Volume Up", .nextPage),
            ("_UIApplicationVolumeDownButtonDownNotification", "Volume Down", .previousPage),
        ]
        for (name, label, action) in inputs {
            buttonNotificationTokens.append(center.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.volumeEventCount += 1
                    self.lastInput = label
                    await self.perform(action, source: "Raw \(label)")
                }
            })
        }
    }

    private func removePrivateButtonNotifications() {
        buttonNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        buttonNotificationTokens.removeAll()
    }

    private func installAudioNotifications(_ session: AVAudioSession) {
        audioNotificationTokens.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lastResult = "Audio session interrupted" }
        })
        audioNotificationTokens.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lastResult = "Audio route changed" }
        })
    }

    private func installRemoteCommands() {
        removeRemoteCommands()
        let center = MPRemoteCommandCenter.shared()
        let allCommands = [
            center.nextTrackCommand,
            center.previousTrackCommand,
            center.skipForwardCommand,
            center.skipBackwardCommand,
        ]
        allCommands.forEach { $0.isEnabled = false }

        switch nowPlayingStyle {
        case .tracks:
            register(center.previousTrackCommand, action: .previousPage, source: "Now Playing Previous")
            register(center.nextTrackCommand, action: .nextPage, source: "Now Playing Next")
        case .tenSeconds:
            center.skipBackwardCommand.preferredIntervals = [10]
            center.skipForwardCommand.preferredIntervals = [10]
            register(center.skipBackwardCommand, action: .previousPage, source: "Now Playing Back 10")
            register(center.skipForwardCommand, action: .nextPage, source: "Now Playing Forward 10")
        }
    }

    private func register(_ command: MPRemoteCommand, action: RemoteAction, source: String) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remoteCommandCount += 1
                await self.perform(action, source: source)
            }
            return .success
        }
        remoteCommandTokens.append((command, token))
    }

    private func removeRemoteCommands() {
        remoteCommandTokens.forEach { command, token in command.removeTarget(token) }
        remoteCommandTokens.removeAll()
    }

    private func publishNowPlayingState() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "KORemote",
            MPMediaItemPropertyArtist: "Previous and Next turn KOReader pages",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        switch nowPlayingStyle {
        case .tracks:
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = 3
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = 1
        case .tenSeconds:
            info[MPMediaItemPropertyPlaybackDuration] = 86_400.0
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 43_200.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }
}

struct SystemVolumeView: UIViewRepresentable {
    let volumeView: MPVolumeView

    func makeUIView(context: Context) -> MPVolumeView { volumeView }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
