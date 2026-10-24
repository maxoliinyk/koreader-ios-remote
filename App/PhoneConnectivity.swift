//
//  PhoneConnectivity.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import RemoteCore
import WatchConnectivity

private nonisolated struct WatchReply: @unchecked Sendable {
    let send: ([String: Any]) -> Void
}

final class PhoneConnectivity: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneConnectivity()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let storage = PairingStore()
    private let client = KindleClient()

    private override init() {
        super.init()
    }

    func activate() {
        session?.delegate = self
        session?.activate()
    }

    func sync(_ configuration: PairingConfiguration?) {
        guard let session, session.activationState == .activated, session.isWatchAppInstalled else { return }
        do {
            let context: [String: Any]
            if let configuration {
                context = ["configuration": try JSONEncoder().encode(PairingTransfer(configuration: configuration))]
            } else {
                context = ["forgotten": true]
            }
            try session.updateApplicationContext(context)
        } catch {
            // The current configuration remains available for the next activation retry.
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor [weak self] in self?.syncCurrentPairing() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.syncCurrentPairing() }
    }

    private func syncCurrentPairing() {
        do {
            sync(try storage.load())
        } catch {
            // Retry after the next activation without replacing the Watch pairing.
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let value = message["action"] as? String, let action = RemoteAction(rawValue: value) else {
            replyHandler(["ok": false, "message": "Invalid action"])
            return
        }
        guard let pairingIdentifier = message["pairingIdentifier"] as? String else {
            replyHandler(["ok": false, "message": "Update the Watch app and pair KOReader again."])
            return
        }
        let reply = WatchReply(send: replyHandler)
        Task { @MainActor [weak self] in
            do {
                guard let self, let configuration = try storage.load() else {
                    reply.send(["ok": false, "message": "KOReader is not paired"])
                    return
                }
                guard configuration.watchRelayIdentifier == pairingIdentifier else {
                    sync(configuration)
                    reply.send(["ok": false, "message": "Pairing changed. Wait for the Watch to sync, then try again."])
                    return
                }
                _ = try await client.send(action, using: configuration)
                reply.send(["ok": true])
            } catch {
                reply.send(["ok": false, "message": error.localizedDescription])
            }
        }
    }
}
