//
//  HeadGestureDetectorTests.swift
//  KORemote
//
//  Created by Max Oliinyk on 25.10.26.
//

import Testing
@testable import RemoteCore

@Suite("Head gestures")
struct HeadGestureDetectorTests {
    private typealias Frame = (time: Double, pitch: Double, yaw: Double)

    @Test(arguments: [-1.0, 1.0])
    func nodTurnsOnePageAfterReturningToCenter(direction: Double) {
        #expect(replay([
            (0, 0, 0), (0.4, 0, 0), (0.6, 25 * direction, 0),
            (0.8, 0, 0), (1.2, 0, 0),
        ]) == [.nextPage])
        #expect(replay([
            (0, 0, 0), (0.4, 0, 0), (0.6, 25 * direction, 0),
        ]).isEmpty)
    }

    @Test(arguments: [-1.0, 1.0])
    func shakeRequiresBothSidesAndReturnToCenter(direction: Double) {
        #expect(replay([
            (0, 0, 0), (0.4, 0, 0), (0.6, 0, 25 * direction),
            (1.0, 0, -25 * direction), (1.2, 0, 0),
        ]) == [.previousPage])
        #expect(replay([
            (0, 0, 0), (0.4, 0, 0), (0.6, 0, 25 * direction),
            (0.8, 0, 0), (2.5, 0, 0),
        ]).isEmpty)
    }

    @Test func smallDiagonalAndHeldMovementsDoNotTurnPages() {
        #expect(replay([(0, 0, 0), (0.4, 0, 0), (0.6, 8, 8), (0.8, 0, 0)]).isEmpty)
        #expect(replay([(0, 0, 0), (0.4, 0, 0), (0.6, 25, 25), (0.8, 0, 0)]).isEmpty)
        #expect(replay([
            (0, 0, 0), (0.4, 0, 0), (0.6, 25, 0), (2.4, 25, 0), (2.6, 0, 0),
        ]).isEmpty)
    }

    @Test func cooldownSuppressesRepeatedNodsThenRearms() {
        #expect(replay([
            (0, 0, 0), (0.4, 0, 0), (0.6, 25, 0), (0.8, 0, 0),
            (1.0, 25, 0), (1.2, 0, 0), (2.4, 0, 0),
            (2.6, 25, 0), (2.8, 0, 0),
        ]) == [.nextPage, .nextPage])
    }

    @Test func movementBeforeSettlingDoesNotTurnPages() {
        #expect(replay([(0, 0, 0), (0.1, 25, 0), (0.2, 0, 0)]).isEmpty)
    }

    @Test func interruptedOrInvalidSamplesDiscardPendingGesture() {
        for interruptedTime in [0.55, 1.5, Double.nan] {
            var detector = HeadGestureDetector()
            for time in [0.0, 0.1, 0.2, 0.3, 0.4] {
                #expect(detector.consume(pitch: 0, yaw: 0, timestamp: time) == nil)
            }
            #expect(detector.consume(pitch: 0.45, yaw: 0, timestamp: 0.6) == nil)
            #expect(detector.consume(pitch: 0, yaw: 0, timestamp: interruptedTime) == nil)
            #expect(detector.consume(pitch: 0, yaw: 0, timestamp: 1.6) == nil)
        }
    }

    @Test func gestureSizeChangesRequiredMovement() {
        let frames: [Frame] = [(0, 0, 0), (0.4, 0, 0), (0.6, 15, 0), (0.8, 0, 0)]
        #expect(replay(frames, threshold: 10) == [.nextPage])
        #expect(replay(frames, threshold: 30).isEmpty)
    }

    private func replay(_ frames: [Frame], threshold: Double = 18) -> [RemoteAction] {
        var detector = HeadGestureDetector(thresholdDegrees: threshold)
        var actions: [RemoteAction] = []
        for (start, end) in zip(frames, frames.dropFirst()) {
            let steps = Int(((end.time - start.time) / 0.02).rounded())
            for step in 0..<steps {
                let fraction = Double(step) / Double(steps)
                let pitch = start.pitch + (end.pitch - start.pitch) * fraction
                let yaw = start.yaw + (end.yaw - start.yaw) * fraction
                let time = start.time + (end.time - start.time) * fraction
                if let action = detector.consume(pitch: pitch * .pi / 180, yaw: yaw * .pi / 180, timestamp: time) {
                    actions.append(action)
                }
            }
        }
        if let last = frames.last,
           let action = detector.consume(pitch: last.pitch * .pi / 180, yaw: last.yaw * .pi / 180, timestamp: last.time) {
            actions.append(action)
        }
        return actions
    }
}
