//
//  KORemoteView.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import RemoteCore
import SwiftUI

struct KORemoteView: View {
    @Environment(KORemoteStore.self) private var store
    @State private var confirmsSleep = false

    var body: some View {
        VStack(spacing: 10) {
            status

            HStack(spacing: 8) {
                actionButton("Previous", symbol: "chevron.backward", action: .previousPage)

                Button {
                    Task { await store.send(.nextPage) }
                } label: {
                    Label("Next", systemImage: "chevron.forward")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .handGestureShortcut(.primaryAction)
                .accessibilityLabel("Next Page")
                .accessibilityHint("Turns forward one page in KOReader")
            }
            .frame(maxHeight: 72)

            Button("Sleep", systemImage: "moon.zzz", role: .destructive) {
                confirmsSleep = true
            }
            .font(.footnote)
            .disabled(store.state == .sending)

#if DEBUG
            NavigationLink {
                WatchGestureLabView()
            } label: {
                Label("Gesture Lab", systemImage: "waveform.path")
            }
            .font(.footnote)
#endif
        }
        .padding(.horizontal, 4)
        .confirmationDialog("Sleep KOReader device?", isPresented: $confirmsSleep) {
            Button("Sleep Device", role: .destructive) {
                Task { await store.send(.sleep) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func actionButton(_ title: LocalizedStringKey, symbol: String, action: RemoteAction) -> some View {
        Button {
            Task { await store.send(action) }
        } label: {
            Label(title, systemImage: symbol)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(store.state == .sending)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var status: some View {
        if let name = store.configuration?.endpoint.name {
            switch store.state {
            case .ready:
                Label(name, systemImage: "checkmark.circle")
            case .sending:
                ProgressView("Sending…")
            case .success:
                Label("Sent", systemImage: "checkmark")
                    .foregroundStyle(.green)
            case let .failure(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        } else {
            Label("Pair on iPhone", systemImage: "iphone.and.arrow.forward")
                .foregroundStyle(.secondary)
        }
    }
}
