//
//  RemoteLayoutStyle.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import SwiftUI

enum RemoteLayoutStyle: String, CaseIterable, Identifiable {
    case fullSplit
    case nextFocused
    case compact

    static let storageKey = "remoteLayoutStyle"

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .fullSplit: "Full Split"
        case .nextFocused: "Next Focused"
        case .compact: "Compact"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .fullSplit: "Previous and Next share the available screen."
        case .nextFocused: "Next gets a larger tap area for one-handed reading."
        case .compact: "Smaller controls leave more open space on screen."
        }
    }

    var symbol: String {
        switch self {
        case .fullSplit: "rectangle.split.2x1"
        case .nextFocused: "rectangle.righthalf.filled"
        case .compact: "rectangle.compress.vertical"
        }
    }
}

private struct RemoteLayoutPreviewOverrideKey: EnvironmentKey {
    static let defaultValue: RemoteLayoutStyle? = nil
}

extension EnvironmentValues {
    var remoteLayoutPreviewOverride: RemoteLayoutStyle? {
        get { self[RemoteLayoutPreviewOverrideKey.self] }
        set { self[RemoteLayoutPreviewOverrideKey.self] = newValue }
    }
}
