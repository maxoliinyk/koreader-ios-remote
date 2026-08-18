import AppIntents
import RemoteCore

struct KOReaderAppShortcuts: AppShortcutsProvider {
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
            intent: SleepKindleIntent(),
            phrases: [
                "Sleep my Kindle with \(.applicationName)",
            ],
            shortTitle: "Sleep Kindle",
            systemImageName: "moon.zzz"
        )
    }
}
