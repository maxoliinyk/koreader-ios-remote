//
//  RemoteStore.swift
//  KOReaderRemote
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
        case sending(RemoteAction)
        case success(String)
        case failure(String)
    }

    private(set) var configuration: PairingConfiguration?
    private(set) var activity: Activity = .idle
    var isPairingPresented = false

    private let client: KindleClient
    private let storage: PairingStore
    private let logger = Logger(subsystem: "com.maxoliinyk.koreaderremote", category: "remote")

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
        if case .sending = activity { true } else { false }
    }

    func pair(with url: URL) {
        do {
            try save(PairingPayload(url: url).configuration)
            isPairingPresented = false
            activity = .success(String(localized: "KOReader paired."))
            Feedback.success()
            Task { await testConnection() }
        } catch {
            fail(error)
        }
    }

    func pair(name: String, host: String, port: Int, secret: String) {
        do {
            guard let secretData = Data(base64URLEncoded: secret) else {
                throw PairingError.invalidSecret
            }
            let value = try PairingConfiguration(
                endpoint: KindleEndpoint(name: name, host: host, port: port),
                secret: secretData
            )
            try save(value)
            isPairingPresented = false
            activity = .success(String(localized: "KOReader paired."))
            Feedback.success()
            Task { await testConnection() }
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
        activity = .sending(action)

        do {
            _ = try await client.send(action, using: configuration)
            activity = .success(successMessage(for: action))
            Feedback.success()
        } catch {
            fail(error)
        }
    }

    func testConnection() async {
        guard let configuration else {
            isPairingPresented = true
            return
        }
        guard !isSending else { return }
        activity = .sending(.nextPage)

        do {
            _ = try await client.ping(using: configuration)
            activity = .success(String(localized: "KOReader is ready."))
            Feedback.success()
        } catch {
            fail(error)
        }
    }

    func forget() {
        do {
            try storage.forget()
            configuration = nil
            activity = .idle
            PhoneConnectivity.shared.sync(nil)
        } catch {
            fail(error)
        }
    }

    private func save(_ value: PairingConfiguration) throws {
        try storage.save(value)
        configuration = value
        PhoneConnectivity.shared.sync(value)
    }

    private func fail(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? String(localized: "Something went wrong.")
        logger.error("Remote operation failed: \(message, privacy: .public)")
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
