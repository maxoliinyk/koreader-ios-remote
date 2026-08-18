//
//  SystemControlsStore.swift
//  KOReaderRemote
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
    @ObservationIgnored private var hasActivated = false
    @ObservationIgnored private var isSessionRunning = false
    @ObservationIgnored private var volumeObservation: NSKeyValueObservation?
    @ObservationIgnored private var remoteCommandTokens: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var expectedVolume: Float?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        usesVolumeButtons = defaults.bool(forKey: Keys.usesVolumeButtons)
        capturesMediaControls = defaults.bool(forKey: Keys.capturesMediaControls)
    }

    func activate() {
        hasActivated = true
        reconcile()
    }

    private func reconcile() {
        guard hasActivated else { return }

        if usesVolumeButtons || capturesMediaControls {
            startSessionIfNeeded()
        }

        usesVolumeButtons ? installVolumeCapture() : removeVolumeCapture()
        capturesMediaControls ? installMediaControls() : removeMediaControls()

        if !usesVolumeButtons, !capturesMediaControls {
            stopSession()
        }
    }

    private func startSessionIfNeeded() {
        guard !isSessionRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try startAudioEngine()
            isSessionRunning = true
        } catch {
            stopSession()
            Feedback.error()
        }
    }

    private func stopSession() {
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
                guard let self else { return }
                if let expectedVolume = self.expectedVolume, abs(newValue - expectedVolume) < 0.01 {
                    self.expectedVolume = nil
                    return
                }
                guard newValue != oldValue else { return }

                let action: RemoteAction = newValue > oldValue ? .nextPage : .previousPage
                self.recenterVolume()
                await self.send(action)
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(250))
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
            MPMediaItemPropertyTitle: "KOReader Remote",
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
                await self?.send(action)
            }
            return .success
        }
        remoteCommandTokens.append((command, token))
    }

    private func removeMediaControls() {
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
                Feedback.error()
                return
            }
            _ = try await client.send(action, using: configuration)
            Feedback.success()
        } catch {
            Feedback.error()
        }
    }
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
