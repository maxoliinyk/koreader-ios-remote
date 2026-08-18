//
//  RequestSigner.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import CryptoKit
import Foundation

public enum RequestSigner {
    public static func canonical(version: Int, action: String, nonce: String) -> String {
        "version=\(version)\naction=\(action)\nnonce=\(nonce)"
    }

    public static func mac(version: Int, action: String, nonce: String, secret: Data) -> String {
        let input = Data(canonical(version: version, action: action, nonce: nonce).utf8)
        let code = HMAC<SHA256>.authenticationCode(for: input, using: SymmetricKey(data: secret))
        return code.map { String(format: "%02x", $0) }.joined()
    }

    public static func nonce(byteCount: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        var generator = SystemRandomNumberGenerator()
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max, using: &generator)
        }
        return Data(bytes).base64URLEncodedString
    }
}
