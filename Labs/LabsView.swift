//
//  LabsView.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

struct LabsView: View {
    @Environment(VolumeButtonExperiment.self) private var experiment
    @State private var privateSymbols: [PrivateSymbolStatus] = []
    @State private var mediaRemoteResult = "Not invoked"

    var body: some View {
        @Bindable var experiment = experiment
        NavigationStack {
            Form {
                Section {
                    Label("Unsupported research build", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("This target owns the audio session and can call private UIKit and MediaRemote APIs. It is separate from the normal app.")
                }

                Section("Locked-Screen Session") {
                    Button(experiment.isRunning ? "Stop Experiment" : "Start Experiment") {
                        experiment.isRunning ? experiment.stop() : experiment.start()
                    }
                    .buttonStyle(.borderedProminent)
                    LabeledContent("Status", value: experiment.isRunning ? "Active" : "Stopped")
                    LabeledContent("Last Result", value: experiment.lastResult)
                    Text("Starting plays an effectively inaudible loop and publishes a Now Playing session. Lock the iPhone, open Now Playing, then press its Next button.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Now Playing Remote") {
                    Picker("Buttons", selection: $experiment.nowPlayingStyle) {
                        ForEach(NowPlayingButtonStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    HStack {
                        Button("Previous", systemImage: "chevron.backward") {
                            experiment.send(.previousPage, source: "Labs button")
                        }
                        Button("Next", systemImage: "chevron.forward") {
                            experiment.send(.nextPage, source: "Labs button")
                        }
                    }
                    .disabled(!experiment.isRunning)
                    LabeledContent("Remote Commands", value: experiment.remoteCommandCount.formatted())
                    Text("Previous and Next Track, or the 10-second backward and forward controls, map to the matching KOReader page action. The button style updates while the session is active.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Volume Buttons") {
                    Picker("Capture Mode", selection: $experiment.volumeMode) {
                        ForEach(VolumeCaptureMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Text(experiment.volumeMode.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Volume Up", value: "Next Page")
                    LabeledContent("Volume Down", value: "Previous Page")
                    LabeledContent("Raw Capture", value: experiment.privateCaptureEnabled ? "Active" : "Off")
                    LabeledContent("System Volume", value: experiment.outputVolume.formatted(.number.precision(.fractionLength(2))))
                    LabeledContent("Events", value: experiment.volumeEventCount.formatted())
                    LabeledContent("Last Input", value: experiment.lastInput)
                }

                Section("Private MediaRemote") {
                    Button("Inspect Symbols") { privateSymbols = PrivateFrameworkProbe.inspectMediaRemote() }
                    Button("Claim Now Playing") { mediaRemoteResult = PrivateFrameworkProbe.claimNowPlaying(true) }
                        .disabled(!experiment.isRunning)
                    LabeledContent("Invocation", value: mediaRemoteResult)
                    ForEach(privateSymbols) { item in
                        LabeledContent(item.name, value: item.available ? "Present" : "Missing")
                    }
                }

                Section("Limits") {
                    Text("Sideloading allows private calls but does not remove iOS sandboxing, background suspension, or entitlement checks. System-wide interception would require a jailbroken iPhone and a SpringBoard tweak.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Remote Labs")
        }
        .overlay(alignment: .bottomTrailing) {
            SystemVolumeView(volumeView: experiment.systemVolumeView)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
        .onDisappear { experiment.stop() }
    }
}
