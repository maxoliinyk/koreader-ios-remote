import SwiftUI

@main
struct KOReaderRemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = RemoteStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { PhoneConnectivity.shared.activate() }
                .onOpenURL { url in
                    store.pair(with: url)
                }
        }
    }
}
