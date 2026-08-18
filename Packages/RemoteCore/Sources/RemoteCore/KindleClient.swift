//
//  KindleClient.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ActionResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let message: String?

    public init(ok: Bool, message: String? = nil) {
        self.ok = ok
        self.message = message
    }
}

private struct SignedRequest: Codable, Sendable {
    let version: Int
    let action: String
    let nonce: String
    let mac: String
}

public enum KindleClientError: Error, Equatable, LocalizedError, Sendable {
    case invalidConfiguration
    case localNetworkDenied
    case timedOut
    case unreachable
    case invalidResponse
    case authenticationFailed
    case replayRejected
    case portConflict
    case server(status: Int, message: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "The paired KOReader configuration is invalid."
        case .localNetworkDenied: "Local Network access is off. Enable it in Settings to reach KOReader."
        case .timedOut: "KOReader did not respond. Check that it is open and both devices use the same Wi‑Fi."
        case .unreachable: "The KOReader device could not be reached on the local network."
        case .invalidResponse: "KOReader returned an unreadable response."
        case .authenticationFailed: "The pairing secret no longer matches. Scan a new code from KOReader."
        case .replayRejected: "KOReader rejected a repeated request. Try again."
        case .portConflict: "KOReader could not use the configured listener port."
        case let .server(status, message): message ?? "KOReader returned error \(status)."
        }
    }
}

public actor KindleClient {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 3
            configuration.timeoutIntervalForResource = 5
            configuration.waitsForConnectivity = false
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    public func send(_ action: RemoteAction, using configuration: PairingConfiguration) async throws -> ActionResponse {
        try await perform(action: action.rawValue, path: ProtocolConstants.actionPath, using: configuration)
    }

    public func ping(using configuration: PairingConfiguration) async throws -> ActionResponse {
        try await perform(action: "ping", path: ProtocolConstants.pingPath, using: configuration)
    }

    private func perform(action: String, path: String, using configuration: PairingConfiguration) async throws -> ActionResponse {
        let nonce = RequestSigner.nonce()
        let signed = SignedRequest(
            version: configuration.endpoint.protocolVersion,
            action: action,
            nonce: nonce,
            mac: RequestSigner.mac(
                version: configuration.endpoint.protocolVersion,
                action: action,
                nonce: nonce,
                secret: configuration.secret
            )
        )

        let url: URL
        do {
            url = try configuration.endpoint.url(path: path)
        } catch {
            throw KindleClientError.invalidConfiguration
        }

        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(signed)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw KindleClientError.invalidResponse
            }

            let payload = try? decoder.decode(ActionResponse.self, from: data)
            switch http.statusCode {
            case 200..<300:
                guard let payload, payload.ok else { throw KindleClientError.invalidResponse }
                return payload
            case 401: throw KindleClientError.authenticationFailed
            case 409: throw KindleClientError.replayRejected
            case 423: throw KindleClientError.portConflict
            default: throw KindleClientError.server(status: http.statusCode, message: payload?.message)
            }
        } catch let error as KindleClientError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
                throw KindleClientError.unreachable
            case .timedOut:
                throw KindleClientError.timedOut
            case .dataNotAllowed, .internationalRoamingOff:
                throw KindleClientError.localNetworkDenied
            default:
                throw KindleClientError.unreachable
            }
        } catch {
            throw KindleClientError.invalidResponse
        }
    }
}
