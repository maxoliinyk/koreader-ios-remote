import RemoteCore
import SwiftUI

struct RemoteView: View {
    @Environment(RemoteStore.self) private var store

    var body: some View {
        Group {
            if let endpoint = store.configuration?.endpoint {
                pairedContent(endpoint: endpoint)
            } else {
                ContentUnavailableView {
                    Label("Pair your KOReader device", systemImage: "rectangle.connected.to.line.below")
                } description: {
                    Text("Open KOReader, show the Remote Turner pairing code, then scan it here.")
                } actions: {
                    Button("Pair KOReader") {
                        store.isPairingPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Remote")
        .sheet(isPresented: Bindable(store).isPairingPresented) {
            PairingView()
        }
    }

    private func pairedContent(endpoint: KindleEndpoint) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                readiness(endpoint)

                HStack(spacing: 16) {
                    pageButton(title: "Previous", symbol: "chevron.backward", action: .previousPage, prominent: false)
                    pageButton(title: "Next", symbol: "chevron.forward", action: .nextPage, prominent: true)
                }

                Button(role: .destructive) {
                    Task { await store.send(.sleep) }
                } label: {
                    Label("Sleep Device", systemImage: "moon.zzz")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isSending)
                .accessibilityHint("Puts the paired KOReader device to sleep")

                resultView
            }
            .padding()
        }
    }

    private func readiness(_ endpoint: KindleEndpoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready")
                    .font(.headline)
                Text(endpoint.name)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func pageButton(title: LocalizedStringKey, symbol: String, action: RemoteAction, prominent: Bool) -> some View {
        if prominent {
            actionButton(title: title, symbol: symbol, action: action)
                .buttonStyle(.borderedProminent)
        } else {
            actionButton(title: title, symbol: symbol, action: action)
                .buttonStyle(.bordered)
        }
    }

    private func actionButton(title: LocalizedStringKey, symbol: String, action: RemoteAction) -> some View {
        Button {
            Task { await store.send(action) }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.largeTitle.weight(.semibold))
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 144)
        }
        .controlSize(.large)
        .disabled(store.isSending)
        .accessibilityHint(action == .nextPage ? "Turns forward one page in KOReader" : "Turns back one page in KOReader")
    }

    @ViewBuilder
    private var resultView: some View {
        switch store.activity {
        case .idle:
            EmptyView()
        case .sending:
            HStack {
                ProgressView()
                Text("Sending…")
            }
            .foregroundStyle(.secondary)
        case let .success(message):
            Label(message, systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case let .failure(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Unpaired") {
    NavigationStack { RemoteView() }
        .environment(RemoteStore.preview(paired: false))
}

#Preview("Sending") {
    NavigationStack { RemoteView() }
        .environment(RemoteStore.preview(activity: .sending(.nextPage)))
}

#Preview("Success") {
    NavigationStack { RemoteView() }
        .environment(RemoteStore.preview(activity: .success("Next page sent.")))
}

#Preview("Failure") {
    NavigationStack { RemoteView() }
        .environment(RemoteStore.preview(activity: .failure("The KOReader device could not be reached.")))
}
