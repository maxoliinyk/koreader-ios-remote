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

    var body: some View {
        TabView {
            Tab("Remote", systemImage: "book.pages") {
                NavigationStack {
                    RemoteView()
                }
            }

            Tab("Settings", systemImage: "gear") {
                NavigationStack {
                    SettingsView()
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
