//
//  SettingsView.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import RemoteCore
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(RemoteStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SystemControlsStore.self) private var systemControls
    @AppStorage(RemoteLayoutStyle.storageKey) private var remoteLayout = RemoteLayoutStyle.fullSplit
    @State private var confirmsForget = false
    @State private var summary: PageTurnStatistics.Summary?
    @State private var failedToLoadStatistics = false

    var body: some View {
        @Bindable var systemControls = systemControls
        @Bindable var airPods = store.airPods
        Form {
            Section("Remote") {
                Picker("Button Layout", selection: $remoteLayout) {
                    ForEach(RemoteLayoutStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            Image(systemName: style.symbol)
                        }
                        .tag(style)
                    }
                }
            }

            Section("Pages Turned") {
                if let summary {
                    LabeledContent("This month", value: summary.thisMonth.formatted())
                    LabeledContent("All time", value: summary.allTime.formatted())
                } else if failedToLoadStatistics {
                    Text("Page-turn statistics could not be loaded.")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }

            Section("KOReader") {
                if let endpoint = store.configuration?.endpoint {
                    LabeledContent("Name", value: endpoint.name)
                    LabeledContent("Address", value: endpoint.host)
                        .textSelection(.enabled)
                    LabeledContent("Port", value: String(endpoint.port))

                    Button("Test Connection", systemImage: "network") {
                        Task { await store.testConnection() }
                    }
                    .disabled(store.isSending)

                    connectionStatus

                    Button("Pair Again", systemImage: "qrcode.viewfinder") {
                        store.isPairingPresented = true
                    }
                    Button("Forget Device", systemImage: "trash", role: .destructive) {
                        confirmsForget = true
                    }
                } else {
                    Button("Pair KOReader", systemImage: "qrcode.viewfinder") {
                        store.isPairingPresented = true
                    }
                }
            }

            Section {
                Toggle("Use Volume Buttons", isOn: $systemControls.usesVolumeButtons)
                    .accessibilityHint("Volume Up turns forward; Volume Down turns back.")
                if DistributionProfile.current.supportsMediaControls {
                    Toggle("Capture Media Controls", isOn: $systemControls.capturesMediaControls)
                }
                if let message = systemControls.lastError {
                    Text(message)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Controls")
            } footer: {
                if systemControls.usesVolumeButtons || systemControls.capturesMediaControls {
                    Text("May interrupt other audio.")
                }
            }

            Section {
                Toggle("AirPods Head Gestures", isOn: $airPods.isEnabled)
                if airPods.isEnabled {
                    LabeledContent("Gesture Size", value: "\(Int(airPods.thresholdDegrees))°")
                    Slider(value: $airPods.thresholdDegrees, in: 10...30, step: 1) {
                        Text("Gesture Size")
                    }
                    Text(airPods.status)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Experimental")
            } footer: {
                Text("With compatible AirPods connected, open Remote and hold your head still to calibrate. Nod and return to center for next; shake left and right, then center, for previous. Works while Remote is visible and the app is active. Smaller gestures are easier to trigger accidentally.")
            }

            Section {
                NavigationLink {
                    RemoteHelpView()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                Link("Source Code", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote")!)
                Link("License", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
#if DEBUG && targetEnvironment(simulator)
                NavigationLink("Simulator Tools") {
                    SimulatorControlsView()
                }
#endif
            }
        }
        .navigationTitle("Settings")
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await loadStatistics()
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
            }
        }
        .confirmationDialog("Forget this KOReader device?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Device", role: .destructive) { store.forget() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadStatistics() async {
        do {
            summary = try await PageTurnStatistics.shared.summary()
            failedToLoadStatistics = false
        } catch {
            summary = nil
            failedToLoadStatistics = true
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch store.activity {
        case .idle, .sending, .success:
            EmptyView()
        case .testingConnection:
            ProgressView("Testing…")
        case .connectionReady:
            Label("Connected", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case let .failure(message):
            Text(message).foregroundStyle(.red)
        }
    }
}

private struct RemoteHelpView: View {
    var body: some View {
        List {
            Section("Connection") {
                Text("Keep KOReader awake on the same Wi-Fi network.")
                Link("Open iPhone Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
            }
            Section {
                Link("Setup & Troubleshooting", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote/blob/main/README.md")!)
                Link("Download KOReader Plugin", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote/releases")!)
            }
        }
        .navigationTitle("Help")
    }
}

#if DEBUG && targetEnvironment(simulator)
private struct SimulatorControlsView: View {
    @Environment(SystemControlsStore.self) private var systemControls

    var body: some View {
        Form {
            Button("Simulate Volume Up", systemImage: "speaker.plus") {
                Task { await systemControls.simulateVolumeAction(.nextPage) }
            }
            Button("Simulate Volume Down", systemImage: "speaker.minus") {
                Task { await systemControls.simulateVolumeAction(.previousPage) }
            }
        }
        .navigationTitle("Simulator Tools")
    }
}
#endif
