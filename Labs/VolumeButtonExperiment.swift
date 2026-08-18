import AVFoundation
import MediaPlayer
import Observation
import SwiftUI

@MainActor
@Observable
final class VolumeButtonExperiment: NSObject {
    var isRunning = false
    private(set) var outputVolume = AVAudioSession.sharedInstance().outputVolume
    private(set) var lastChange = "None"

    @ObservationIgnored
    private var observation: NSKeyValueObservation?

    func start(backgroundAudio: Bool) {
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(backgroundAudio ? .playback : .ambient, options: [.mixWithOthers])
            try session.setActive(true)
            outputVolume = session.outputVolume
            observation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
                let oldValue = change.oldValue ?? 0
                let newValue = change.newValue ?? oldValue
                Task { @MainActor in
                    self?.outputVolume = newValue
                    self?.lastChange = newValue > oldValue ? "Volume Up" : newValue < oldValue ? "Volume Down" : "Unchanged"
                }
            }
            isRunning = true
        } catch {
            lastChange = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        observation = nil
        if isRunning { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        isRunning = false
    }
}

struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.alpha = 0.01
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
