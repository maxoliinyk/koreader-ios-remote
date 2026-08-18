//
//  AppShortcuts.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import AppIntents
import RemoteCore

struct KORemoteAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextPageIntent(),
            phrases: [
                "Turn the next page with \(.applicationName)",
                "Next page in \(.applicationName)",
            ],
            shortTitle: "Next Page",
            systemImageName: "chevron.forward"
        )
        AppShortcut(
            intent: PreviousPageIntent(),
            phrases: [
                "Turn the previous page with \(.applicationName)",
                "Previous page in \(.applicationName)",
            ],
            shortTitle: "Previous Page",
            systemImageName: "chevron.backward"
        )
        AppShortcut(
            intent: SleepDeviceIntent(),
            phrases: [
                "Sleep my KOReader device with \(.applicationName)",
            ],
            shortTitle: "Sleep Device",
            systemImageName: "moon.zzz"
        )
    }
}
