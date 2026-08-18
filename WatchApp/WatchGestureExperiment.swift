#if DEBUG
import CoreMotion
import Darwin
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

enum WatchPrivateGestureProbe {
    static func result() -> String {
        let path = "/System/Library/Frameworks/SwiftUI.framework/SwiftUI"
        guard let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) else {
            return "SwiftUI image unavailable"
        }
        defer { dlclose(handle) }
        let symbols = [
            "_$s7SwiftUI4ViewPAAE23handGestureShortcutTask018prepareToHighlightG0QryAA04HandeF0VYaScMYcc_tF",
            "_$s7SwiftUI4ViewPAAE29handGestureShortcutPagination9directionQrAA04HandefG9DirectionO_tF",
        ]
        let found = symbols.filter { dlsym(handle, $0) != nil }.count
        return "\(found)/\(symbols.count) private shortcut symbols present"
    }
}

struct WatchGestureLabView: View {
    @Environment(WatchRemoteStore.self) private var store
    @State private var experiment = WatchGestureExperiment()
    @State private var privateResult = "Not inspected"

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
                Text("Primary Action is the public Double Tap route. watchOS 27 Single Tap is owned by Smart Stack and has no app callback in Beta 5.")
                    .font(.footnote)
            }

            Section("Private SwiftUI") {
                Button("Inspect Symbols") { privateResult = WatchPrivateGestureProbe.result() }
                Text(privateResult)
                Text("The private symbols prepare highlighting and pagination; they do not expose a raw Single Tap event.")
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
