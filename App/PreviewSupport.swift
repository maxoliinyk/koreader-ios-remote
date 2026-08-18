import Foundation
import RemoteCore

extension RemoteStore {
    static func preview(paired: Bool = true) -> RemoteStore {
        let suite = UserDefaults(suiteName: "KOReaderRemote.preview.\(UUID().uuidString)")!
        let store = RemoteStore(storage: PairingStore(defaults: suite, secrets: PreviewSecretStore()))
        if paired {
            store.pair(
                name: "Bedroom Kindle",
                host: "192.168.1.20",
                port: 9090,
                secret: Data(repeating: 1, count: 32).base64URLEncodedString
            )
        }
        return store
    }
}

private final class PreviewSecretStore: SecretStoring, @unchecked Sendable {
    private var value: Data?
    func load() throws -> Data? { value }
    func save(_ secret: Data) throws { value = secret }
    func delete() throws { value = nil }
}
