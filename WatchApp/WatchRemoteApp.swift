import SwiftUI

@main
struct WatchRemoteApp: App {
    @State private var store = WatchRemoteStore()

    var body: some Scene {
        WindowGroup {
            WatchRemoteView()
                .environment(store)
                .task { store.activate() }
        }
    }
}
