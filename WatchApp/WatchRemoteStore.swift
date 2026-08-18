//
//  WatchRemoteStore.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import Observation
import RemoteCore
import WatchKit

@MainActor
@Observable
final class WatchRemoteStore {
    enum State: Equatable {
        case ready
        case sending
        case success
        case failure(String)
    }

    private(set) var configuration: PairingConfiguration?
    private(set) var state: State = .ready

    private let storage = PairingStore(defaults: .standard)
    private let client = KindleClient()
    private let connectivity = WatchConnectivityBridge.shared
    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .watchPairingChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func activate() {
        connectivity.activate()
        reload()
    }

    func send(_ action: RemoteAction) async {
        guard let configuration, state != .sending else {
            state = .failure(String(localized: "Pair KOReader on your iPhone first."))
            WKInterfaceDevice.current().play(.failure)
            return
        }
        state = .sending

        do {
            _ = try await client.send(action, using: configuration)
            succeed()
            return
        } catch {
            do {
                try await connectivity.relay(action)
                succeed()
            } catch {
                state = .failure(error.localizedDescription)
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func reload() {
        configuration = try? storage.load()
        if configuration == nil { state = .ready }
    }

    private func succeed() {
        state = .success
        WKInterfaceDevice.current().play(.success)
    }
}
