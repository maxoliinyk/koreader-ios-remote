//
//  LabsApp.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

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
