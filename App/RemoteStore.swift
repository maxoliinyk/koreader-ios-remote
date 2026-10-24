//
//  RemoteStore.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import Observation
import OSLog
import RemoteCore

@MainActor
@Observable
final class RemoteStore {
    enum Activity: Equatable {
        case idle
        case testingConnection
        case connectionReady
        case sending(RemoteAction)
        case success(String)
        case failure(String)
    }

    private(set) var configuration: PairingConfiguration?
    private(set) var activity: Activity = .idle
    var isPairingPresented = false

    private var pairingRevision = UUID()
    private let client: KindleClient
    private let storage: PairingStore
    private let logger = Logger(subsystem: "com.maxoliinyk.koreaderremote", category: "remote")
#if DEBUG && targetEnvironment(simulator)
    private var didRunSimulatorPairing = false
#endif

    init(client: KindleClient = KindleClient(), storage: PairingStore = PairingStore()) {
        self.client = client
        self.storage = storage
        do {
            configuration = try storage.load()
        } catch {
            activity = .failure(String(localized: "The saved KOReader device could not be loaded."))
        }
    }

    var isSending: Bool {
        switch activity {
        case .sending, .testingConnection: true
        case .idle, .connectionReady, .success, .failure: false
        }
    }

    func clearPairingError() {
        if case .failure = activity { activity = .idle }
    }

    func pair(with url: URL) {
        do {
            try completePairing(PairingPayload(url: url).configuration)
        } catch {
            fail(error)
        }
    }

    func pair(name: String, host: String, port: Int, secret: String) {
        do {
            guard let secretData = Data(base64URLEncoded: secret.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw PairingError.invalidSecret
            }
            let value = try PairingConfiguration(
                endpoint: KindleEndpoint(name: name, host: host, port: port),
                secret: secretData
            )
            try completePairing(value)
        } catch {
            fail(error)
        }
    }

    func send(_ action: RemoteAction) async {
        guard let configuration else {
            isPairingPresented = true
            return
        }
        guard !isSending else { return }
        let revision = pairingRevision
        activity = .sending(action)

        do {
            _ = try await client.send(action, using: configuration)
            guard revision == pairingRevision else { return }
            activity = .success(successMessage(for: action))
            Feedback.success()
        } catch {
            guard revision == pairingRevision else { return }
            fail(error)
        }
    }

    func testConnection() async {
        guard let configuration else {
            isPairingPresented = true
            return
        }
        guard !isSending else { return }
        let revision = pairingRevision
        activity = .testingConnection

        do {
            _ = try await client.ping(using: configuration)
            guard revision == pairingRevision else { return }
            activity = .connectionReady
            Feedback.success()
        } catch {
            guard revision == pairingRevision else { return }
            fail(error)
        }
    }

    func forget() {
        do {
            try storage.forget()
            pairingRevision = UUID()
            configuration = nil
            activity = .idle
            PhoneConnectivity.shared.sync(nil)
        } catch {
            fail(error)
        }
    }

#if DEBUG && targetEnvironment(simulator)
    func runSimulatorPairingIfRequested() {
        guard
            !didRunSimulatorPairing,
            let value = ProcessInfo.processInfo.environment["KOREMOTE_SIMULATOR_PAIRING_URL"],
            let url = URL(string: value)
        else { return }
        didRunSimulatorPairing = true
        pair(with: url)
    }
#endif

    private func completePairing(_ value: PairingConfiguration) throws {
        try storage.save(value)
        pairingRevision = UUID()
        configuration = value
        PhoneConnectivity.shared.sync(value)
        isPairingPresented = false
        activity = .success(String(localized: "KOReader paired."))
        Feedback.success()
        Task { await testConnection() }
    }

    private func fail(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong.")
        logger.error("Remote operation failed: \(message, privacy: .private)")
        activity = .failure(message)
        Feedback.error()
    }

    private func successMessage(for action: RemoteAction) -> String {
        switch action {
        case .nextPage: String(localized: "Next page sent.")
        case .previousPage: String(localized: "Previous page sent.")
        case .sleep: String(localized: "Sleep sent.")
        }
    }

#if DEBUG
    func setPreviewState(configuration: PairingConfiguration?, activity: Activity) {
        self.configuration = configuration
        self.activity = activity
    }
#endif
}
