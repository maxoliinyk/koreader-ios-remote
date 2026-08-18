import Foundation

public struct PairingConfiguration: Equatable, Sendable {
    public let endpoint: KindleEndpoint
    public let secret: Data

    public init(endpoint: KindleEndpoint, secret: Data) throws {
        self.endpoint = try endpoint.validated()
        guard secret.count == 32 else { throw PairingError.invalidSecret }
        self.secret = secret
    }
}

public struct PairingPayload: Equatable, Sendable {
    public let configuration: PairingConfiguration

    public init(url: URL) throws {
        guard url.scheme?.lowercased() == "koreaderturner", url.host?.lowercased() == "pair" else {
            throw PairingError.invalidURL
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw PairingError.invalidURL
        }

        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard let value = item.value, values[item.name] == nil else {
                throw PairingError.invalidURL
            }
            values[item.name] = value
        }

        guard
            let versionText = values["v"], let version = Int(versionText),
            let host = values["host"],
            let portText = values["port"], let port = Int(portText),
            let name = values["name"],
            let secretText = values["secret"],
            let secret = Data(base64URLEncoded: secretText)
        else {
            throw PairingError.missingField
        }

        configuration = try PairingConfiguration(
            endpoint: KindleEndpoint(name: name, host: host, port: port, protocolVersion: version),
            secret: secret
        )
    }
}

public enum PairingError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case missingField
    case unsupportedVersion(Int)
    case invalidDeviceName
    case invalidHost
    case invalidPort
    case invalidSecret

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "This is not a KOReader Remote pairing code."
        case .missingField: "The pairing code is incomplete."
        case let .unsupportedVersion(version): "Protocol version \(version) is not supported."
        case .invalidDeviceName: "Enter a valid Kindle name."
        case .invalidHost: "Enter a valid Kindle address."
        case .invalidPort: "Enter a port from 1 to 65535."
        case .invalidSecret: "The pairing secret must contain 32 bytes."
        }
    }
}

public extension Data {
    init?(base64URLEncoded value: String) {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }

    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
