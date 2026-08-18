import Foundation
import RemoteCore
import WatchConnectivity

final class PhoneConnectivity: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneConnectivity()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let storage = PairingStore()

    private override init() {
        super.init()
    }

    func activate() {
        session?.delegate = self
        session?.activate()
        if let configuration = try? storage.load() {
            sync(configuration)
        }
    }

    func sync(_ configuration: PairingConfiguration?) {
        guard let session else { return }
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

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let value = message["action"] as? String, let action = RemoteAction(rawValue: value) else {
            replyHandler(["ok": false, "message": "Invalid action"])
            return
        }
        Task {
            do {
                guard let configuration = try storage.load() else {
                    replyHandler(["ok": false, "message": "Kindle is not paired"])
                    return
                }
                _ = try await KindleClient().send(action, using: configuration)
                replyHandler(["ok": true])
            } catch {
                replyHandler(["ok": false, "message": error.localizedDescription])
            }
        }
    }
}
