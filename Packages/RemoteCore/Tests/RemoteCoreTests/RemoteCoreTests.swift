//
//  RemoteCoreTests.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import Testing
@testable import RemoteCore

@Suite("Pairing payload")
struct PairingPayloadTests {
    @Test func parsesValidURL() throws {
        let secret = Data(repeating: 7, count: 32)
        let encodedName = "Bedroom Kindle".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = try #require(URL(string: "koreaderturner://pair?v=1&host=192.168.1.20&port=9090&name=\(encodedName)&secret=\(secret.base64URLEncodedString)"))

        let payload = try PairingPayload(url: url)

        #expect(payload.configuration.endpoint.name == "Bedroom Kindle")
        #expect(payload.configuration.endpoint.host == "192.168.1.20")
        #expect(payload.configuration.endpoint.port == 9090)
        #expect(payload.configuration.secret == secret)
    }

    @Test(arguments: [
        "https://example.com",
        "koreaderturner://pair?v=2&host=kindle&port=9090&name=Kindle&secret=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "koreaderturner://pair?v=1&host=bad%20host&port=9090&name=Kindle&secret=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "koreaderturner://pair?v=1&host=kindle&port=99999&name=Kindle&secret=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    ])
    func rejectsInvalidURL(_ value: String) {
        #expect(throws: (any Error).self) {
            try PairingPayload(url: #require(URL(string: value)))
        }
    }
}

@Suite("Request authentication")
struct RequestSignerTests {
    @Test func canonicalInputAndMACAreStable() {
        let secret = Data(repeating: 0x0b, count: 32)

        #expect(RequestSigner.canonical(version: 1, action: "next", nonce: "abc") == "version=1\naction=next\nnonce=abc")
        #expect(RequestSigner.mac(version: 1, action: "next", nonce: "abc", secret: secret) == "7701c4d52c73919a5fd21f721faf0dfce517ce2186b9a4c14f880f45a357dbf4")
    }

    @Test func boundedReplayGuardRejectsDuplicatesAndEvictsOldValues() {
        var guardState = ReplayGuard(capacity: 2)
        let first = guardState.insert("one")
        let duplicate = guardState.insert("one")
        let second = guardState.insert("two")
        let third = guardState.insert("three")
        let evicted = guardState.insert("one")
        #expect(first)
        #expect(!duplicate)
        #expect(second)
        #expect(third)
        #expect(evicted)
    }
}

@Suite("Storage")
struct PairingStoreTests {
    @Test func roundTripsAndForgetsConfiguration() throws {
        let suiteName = "RemoteCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secrets = MemorySecretStore()
        let store = PairingStore(defaults: defaults, secrets: secrets)
        let expected = try PairingConfiguration(
            endpoint: KindleEndpoint(name: "Kindle", host: "kindle.local"),
            secret: Data(repeating: 4, count: 32)
        )

        try store.save(expected)
        #expect(try store.load() == expected)

        try store.forget()
        #expect(try store.load() == nil)
    }
}

@Suite("Client responses", .serialized)
struct KindleClientTests {
    @Test func decodesSuccessfulResponse() async throws {
        let client = makeClient(status: 200, body: #"{"ok":true,"message":"ready"}"#)
        let response = try await client.ping(using: configuration)
        #expect(response == ActionResponse(ok: true, message: "ready"))
    }

    @Test(arguments: [(401, KindleClientError.authenticationFailed), (409, .replayRejected), (423, .portConflict)])
    func mapsStatusErrors(_ status: Int, _ expected: KindleClientError) async {
        let client = makeClient(status: status, body: #"{"ok":false,"message":"no"}"#)
        await #expect(throws: expected) {
            try await client.send(.nextPage, using: configuration)
        }
    }

    private var configuration: PairingConfiguration {
        get throws {
            try PairingConfiguration(
                endpoint: KindleEndpoint(name: "Kindle", host: "kindle.local"),
                secret: Data(repeating: 3, count: 32)
            )
        }
    }

    private func makeClient(status: Int, body: String) -> KindleClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        return KindleClient(session: URLSession(configuration: config))
    }
}

private final class MemorySecretStore: SecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?

    func load() throws -> Data? { lock.withLock { value } }
    func save(_ secret: Data) throws { lock.withLock { value = secret } }
    func delete() throws { lock.withLock { value = nil } }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let result = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.1)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
