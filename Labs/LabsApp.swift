import SwiftUI

@main
struct KOReaderRemoteLabsApp: App {
    @State private var volume = VolumeButtonExperiment()

    var body: some Scene {
        WindowGroup {
            LabsView()
                .environment(volume)
        }
    }
}
