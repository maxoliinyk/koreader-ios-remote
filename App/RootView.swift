//
//  RootView.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

struct RootView: View {
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
    }
}

#Preview {
    RootView()
        .environment(RemoteStore.preview())
}
