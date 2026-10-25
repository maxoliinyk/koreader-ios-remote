//
//  AirPodsGestureStore.swift
//  KORemote
//
//  Created by Max Oliinyk on 25.10.26.
//

import CoreMotion
import Observation
import RemoteCore

@MainActor
@Observable
final class AirPodsGestureStore: NSObject {
    var isEnabled = false {
        didSet { updateListening() }
    }
    var thresholdDegrees = 18.0 {
        didSet { recalibrate() }
    }
    var isConfirmationPresented = false {
        didSet { updateListening() }
    }
    private(set) var status = String(localized: "Off")
    private(set) var isRunning = false
    private(set) var lastGesture: String?

    @ObservationIgnored private let motion = CMHeadphoneMotionManager()
    @ObservationIgnored private var detector = HeadGestureDetector()
    @ObservationIgnored private var reference: CMAttitude?
    @ObservationIgnored private var stableSince: Double?
    @ObservationIgnored private var lastTimestamp: Double?
    @ObservationIgnored private var session = UUID()
    @ObservationIgnored private var isAllowed = false
    @ObservationIgnored private var onGesture: (@MainActor (RemoteAction) -> Void)?
    @ObservationIgnored private var startupTimeout: Task<Void, Never>?

    func setListeningAllowed(_ allowed: Bool, onGesture: @escaping @MainActor (RemoteAction) -> Void) {
        self.onGesture = onGesture
        guard isAllowed != allowed else { return }
        isAllowed = allowed
        updateListening()
    }

    func recalibrate() {
        reference = nil
        stableSince = nil
        lastTimestamp = nil
        lastGesture = nil
        detector = HeadGestureDetector(thresholdDegrees: thresholdDegrees)
        if isRunning { status = String(localized: "Hold your head still to calibrate…") }
    }

    func retry() {
        stop()
        updateListening()
    }

    private func updateListening() {
        guard isEnabled, isAllowed, !isConfirmationPresented else {
            stop()
            status = isEnabled ? String(localized: "Paused · open Remote to use") : String(localized: "Off")
            return
        }
        guard !isRunning else { return }
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            stop()
            status = String(localized: "Motion access denied. Allow Motion & Fitness in iPhone Settings.")
            return
        default:
            break
        }

        motion.delegate = self
        if !motion.isConnectionStatusActive { motion.startConnectionStatusUpdates() }
        guard motion.isDeviceMotionAvailable else {
            status = String(localized: "Connect AirPods that support head tracking, then retry.")
            return
        }

        recalibrate()
        isRunning = true
        status = String(localized: "Waiting for AirPods motion…")
        let currentSession = UUID()
        session = currentSession
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, error in
            MainActor.assumeIsolated {
                guard let self, self.session == currentSession, self.isRunning else { return }
                if let error {
                    self.stop()
                    self.status = error.localizedDescription
                    return
                }
                guard let sample else { return }
                self.startupTimeout?.cancel()
                self.startupTimeout = nil
                self.consume(sample)
            }
        }
        startupTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            guard let self, self.session == currentSession else { return }
            self.stop()
            self.status = String(localized: "No motion received. Check AirPods and Motion & Fitness access, then retry.")
        }
    }

    private func stop() {
        session = UUID()
        startupTimeout?.cancel()
        startupTimeout = nil
        motion.stopDeviceMotionUpdates()
        motion.stopConnectionStatusUpdates()
        isRunning = false
        recalibrate()
    }

    private func consume(_ sample: CMDeviceMotion) {
        if let lastTimestamp, sample.timestamp - lastTimestamp > 0.3 || sample.timestamp <= lastTimestamp {
            recalibrate()
        }
        lastTimestamp = sample.timestamp

        guard let reference else {
            let rotation = sample.rotationRate
            let speed = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
            status = String(localized: "Hold your head still to calibrate…")
            guard speed < 0.2 else {
                stableSince = nil
                return
            }
            if stableSince == nil { stableSince = sample.timestamp }
            if let stableSince, sample.timestamp - stableSince >= 0.6 {
                self.reference = sample.attitude.copy() as? CMAttitude
                status = String(localized: "Ready · nod for next, shake for previous")
            }
            return
        }

        guard let relative = sample.attitude.copy() as? CMAttitude else { return }
        relative.multiply(byInverseOf: reference)
        guard let action = detector.consume(pitch: relative.pitch, yaw: relative.yaw, timestamp: sample.timestamp) else { return }
        lastGesture = action == .nextPage ? String(localized: "Nod · next page") : String(localized: "Shake · previous page")
        onGesture?(action)
    }
}

extension AirPodsGestureStore: CMHeadphoneMotionManagerDelegate {
    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            guard let self, self.isEnabled, self.isAllowed, !self.isRunning else { return }
            self.updateListening()
        }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak self] in
            guard let self, self.isEnabled, self.isAllowed else { return }
            self.stop()
            self.updateListening()
        }
    }
}
