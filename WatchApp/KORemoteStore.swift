//
//  KORemoteStore.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import Observation
import RemoteCore
import WatchKit

@MainActor
@Observable
final class KORemoteStore {
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
#if DEBUG && targetEnvironment(simulator)
    private var didRunSimulatorAction = false
#endif

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
        guard state != .sending else { return }
        guard let configuration else {
            state = .failure(String(localized: "Pair KOReader on your iPhone first."))
            WKInterfaceDevice.current().play(.failure)
            return
        }
        state = .sending

        do {
            _ = try await client.send(action, using: configuration)
            succeed()
            return
        } catch let error as KindleClientError where error == .unreachable {
            do {
                try await connectivity.relay(action)
                succeed()
            } catch {
                state = .failure(error.localizedDescription)
                WKInterfaceDevice.current().play(.failure)
            }
        } catch {
            state = .failure(error.localizedDescription)
            WKInterfaceDevice.current().play(.failure)
        }
    }

#if DEBUG && targetEnvironment(simulator)
    func runSimulatorActionIfRequested() async {
        guard
            !didRunSimulatorAction,
            let value = ProcessInfo.processInfo.environment["KOREMOTE_SIMULATOR_WATCH_ACTION"],
            let action = RemoteAction(rawValue: value)
        else { return }
        didRunSimulatorAction = true

        // Give WatchConnectivity a short opportunity to deliver the real context.
        for _ in 0..<30 {
            reload()
            if configuration != nil { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        // WatchConnectivity delivery is unreliable in Simulator. Seed the same
        // local mock pairing so the Watch request path remains testable there.
        if configuration == nil,
           let value = ProcessInfo.processInfo.environment["KOREMOTE_SIMULATOR_WATCH_PAIRING_URL"],
           let url = URL(string: value),
           let pairing = try? PairingPayload(url: url).configuration {
            try? storage.save(pairing)
            reload()
        }

        guard configuration != nil else { return }
        await send(action)
    }
#endif

    private func reload() {
        configuration = try? storage.load()
        if configuration == nil { state = .ready }
    }

    private func succeed() {
        state = .success
        WKInterfaceDevice.current().play(.success)
    }
}
