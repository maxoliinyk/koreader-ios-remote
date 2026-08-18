//
//  KOReaderRemoteApp.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

@main
struct KOReaderRemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = RemoteStore()
    @State private var systemControls = SystemControlsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(systemControls)
                .task {
                    PhoneConnectivity.shared.activate()
                    systemControls.activate()
                }
                .onOpenURL { url in
                    store.pair(with: url)
                }
        }
    }
}
