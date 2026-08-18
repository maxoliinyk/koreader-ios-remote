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
                    Text("Pairing stores the KOReader device address in shared settings and the secret in Keychain.")
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
                Text("Next Page can run from the Lock Screen, Control Center, Action Button, Siri, or Shortcuts without opening the app.")
            }

            if case let .failure(message) = store.activity {
                Section("Last Error") {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                Link("Source Code", destination: URL(string: "https://github.com/maxoliinyk/koreader-ios-remote")!)
                Link("AGPL-3.0 License", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: Bindable(store).isPairingPresented) {
            PairingView()
        }
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
            }

            Section("Media") {
                Toggle("Capture Media Controls", isOn: $systemControls.capturesMediaControls)
            }

            Section("Control Center & Action Button") {
                Label("Next Page is available", systemImage: "forward.end.fill")
            }

            Section("Before locking") {
                Label("Pair KOReader in this app", systemImage: "checkmark.circle")
                Label("Allow Local Network access", systemImage: "checkmark.circle")
                Label("Keep KOReader awake on the same Wi‑Fi", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("System Controls")
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
