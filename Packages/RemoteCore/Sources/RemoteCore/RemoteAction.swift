//
//  RemoteAction.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum RemoteAction: String, Codable, CaseIterable, Sendable {
    case nextPage = "next"
    case previousPage = "previous"
    case sleep
}

public struct KindleEndpoint: Codable, Equatable, Sendable {
    public static let defaultPort = 9090

    public var name: String
    public var host: String
    public var port: Int
    public var protocolVersion: Int

    public init(name: String, host: String, port: Int = Self.defaultPort, protocolVersion: Int = 1) {
        self.name = name
        self.host = host
        self.port = port
        self.protocolVersion = protocolVersion
    }

    public func validated() throws -> Self {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        guard protocolVersion == ProtocolConstants.version else {
            throw PairingError.unsupportedVersion(protocolVersion)
        }
        guard !cleanName.isEmpty, cleanName.count <= 64 else {
            throw PairingError.invalidDeviceName
        }
        guard HostValidator.isValid(cleanHost) else {
            throw PairingError.invalidHost
        }
        guard (1...65_535).contains(port) else {
            throw PairingError.invalidPort
        }

        return Self(name: cleanName, host: cleanHost, port: port, protocolVersion: protocolVersion)
    }

    public func url(path: String) throws -> URL {
        let endpoint = try validated()
        var components = URLComponents()
        components.scheme = "http"
        components.host = endpoint.host.contains(":") ? "[\(endpoint.host)]" : endpoint.host
        components.port = endpoint.port
        components.path = path
        guard let url = components.url else { throw PairingError.invalidHost }
        return url
    }
}

public enum ProtocolConstants {
    public static let version = 1
    public static let actionPath = "/v1/action"
    public static let pingPath = "/v1/ping"
    public static let appGroup = "group.com.maxoliinyk.koreaderremote"
    public static let secretAccount = "koreader-pairing-secret"
}

enum HostValidator {
    static func isValid(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253, !host.contains(where: { $0.isWhitespace }) else {
            return false
        }

        if host.contains(":") {
            var address = in6_addr()
            return host.withCString { inet_pton(AF_INET6, $0, &address) } == 1
        }

        if host.allSatisfy({ $0.isNumber || $0 == "." }) {
            var address = in_addr()
            return host.withCString { inet_pton(AF_INET, $0, &address) } == 1
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            !label.isEmpty && label.count <= 63 && label.range(
                of: "^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$",
                options: .regularExpression
            ) != nil
        }
    }
}
