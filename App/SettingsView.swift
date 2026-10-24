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
    @Environment(SystemControlsStore.self) private var systemControls
    @AppStorage(RemoteLayoutStyle.storageKey) private var remoteLayout = RemoteLayoutStyle.fullSplit
    @State private var confirmsForget = false

    var body: some View {
        @Bindable var systemControls = systemControls
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

            PageTurnStatisticsSection()

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
        .confirmationDialog("Forget this KOReader device?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Device", role: .destructive) { store.forget() }
            Button("Cancel", role: .cancel) {}
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

private struct PageTurnStatisticsSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var summary: PageTurnStatistics.Summary?
    @State private var failedToLoad = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Section {
                if let summary {
                    LabeledContent("This month", value: summary.thisMonth.formatted())
                    LabeledContent("All time", value: summary.allTime.formatted())
                } else if failedToLoad {
                    Text("Page-turn statistics could not be loaded.")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            } header: {
                Text("Pages Turned")
            } footer: {
                Text("Successful next-page commands on this device, starting with this update.")
            }
            .task(id: context.date) { await loadSummary() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadSummary() }
                }
            }
        }
    }

    private func loadSummary() async {
        do {
            summary = try await PageTurnStatistics.shared.summary()
            failedToLoad = false
        } catch {
            summary = nil
            failedToLoad = true
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
