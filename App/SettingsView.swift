import RemoteCore
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(RemoteStore.self) private var store
    @State private var confirmsForget = false

    var body: some View {
        Form {
            if let endpoint = store.configuration?.endpoint {
                Section("Paired Kindle") {
                    LabeledContent("Name", value: endpoint.name)
                    LabeledContent("Address", value: endpoint.host)
                    LabeledContent("Port", value: String(endpoint.port))

                    Button("Test Connection", systemImage: "network") {
                        Task { await store.testConnection() }
                    }
                    .disabled(store.isSending)

                    Button("Scan Again", systemImage: "qrcode.viewfinder") {
                        store.isPairingPresented = true
                    }

                    Button("Forget Device", systemImage: "trash", role: .destructive) {
                        confirmsForget = true
                    }
                }
            } else {
                Section {
                    Button("Pair Kindle", systemImage: "qrcode.viewfinder") {
                        store.isPairingPresented = true
                    }
                } footer: {
                    Text("Pairing stores the Kindle address in shared settings and the secret in Keychain.")
                }
            }

            Section("Connection") {
                LabeledContent("Protocol", value: "KOReader Remote v1")
                LabeledContent("Default Port", value: "9090")
                NavigationLink("Local Network Help") {
                    LocalNetworkHelpView()
                }
            }

            if case let .failure(message) = store.activity {
                Section("Last Error") {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                Link("Source Code", destination: URL(string: "https://github.com/tachibana-shin/koreader_remote_turner")!)
                Link("AGPL-3.0 License", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: Bindable(store).isPairingPresented) {
            PairingView()
        }
        .confirmationDialog("Forget this Kindle?", isPresented: $confirmsForget, titleVisibility: .visible) {
            Button("Forget Device", role: .destructive) { store.forget() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to scan or enter a new pairing secret before sending page actions.")
        }
    }
}

private struct LocalNetworkHelpView: View {
    var body: some View {
        List {
            Section {
                Label("Keep the iPhone and Kindle on the same Wi‑Fi network.", systemImage: "wifi")
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
