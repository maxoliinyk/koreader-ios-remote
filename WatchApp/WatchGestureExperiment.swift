//
//  WatchGestureExperiment.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

#if DEBUG
import CoreMotion
import Observation
import SwiftUI

@MainActor
@Observable
final class WatchGestureExperiment {
    private(set) var isRunning = false
    private(set) var impulse = 0.0
    private(set) var peak = 0.0
    private(set) var detections = 0
    private(set) var status = "Stopped"
    var threshold = 0.55
    var sendsNext = false
    var onDetection: (@MainActor () -> Void)?

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var lastDetection = Date.distantPast

    func start() {
        guard motion.isDeviceMotionAvailable else {
            status = "Device Motion unavailable"
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 50.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = error.localizedDescription
                    return
                }
                guard let sample else { return }
                self.consume(sample)
            }
        }
        isRunning = true
        status = "Listening at 50 Hz"
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        isRunning = false
        status = "Stopped"
    }

    func resetPeak() {
        peak = 0
        detections = 0
    }

    private func consume(_ sample: CMDeviceMotion) {
        let a = sample.userAcceleration
        let r = sample.rotationRate
        let acceleration = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        let rotation = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
        impulse = acceleration + rotation * 0.08
        peak = max(peak, impulse)

        let now = Date()
        guard impulse >= threshold, now.timeIntervalSince(lastDetection) > 0.8 else { return }
        lastDetection = now
        detections += 1
        status = "Impulse detected"
        if sendsNext { onDetection?() }
    }
}

struct WatchGestureLabView: View {
    @Environment(WatchRemoteStore.self) private var store
    @State private var experiment = WatchGestureExperiment()

    var body: some View {
        @Bindable var experiment = experiment
        List {
            Section("Motion Heuristic") {
                Button(experiment.isRunning ? "Stop" : "Start") {
                    experiment.isRunning ? experiment.stop() : experiment.start()
                }
                Toggle("Send Next", isOn: $experiment.sendsNext)
                LabeledContent("Impulse", value: experiment.impulse.formatted(.number.precision(.fractionLength(2))))
                LabeledContent("Peak", value: experiment.peak.formatted(.number.precision(.fractionLength(2))))
                LabeledContent("Hits", value: experiment.detections.formatted())
                Slider(value: $experiment.threshold, in: 0.15...2.0) {
                    Text("Threshold")
                } minimumValueLabel: {
                    Text("Low")
                } maximumValueLabel: {
                    Text("High")
                }
                Button("Reset") { experiment.resetPeak() }
            }

            Section("System Gesture") {
                Button("Next") { Task { await store.send(.nextPage) } }
                    .handGestureShortcut(.primaryAction)
                Text("Primary Action enables Double Tap on supported watches while this scene is visible.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Gesture Lab")
        .onAppear {
            experiment.onDetection = {
                Task { await store.send(.nextPage) }
            }
        }
        .onDisappear { experiment.stop() }
    }
}
#endif
