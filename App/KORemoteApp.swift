//
//  KORemoteApp.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import SwiftUI

@main
struct KORemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
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
#if DEBUG && targetEnvironment(simulator)
                    store.runSimulatorPairingIfRequested()
                    await systemControls.runSimulatorVolumeActionIfRequested()
#endif
                }
                .onOpenURL { url in
                    store.pair(with: url)
                }
                .onChange(of: scenePhase, initial: true) { _, newValue in
                    systemControls.scenePhaseChanged(to: newValue)
                }
        }
    }
}
