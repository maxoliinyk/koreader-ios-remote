//
//  Feedback.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import UIKit

@MainActor
enum Feedback {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
