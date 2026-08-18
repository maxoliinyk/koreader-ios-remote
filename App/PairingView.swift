import RemoteCore
import SwiftUI

struct PairingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode = Mode.scan

    enum Mode: String, CaseIterable, Identifiable {
        case scan
        case manual
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Pairing Method", selection: $mode) {
                    Text("Scan Code").tag(Mode.scan)
                    Text("Manual").tag(Mode.manual)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch mode {
                case .scan: ScannerPane()
                case .manual: ManualPairingForm()
                }
            }
            .navigationTitle("Pair KOReader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct ScannerPane: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        if PairingScannerView.isSupported {
            PairingScannerView { value in
                guard let url = URL(string: value) else { return }
                store.pair(with: url)
            }
            .clipShape(.rect(cornerRadius: 16))
            .padding([.horizontal, .bottom])
            .overlay(alignment: .bottom) {
                Text("Point the camera at the QR code shown by the KOReader plugin.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: .capsule)
                    .padding(32)
            }
        } else {
            ContentUnavailableView(
                "Scanner Unavailable",
                systemImage: "camera.fill",
                description: Text("Use manual pairing on this device.")
            )
        }
    }
}

private struct ManualPairingForm: View {
    @Environment(RemoteStore.self) private var store
    @State private var name = "My KOReader"
    @State private var host = ""
    @State private var port = "9090"
    @State private var secret = ""

    var body: some View {
        Form {
            Section("KOReader Device") {
                TextField("Name", text: $name)
                TextField("IP address or hostname", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
            }

            Section("Pairing Secret") {
                SecureField("Base64URL secret", text: $secret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.oneTimeCode)
                Text("Enter the secret exactly as shown in KOReader.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Save and Pair") {
                store.pair(name: name, host: host, port: Int(port) ?? 0, secret: secret)
            }
            .disabled(name.isEmpty || host.isEmpty || secret.isEmpty)
        }
    }
}
