import SwiftUI

@main
struct WatchRemoteApp: App {
    @State private var store = WatchRemoteStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRemoteView()
            }
            .environment(store)
            .task { store.activate() }
        }
    }
}
