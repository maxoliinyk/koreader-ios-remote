//
//  PairingTransfer.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation

public struct PairingTransfer: Codable, Equatable, Sendable {
    public let endpoint: KindleEndpoint
    public let secret: String

    public init(configuration: PairingConfiguration) {
        endpoint = configuration.endpoint
        secret = configuration.secret.base64URLEncodedString
    }

    public func configuration() throws -> PairingConfiguration {
        guard let data = Data(base64URLEncoded: secret) else {
            throw PairingError.invalidSecret
        }
        return try PairingConfiguration(endpoint: endpoint, secret: data)
    }
}
