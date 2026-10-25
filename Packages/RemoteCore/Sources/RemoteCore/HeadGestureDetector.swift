//
//  HeadGestureDetector.swift
//  KORemote
//
//  Created by Max Oliinyk on 25.10.26.
//

import Foundation

/// Recognizes deliberate gestures relative to a calibrated resting position.
public struct HeadGestureDetector: Sendable {
    private struct Candidate: Sendable {
        let action: RemoteAction
        let startedAt: Double
        let yawSign: Double
        var reversed = false
    }

    private let threshold: Double
    private var lastTimestamp: Double?
    private var neutralSince: Double?
    private var isArmed = false
    private var candidate: Candidate?
    private var cooldownUntil = 0.0

    public init(thresholdDegrees: Double = 18) {
        threshold = (thresholdDegrees.isFinite ? min(30, max(10, thresholdDegrees)) : 18) * .pi / 180
    }

    public mutating func consume(pitch: Double, yaw: Double, timestamp: Double) -> RemoteAction? {
        guard pitch.isFinite, yaw.isFinite, timestamp.isFinite, timestamp >= 0 else {
            reset()
            return nil
        }
        if let lastTimestamp, timestamp <= lastTimestamp || timestamp - lastTimestamp > 0.3 {
            reset()
        }
        lastTimestamp = timestamp
        guard timestamp >= cooldownUntil else { return nil }

        let isNeutral = abs(pitch) < threshold * 0.35 && abs(yaw) < threshold * 0.35

        if var gesture = candidate {
            let elapsed = timestamp - gesture.startedAt
            let crossAxis = gesture.action == .nextPage ? abs(yaw) : abs(pitch)
            guard elapsed <= 1.5, crossAxis < threshold else {
                disarm()
                return nil
            }
            if gesture.action == .previousPage, yaw * gesture.yawSign <= -threshold {
                gesture.reversed = true
                candidate = gesture
            }
            if isNeutral, gesture.action == .nextPage || gesture.reversed {
                disarm()
                guard elapsed >= 0.12 else { return nil }
                cooldownUntil = timestamp + 1.2
                return gesture.action
            }
            return nil
        }

        if isNeutral {
            if neutralSince == nil { neutralSince = timestamp }
            if let neutralSince, timestamp - neutralSince >= 0.25 { isArmed = true }
            return nil
        }
        neutralSince = nil
        guard isArmed else { return nil }

        if abs(pitch) >= threshold, abs(pitch) > abs(yaw) * 1.6 {
            candidate = Candidate(action: .nextPage, startedAt: timestamp, yawSign: 0)
        } else if abs(yaw) >= threshold, abs(yaw) > abs(pitch) * 1.6 {
            candidate = Candidate(action: .previousPage, startedAt: timestamp, yawSign: yaw.sign == .minus ? -1 : 1)
        } else if max(abs(pitch), abs(yaw)) >= threshold {
            disarm()
        }
        return nil
    }

    private mutating func disarm() {
        candidate = nil
        isArmed = false
        neutralSince = nil
    }

    private mutating func reset() {
        disarm()
        lastTimestamp = nil
        cooldownUntil = 0
    }
}
