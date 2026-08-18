import SwiftUI

@main
struct KOReaderRemoteApp: App {
    @State private var store = RemoteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onOpenURL { url in
                    store.pair(with: url)
                }
        }
    }
}
