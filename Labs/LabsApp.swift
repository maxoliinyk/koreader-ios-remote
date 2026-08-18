import SwiftUI

@main
struct KOReaderRemoteLabsApp: App {
    @State private var experiment = VolumeButtonExperiment()

    var body: some Scene {
        WindowGroup {
            LabsView()
                .environment(experiment)
        }
    }
}
