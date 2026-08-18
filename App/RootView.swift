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
