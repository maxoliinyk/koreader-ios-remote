//
//  KORemoteWatchApp.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

@main
struct KORemoteWatchApp: App {
    @State private var store = KORemoteStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                KORemoteView()
            }
            .environment(store)
            .task { store.activate() }
        }
    }
}
