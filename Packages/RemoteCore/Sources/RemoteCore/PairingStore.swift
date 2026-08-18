import Foundation
#if canImport(Security)
import Security
#endif

public protocol SecretStoring: Sendable {
    func load() throws -> Data?
    func save(_ secret: Data) throws
    func delete() throws
}

public enum StorageError: Error, Equatable, LocalizedError, Sendable {
    case encodingFailed
    case keychain(Int32)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: "The Kindle configuration could not be saved."
        case let .keychain(status): "Keychain returned error \(status)."
        }
    }
}

public struct PairingStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let secrets: any SecretStoring
    private let endpointKey = "pairedKindleEndpoint"

    public init(defaults: UserDefaults? = nil, secrets: any SecretStoring = KeychainSecretStore()) {
        self.defaults = defaults ?? UserDefaults(suiteName: ProtocolConstants.appGroup) ?? .standard
        self.secrets = secrets
    }

    public func load() throws -> PairingConfiguration? {
        guard
            let endpointData = defaults.data(forKey: endpointKey),
            let endpoint = try? JSONDecoder().decode(KindleEndpoint.self, from: endpointData),
            let secret = try secrets.load()
        else {
            return nil
        }
        return try PairingConfiguration(endpoint: endpoint, secret: secret)
    }

    public func save(_ configuration: PairingConfiguration) throws {
        guard let endpointData = try? JSONEncoder().encode(configuration.endpoint) else {
            throw StorageError.encodingFailed
        }
        try secrets.save(configuration.secret)
        defaults.set(endpointData, forKey: endpointKey)
    }

    public func forget() throws {
        defaults.removeObject(forKey: endpointKey)
        try secrets.delete()
    }
}

#if canImport(Security)
public struct KeychainSecretStore: SecretStoring {
    public init() {}

    public func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw StorageError.keychain(status) }
        return result as? Data
    }

    public func save(_ secret: Data) throws {
        let status = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: secret] as CFDictionary
        )
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw StorageError.keychain(status) }

        var query = baseQuery
        query[kSecValueData as String] = secret
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw StorageError.keychain(addStatus) }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "git.shin.koreaderRemoteTurner",
            kSecAttrAccount as String: ProtocolConstants.secretAccount,
            kSecAttrSynchronizable as String: false,
        ]
    }
}
#else
public struct KeychainSecretStore: SecretStoring {
    public init() {}
    public func load() throws -> Data? { nil }
    public func save(_ secret: Data) throws { throw StorageError.keychain(-1) }
    public func delete() throws {}
}
#endif
