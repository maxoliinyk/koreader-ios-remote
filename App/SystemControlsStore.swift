//
//  SystemControlsStore.swift
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

@MainActor
@Observable
final class SystemControlsStore {
    private(set) var lastError: String?

    var usesVolumeButtons: Bool {
        didSet {
            defaults.set(usesVolumeButtons, forKey: Keys.usesVolumeButtons)
            reconcile()
        }
    }

    var capturesMediaControls: Bool {
        didSet {
            defaults.set(capturesMediaControls, forKey: Keys.capturesMediaControls)
            reconcile()
        }
    }

    @ObservationIgnored let volumeView: MPVolumeView = {
        let view = MPVolumeView(frame: .zero)
        view.alpha = 0.01
        return view
    }()

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let audioPlayer = AVAudioPlayerNode()
    @ObservationIgnored private let client = KindleClient()
    @ObservationIgnored private let storage = PairingStore()
    @ObservationIgnored private let profile: DistributionProfile
    @ObservationIgnored private var hasActivated = false
    @ObservationIgnored private var isAppActive = true
    @ObservationIgnored private var isSessionRunning = false
    @ObservationIgnored private var volumeObservation: NSKeyValueObservation?
    @ObservationIgnored private var remoteCommandTokens: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var expectedVolume: Float?
#if DEBUG && targetEnvironment(simulator)
    @ObservationIgnored private var didRunSimulatorVolumeAction = false
#endif

    init(defaults: UserDefaults = .standard, profile: DistributionProfile = .current) {
        self.defaults = defaults
        self.profile = profile
        usesVolumeButtons = defaults.bool(forKey: Keys.usesVolumeButtons)
        capturesMediaControls = profile.supportsMediaControls
            ? defaults.bool(forKey: Keys.capturesMediaControls)
            : false
    }

    func activate() {
        hasActivated = true
        reconcile()
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        isAppActive = phase == .active
        reconcile()
    }

    private func reconcile() {
        guard hasActivated else { return }
        lastError = nil

        let shouldCaptureVolume = usesVolumeButtons
            && (isAppActive || profile.keepsVolumeCaptureWhileInactive)
        let shouldCaptureMedia = capturesMediaControls && profile.supportsMediaControls

        if shouldCaptureVolume || shouldCaptureMedia {
            startSessionIfNeeded()
        }

        shouldCaptureVolume ? installVolumeCapture() : removeVolumeCapture()
        shouldCaptureMedia ? installMediaControls() : removeMediaControls()

        if !shouldCaptureVolume, !shouldCaptureMedia {
            stopSession()
        }
    }

    private func startSessionIfNeeded() {
        if isSessionRunning {
            guard profile.keepsVolumeCaptureWhileInactive, !audioEngine.isRunning else { return }
            stopSession()
        }

        do {
            let session = AVAudioSession.sharedInstance()
            if profile.keepsVolumeCaptureWhileInactive {
                try session.setCategory(.playback, mode: .default)
            } else {
                try session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
            }
            try session.setActive(true)
            isSessionRunning = true
            if profile.keepsVolumeCaptureWhileInactive {
                try startAudioEngine()
            }
        } catch {
            stopSession()
            lastError = String(localized: "Audio controls could not start. Turn them off and on to retry.")
            Feedback.error()
        }
    }

    private func stopSession() {
        guard isSessionRunning else { return }
        removeVolumeCapture()
        removeMediaControls()
        audioPlayer.stop()
        audioEngine.stop()
        audioEngine.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isSessionRunning = false
    }

