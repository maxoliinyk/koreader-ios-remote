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
    @AppStorage(RemoteLayoutStyle.storageKey) private var remoteLayout = RemoteLayoutStyle.fullSplit
    @State private var confirmsForget = false

    var body: some View {
        Form {
            Section {
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
            } header: {
                Text("Remote Layout")
            } footer: {
                Text(remoteLayout.detail)
            }

            if let endpoint = store.configuration?.endpoint {
                Section("KOReader Device") {
                    LabeledContent("Name", value: endpoint.name)
                    LabeledContent("Address", value: endpoint.host)
                    LabeledContent("Port", value: String(endpoint.port))

                    Button("Scan Again", systemImage: "qrcode.viewfinder") {
                        store.isPairingPresented = true
                    }

                    Button("Forget Device", systemImage: "trash", role: .destructive) {
                        confirmsForget = true
                    }
                }
            } else {
                Section {
                    Button("Pair KOReader", systemImage: "qrcode.viewfinder") {
                        store.isPairingPresented = true
                    }
                } footer: {
                    Text("Pairing stores the KOReader device address on this device and the secret in Keychain.")
                }
            }

            Section("Connection") {
                Button("Test Connection", systemImage: "network") {
                    Task { await store.testConnection() }
                }
                .disabled(store.configuration == nil || store.isSending)

                NavigationLink {
                    LocalNetworkHelpView()
                } label: {
                    Label("Local Network Help", systemImage: "wifi")
                }

                LabeledContent("Protocol", value: "KORemote v1")
                LabeledContent("Default Port", value: "9090")
            }

            Section {
                NavigationLink {
                    SystemControlsHelpView()
                } label: {
                    Label("System Controls", systemImage: "lock.open")
                }
            } header: {
                Text("Use While Locked")
            } footer: {
                Text(DistributionProfile.current.includesControlCenterWidgets
                    ? "Next Page can run from the Lock Screen, Control Center, Action Button, Siri, or Shortcuts."
                    : "Use Next Page with Siri, Shortcuts, or an Action Button shortcut.")
            }

            if case let .failure(message) = store.activity {
                Section("Last Error") {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                LabeledContent("Distribution", value: DistributionProfile.current.title)
                Link("Installation Guide", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote/blob/main/README.md")!)
                Link("Download KOReader Plugin", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote/releases")!)
                Link("Source Code", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote")!)
                Link("AGPL-3.0 License", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Forget this KOReader device?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Device", role: .destructive) { store.forget() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to scan or enter a new pairing secret before sending page actions.")
        }
    }
}

private struct SystemControlsHelpView: View {
    @Environment(SystemControlsStore.self) private var systemControls

    var body: some View {
        @Bindable var systemControls = systemControls
        Form {
            Section("Hardware Buttons") {
                Toggle("Use Volume Buttons", isOn: $systemControls.usesVolumeButtons)
                Text(volumeButtonDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

#if DEBUG && targetEnvironment(simulator)
            Section("Simulator Volume Test") {
                Button("Simulate Volume Up", systemImage: "speaker.plus") {
                    Task { await systemControls.simulateVolumeAction(.nextPage) }
                }
                Button("Simulate Volume Down", systemImage: "speaker.minus") {
                    Task { await systemControls.simulateVolumeAction(.previousPage) }
                }
                Text("Simulator's toolbar volume controls do not reliably change AVAudioSession outputVolume. These buttons exercise the remaining page-action path.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
#endif

            if DistributionProfile.current.supportsMediaControls {
                Section("Media") {
                    Toggle("Capture Media Controls", isOn: $systemControls.capturesMediaControls)
                }
            }

            Section("Shortcuts & Action Button") {
                Label("Next Page is available in Shortcuts", systemImage: "forward.end.fill")
                if DistributionProfile.current.includesControlCenterWidgets {
                    Label("Next Page is available in Control Center", systemImage: "switch.2")
                }
            }

            Section("Before locking") {
                Label("Pair KOReader in this app", systemImage: "checkmark.circle")
                Label("Allow Local Network access", systemImage: "checkmark.circle")
                Label("Keep KOReader awake on the same Wi‑Fi", systemImage: "checkmark.circle")
            }

            Section("Included in this build") {
                Label(
                    DistributionProfile.current.includesWatchCompanion
                        ? "Apple Watch companion"
                        : "Apple Watch companion not included",
                    systemImage: DistributionProfile.current.includesWatchCompanion
                        ? "applewatch"
                        : "applewatch.slash"
                )
                Label(
                    DistributionProfile.current.includesControlCenterWidgets
                        ? "Control Center widgets"
                        : "Control Center widgets not included",
                    systemImage: "switch.2"
                )
            }
        }
        .navigationTitle("System Controls")
    }

    private var volumeButtonDetail: String {
        if DistributionProfile.current.keepsVolumeCaptureWhileInactive {
            "This sideload build keeps a quiet audio session active so volume buttons can turn pages while the app is locked."
        } else {
            "This full build observes volume changes only while KORemote is in the foreground."
        }
    }
}

private struct LocalNetworkHelpView: View {
    var body: some View {
        List {
            Section {
                Label("Keep the iPhone and KOReader device on the same Wi‑Fi network.", systemImage: "wifi")
                Label("Open KOReader so the Remote Turner listener is active.", systemImage: "book")
                Label("Allow Local Network access in the iPhone Settings app.", systemImage: "switch.2")
            }

            Section {
                Link("Open iPhone Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
            }
        }
        .navigationTitle("Local Network")
    }
}
