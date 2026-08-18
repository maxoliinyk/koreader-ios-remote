//
//  RemoteView.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import RemoteCore
import SwiftUI

struct RemoteView: View {
    @Environment(RemoteStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.remoteLayoutPreviewOverride) private var previewLayout
    @AppStorage(RemoteLayoutStyle.storageKey) private var storedLayout = RemoteLayoutStyle.fullSplit
    @State private var confirmsSleep = false

    private var layout: RemoteLayoutStyle {
        previewLayout ?? storedLayout
    }

    var body: some View {
        Group {
            if let endpoint = store.configuration?.endpoint {
                pairedContent(endpoint: endpoint)
            } else {
                unpairedContent
            }
        }
        .navigationTitle("Remote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.configuration != nil {
                remoteToolbar
            }
        }
        .sheet(isPresented: Bindable(store).isPairingPresented) {
            PairingView()
        }
        .confirmationDialog("Sleep KOReader device?", isPresented: $confirmsSleep, titleVisibility: .visible) {
            Button("Sleep Device", role: .destructive) {
                Task { await store.send(.sleep) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This suspends the paired device.")
        }
    }

    private var unpairedContent: some View {
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

    private func pairedContent(endpoint: KindleEndpoint) -> some View {
        VStack(spacing: 12) {
            DeviceStatusHeader(endpoint: endpoint)

            GeometryReader { geometry in
                pageControls(in: geometry.size)
            }

            ActivityStatusView(activity: store.activity)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ToolbarContentBuilder
    private var remoteToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker("Button Layout", selection: $storedLayout) {
                    ForEach(RemoteLayoutStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            Image(systemName: style.symbol)
                        }
                        .tag(style)
                    }
                }
            } label: {
                Label("Remote Layout", systemImage: layout.symbol)
            }

            Button {
                confirmsSleep = true
            } label: {
                Label("Sleep Device", systemImage: "moon.zzz")
            }
            .disabled(store.isSending)
            .accessibilityHint("Puts the paired KOReader device to sleep")
        }
    }

    @ViewBuilder
    private func pageControls(in size: CGSize) -> some View {
        if dynamicTypeSize.isAccessibilitySize, size.height >= 320 {
            verticalPageControls
        } else {
            switch layout {
            case .fullSplit:
                HStack(spacing: 12) {
                    pageButton(.previousPage)
                    pageButton(.nextPage)
                }
            case .nextFocused:
                HStack(spacing: 12) {
                    pageButton(.previousPage)
                        .frame(width: max(112, (size.width - 12) / 3))
                    pageButton(.nextPage)
                }
            case .compact:
                VStack {
                    HStack(spacing: 12) {
                        pageButton(.previousPage)
                        pageButton(.nextPage)
                    }
                    .frame(height: min(176, size.height))

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var verticalPageControls: some View {
        VStack(spacing: 12) {
            pageButton(.previousPage)
            pageButton(.nextPage)
        }
    }

    private func pageButton(_ action: RemoteAction) -> some View {
        RemotePageButton(action: action, isSending: store.isSending) {
            Task { await store.send(action) }
        }
    }
}

private struct DeviceStatusHeader: View {
    let endpoint: KindleEndpoint

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(endpoint.name)
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("Ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(endpoint.name), ready")
    }
}

private struct RemotePageButton: View {
    let action: RemoteAction
    let isSending: Bool
    let send: () -> Void

    private var title: LocalizedStringResource {
        switch action {
        case .previousPage: "Previous"
        case .nextPage: "Next"
        case .sleep: "Sleep"
        }
    }

    private var symbol: String {
        switch action {
        case .previousPage: "chevron.backward"
        case .nextPage: "chevron.forward"
        case .sleep: "moon.zzz"
        }
    }

    private var isPrimary: Bool {
        action == .nextPage
    }

    var body: some View {
        Button(action: send) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 24))
        .tint(isPrimary ? Color.accentColor : Color.primary.opacity(0.09))
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .disabled(isSending)
        .accessibilityLabel(title)
        .accessibilityHint(isPrimary ? "Turns forward one page in KOReader" : "Turns back one page in KOReader")
    }
}

private struct ActivityStatusView: View {
    let activity: RemoteStore.Activity

    var body: some View {
        Group {
            switch activity {
            case .idle:
                Text("Tap a side to turn the page")
                    .foregroundStyle(.secondary)
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
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private struct RemotePreview: View {
    let layout: RemoteLayoutStyle
    var activity = RemoteStore.Activity.idle

    var body: some View {
        NavigationStack {
            RemoteView()
        }
        .environment(RemoteStore.preview(activity: activity))
        .environment(\.remoteLayoutPreviewOverride, layout)
    }
}

#Preview("Unpaired") {
    NavigationStack { RemoteView() }
        .environment(RemoteStore.preview(paired: false))
}

#Preview("Full Split") {
    RemotePreview(layout: .fullSplit)
}

#Preview("Next Focused") {
    RemotePreview(layout: .nextFocused)
}

#Preview("Compact") {
    RemotePreview(layout: .compact)
}

#Preview("Sending") {
    RemotePreview(layout: .fullSplit, activity: .sending(.nextPage))
}

#Preview("Failure") {
    RemotePreview(
        layout: .fullSplit,
        activity: .failure("The KOReader device could not be reached on the local network.")
    )
}