    private func startAudioEngine() throws {
        let sampleRate = 44_100.0
        let frameCount: AVAudioFrameCount = 44_100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let samples = buffer.floatChannelData?[0] {
            for frame in 0..<Int(frameCount) {
                samples[frame] = sin(Float(frame) * 2 * .pi * 220 / Float(sampleRate)) * 0.000_001
            }
        }

        if audioPlayer.engine == nil {
            audioEngine.attach(audioPlayer)
        }
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: format)
        audioPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        try audioEngine.start()
        audioPlayer.play()
    }

    private func installVolumeCapture() {
        guard isSessionRunning, volumeObservation == nil else { return }

        let session = AVAudioSession.sharedInstance()
        volumeObservation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            let oldValue = change.oldValue ?? 0
            let newValue = change.newValue ?? oldValue
            Task { @MainActor in
                guard let self, self.usesVolumeButtons, self.isSessionRunning, self.volumeObservation != nil else { return }
                let expectedVolume = self.expectedVolume
                if let expectedVolume, abs(newValue - expectedVolume) < 0.01 {
                    self.expectedVolume = nil
                    return
                }
                guard let action = VolumeButtonAction.remoteAction(
                    from: oldValue,
                    to: newValue,
                    ignoring: expectedVolume
                ) else { return }
                self.recenterVolume()
                await self.send(action)
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard isSessionRunning, volumeObservation != nil else { return }
            recenterVolume()
        }
    }

    private func removeVolumeCapture() {
        volumeObservation = nil
        expectedVolume = nil
    }

    private func recenterVolume() {
        volumeView.layoutIfNeeded()
        guard let slider = volumeSlider(in: volumeView) else { return }
        guard abs(slider.value - 0.5) > 0.001 else { return }

        expectedVolume = 0.5
        slider.setValue(0.5, animated: false)
        slider.sendActions(for: .valueChanged)
    }

    private func volumeSlider(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider { return slider }
        for subview in view.subviews {
            if let slider = volumeSlider(in: subview) { return slider }
        }
        return nil
    }

    private func installMediaControls() {
        guard isSessionRunning, remoteCommandTokens.isEmpty else { return }

        let center = MPRemoteCommandCenter.shared()
        register(center.previousTrackCommand, action: .previousPage)
        register(center.nextTrackCommand, action: .nextPage)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "KORemote",
            MPMediaItemPropertyArtist: "Previous and Next turn pages",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyPlaybackQueueCount: 3,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: 1,
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    private func register(_ command: MPRemoteCommand, action: RemoteAction) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self, self.capturesMediaControls, !self.remoteCommandTokens.isEmpty else { return }
                await self.send(action)
            }
            return .success
        }
        remoteCommandTokens.append((command, token))
    }

    private func removeMediaControls() {
        guard !remoteCommandTokens.isEmpty else { return }
        remoteCommandTokens.forEach { command, token in
            command.removeTarget(token)
            command.isEnabled = false
        }
        remoteCommandTokens.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func send(_ action: RemoteAction) async {
        do {
            guard let configuration = try storage.load() else {
                lastError = String(localized: "Pair KOReader first.")
                Feedback.error()
                return
            }
            _ = try await client.send(action, using: configuration)
            lastError = nil
            Feedback.success()
        } catch {
            lastError = error.localizedDescription
            Feedback.error()
        }
    }

#if DEBUG && targetEnvironment(simulator)
    func runSimulatorVolumeActionIfRequested() async {
        guard
            !didRunSimulatorVolumeAction,
            let value = ProcessInfo.processInfo.environment["KOREMOTE_SIMULATOR_VOLUME_ACTION"],
            let action = RemoteAction(rawValue: value)
        else { return }
        didRunSimulatorVolumeAction = true
        await send(action)
    }

    func simulateVolumeAction(_ action: RemoteAction) async {
        await send(action)
    }
#endif
}

private extension SystemControlsStore {
    enum Keys {
        static let usesVolumeButtons = "systemControls.usesVolumeButtons"
        static let capturesMediaControls = "systemControls.capturesMediaControls"
    }
}

struct SystemVolumeCaptureView: UIViewRepresentable {
    let volumeView: MPVolumeView

    func makeUIView(context: Context) -> MPVolumeView { volumeView }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

#if DEBUG
extension SystemControlsStore {
    static func preview() -> SystemControlsStore {
        let defaults = UserDefaults(suiteName: "SystemControlsStore.preview")!
        defaults.removePersistentDomain(forName: "SystemControlsStore.preview")
        return SystemControlsStore(defaults: defaults)
    }
}
#endif
