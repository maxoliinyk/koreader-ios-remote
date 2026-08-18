import SwiftUI

struct LabsView: View {
    @Environment(VolumeButtonExperiment.self) private var volume
    @State private var privateSymbols: [PrivateSymbolStatus] = []
    @AppStorage("labs.backgroundAudio") private var backgroundAudio = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Unsupported research build", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This app changes system audio state and probes private symbols. It is never included in the normal archive.")
                }

                Section("Foreground Volume Buttons") {
                    Toggle("Observe Volume Changes", isOn: Bindable(volume).isRunning)
                        .onChange(of: volume.isRunning) { _, enabled in
                            enabled ? volume.start(backgroundAudio: backgroundAudio) : volume.stop()
                        }
                    Toggle("Background Audio Category", isOn: $backgroundAudio)
                        .onChange(of: backgroundAudio) { _, enabled in
                            if volume.isRunning { volume.start(backgroundAudio: enabled) }
                        }
                    LabeledContent("System Volume", value: volume.outputVolume.formatted(.number.precision(.fractionLength(2))))
                    LabeledContent("Last Change", value: volume.lastChange)
                    Text("Volume buttons still change system volume. At 0% and 100%, another press may produce no observable value change. Audio-route changes and interruptions can reset the session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SystemVolumeView()
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }

                Section("Private MediaRemote Probe") {
                    Button("Inspect Symbol Availability") {
                        privateSymbols = PrivateFrameworkProbe.inspectMediaRemote()
                    }
                    ForEach(privateSymbols) { item in
                        LabeledContent(item.name, value: item.available ? "Present" : "Missing")
                    }
                    Text("The probe loads no private API into the public app and never invokes a private function.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("watchOS Gesture Notes") {
                    Label("Public: one primary Double Tap shortcut per scene", systemImage: "hand.tap")
                    Label("No public distinct single-finger gesture action", systemImage: "questionmark.circle")
                    Text("Runtime watchOS symbol research must run in a separately signed watch Labs target before any symbol is called.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Remote Labs")
        }
        .onDisappear { volume.stop() }
    }
}
