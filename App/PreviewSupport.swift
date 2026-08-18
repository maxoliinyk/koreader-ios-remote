//
//  PreviewSupport.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import RemoteCore

extension RemoteStore {
    static func preview(paired: Bool = true, activity: Activity = .idle) -> RemoteStore {
        let suite = UserDefaults(suiteName: "KOReaderiOSRemote.preview.\(UUID().uuidString)")!
        let store = RemoteStore(storage: PairingStore(defaults: suite, secrets: PreviewSecretStore()))
        var configuration: PairingConfiguration?
        if paired {
            configuration = try? PairingConfiguration(
                endpoint: KindleEndpoint(name: "Bedroom Reader", host: "192.168.1.20"),
                secret: Data(repeating: 1, count: 32)
            )
        }
        store.setPreviewState(configuration: configuration, activity: activity)
        return store
    }
}

final class PreviewSecretStore: SecretStoring, @unchecked Sendable {
    private var value: Data?
    func load() throws -> Data? { value }
    func save(_ secret: Data) throws { value = secret }
    func delete() throws { value = nil }
}
