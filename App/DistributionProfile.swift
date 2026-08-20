//
//  DistributionProfile.swift
//  KORemote
//
//  Created by Max Oliinyk on 20.08.26.
//

import Foundation

enum DistributionProfile: Equatable, Sendable {
    case full
    case personalTeam
    case altStore

    static let current: Self = {
#if KOREMOTE_FREE
        .personalTeam
#elseif KOREMOTE_ALTSTORE
        .altStore
#else
        .full
#endif
    }()

    var title: String {
        switch self {
        case .full: "Full"
        case .personalTeam: "Personal Team"
        case .altStore: "AltStore Classic"
        }
    }

    var keepsVolumeCaptureWhileInactive: Bool {
        switch self {
        case .full: false
        case .personalTeam, .altStore: true
        }
    }

    var supportsMediaControls: Bool {
        switch self {
        case .full: false
        case .personalTeam, .altStore: true
        }
    }

    var includesWatchCompanion: Bool {
#if KOREMOTE_HAS_WATCH
        true
#else
        false
#endif
    }

    var includesControlCenterWidgets: Bool {
#if KOREMOTE_HAS_CONTROLS
        true
#else
        false
#endif
    }
}
