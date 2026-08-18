//
//  RootView.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

struct RootView: View {
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
        .overlay(alignment: .bottomTrailing) {
            SystemVolumeCaptureView(volumeView: systemControls.volumeView)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    RootView()
        .environment(RemoteStore.preview())
        .environment(SystemControlsStore.preview())
}
