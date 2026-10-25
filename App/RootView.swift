//
//  RootView.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

struct RootView: View {
    @Environment(RemoteStore.self) private var store
    @Environment(SystemControlsStore.self) private var systemControls
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    private var allowsHeadGestures: Bool {
        scenePhase == .active && selectedTab == 0 && store.configuration != nil && !store.isPairingPresented
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Remote", systemImage: "book.pages", value: 0) {
                NavigationStack {
                    RemoteView()
                }
            }

            Tab("Settings", systemImage: "gear", value: 1) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onChange(of: allowsHeadGestures, initial: true) { [store] _, allowed in
            store.airPods.setListeningAllowed(allowed) { [weak store] action in
                Task { @MainActor [weak store] in
                    guard let store, store.airPods.isRunning, store.airPods.isEnabled,
                          store.configuration != nil, !store.isPairingPresented else { return }
                    await store.send(action)
                }
            }
        }
        .sheet(isPresented: Bindable(store).isPairingPresented) {
            PairingView()
        }
        .overlay(alignment: .bottomTrailing) {
            SystemVolumeCaptureView(volumeView: systemControls.volumeView)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(RemoteStore.preview())
        .environment(SystemControlsStore.preview())
}
#endif
