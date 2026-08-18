import Foundation
import RemoteCore
import WatchConnectivity

extension Notification.Name {
    static let watchPairingChanged = Notification.Name("watchPairingChanged")
}

enum WatchConnectivityError: Error, LocalizedError {
    case phoneUnavailable
    case relayFailed(String)

    var errorDescription: String? {
        switch self {
        case .phoneUnavailable: "The paired iPhone is unavailable."
        case let .relayFailed(message): message
        }
    }
}

final class WatchConnectivityBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchConnectivityBridge()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let storage = PairingStore(defaults: .standard)

    private override init() {
        super.init()
    }

    func activate() {
        session?.delegate = self
        session?.activate()
        if let context = session?.receivedApplicationContext, !context.isEmpty {
            apply(context)
        }
    }

    func relay(_ action: RemoteAction) async throws {
        guard let session, session.isReachable else {
            throw WatchConnectivityError.phoneUnavailable
        }
        try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                ["action": action.rawValue],
                replyHandler: { reply in
                    if reply["ok"] as? Bool == true {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: WatchConnectivityError.relayFailed(
                            reply["message"] as? String ?? "The iPhone could not send the action."
                        ))
                    }
                },
                errorHandler: { error in continuation.resume(throwing: error) }
            )
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ context: [String: Any]) {
        do {
            if context["forgotten"] as? Bool == true {
                try storage.forget()
            } else if let data = context["configuration"] as? Data {
                let transfer = try JSONDecoder().decode(PairingTransfer.self, from: data)
                try storage.save(transfer.configuration())
            } else {
                return
            }
            NotificationCenter.default.post(name: .watchPairingChanged, object: nil)
        } catch {
            // Keep the last valid pairing if a transfer is malformed.
        }
    }
}
