//
//  RemoteCoreTests.swift
//  KORemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation
import Testing
@testable import RemoteCore

@Suite("Pairing payload")
struct PairingPayloadTests {
    @Test(arguments: ["::::", "2001:db8:::1", "999.1.2.3", "kindle..local", "-kindle.local", "kindle-.local"])
    func rejectsMalformedHosts(_ host: String) {
        #expect(throws: PairingError.invalidHost) {
            try KindleEndpoint(name: "Kindle", host: host).validated()
        }
    }

    @Test func buildsIPv6URL() throws {
        let url = try KindleEndpoint(name: "Kindle", host: "2001:db8::1").url(path: "/v1/ping")
        #expect(url.absoluteString == "http://[2001:db8::1]:9090/v1/ping")
    }

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

@Suite("Watch relay identity")
struct WatchRelayIdentityTests {
    @Test func bindsActionsToThePairedReader() throws {
        let secret = Data(repeating: 7, count: 32)
        let original = try PairingConfiguration(endpoint: KindleEndpoint(name: "Reader", host: "reader.local"), secret: secret)
        let renamed = try PairingConfiguration(endpoint: KindleEndpoint(name: "Bedroom", host: "reader.local"), secret: secret)
        let changedHost = try PairingConfiguration(endpoint: KindleEndpoint(name: "Reader", host: "other.local"), secret: secret)
        let changedPort = try PairingConfiguration(endpoint: KindleEndpoint(name: "Reader", host: "reader.local", port: 9091), secret: secret)
        let changedSecret = try PairingConfiguration(endpoint: original.endpoint, secret: Data(repeating: 8, count: 32))

        #expect(original.watchRelayIdentifier == renamed.watchRelayIdentifier)
        #expect(original.watchRelayIdentifier != changedHost.watchRelayIdentifier)
        #expect(original.watchRelayIdentifier != changedPort.watchRelayIdentifier)
        #expect(original.watchRelayIdentifier != changedSecret.watchRelayIdentifier)
    }
}

@Suite("Request authentication")
struct RequestSignerTests {
    @Test func canonicalInputAndMACAreStable() {
        let secret = Data(repeating: 0x0b, count: 32)

        #expect(RequestSigner.canonical(version: 1, action: "next", nonce: "abc") == "version=1\naction=next\nnonce=abc")
        #expect(RequestSigner.mac(version: 1, action: "next", nonce: "abc", secret: secret) == "7701c4d52c73919a5fd21f721faf0dfce517ce2186b9a4c14f880f45a357dbf4")
    }


}

@Suite("Volume button actions")
struct VolumeButtonActionTests {
    @Test func mapsVolumeIncreaseToNextPage() {
        #expect(VolumeButtonAction.remoteAction(from: 0.5, to: 0.5625) == .nextPage)
    }

    @Test func mapsVolumeDecreaseToPreviousPage() {
        #expect(VolumeButtonAction.remoteAction(from: 0.5, to: 0.4375) == .previousPage)
    }

    @Test func ignoresRecenterAndNoise() {
        #expect(VolumeButtonAction.remoteAction(from: 0.4375, to: 0.5, ignoring: 0.5) == nil)
        #expect(VolumeButtonAction.remoteAction(from: 0.5, to: 0.505) == nil)
    }

    @Test func handlesVolumeBoundaries() {
        #expect(VolumeButtonAction.remoteAction(from: 0, to: 0.0625) == .nextPage)
        #expect(VolumeButtonAction.remoteAction(from: 1, to: 0.9375) == .previousPage)
        #expect(VolumeButtonAction.remoteAction(from: 0, to: 0) == nil)
        #expect(VolumeButtonAction.remoteAction(from: 1, to: 1) == nil)
    }
}

@Suite("Storage")
struct PairingStoreTests {
    @Test func preservesPairingWhenSecretDeletionFails() throws {
        let suiteName = "RemoteCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PairingStore(defaults: defaults, secrets: FailingDeleteSecretStore())
        let expected = try PairingConfiguration(
            endpoint: KindleEndpoint(name: "Kindle", host: "kindle.local"),
            secret: Data(repeating: 4, count: 32)
        )
        try store.save(expected)
        #expect(throws: StorageError.keychain(-1)) { try store.forget() }
        #expect(try store.load() == expected)
    }

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
    @Test func countsOnlyConfirmedNextPageCommands() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let statistics = PageTurnStatistics(fileURL: directory.appending(path: "counts.json"))
        let client = makeClient(status: 200, body: #"{"ok":true}"#, statistics: statistics)

        _ = try await client.send(.nextPage, using: configuration)
        _ = try await client.send(.previousPage, using: configuration)
        _ = try await client.send(.sleep, using: configuration)
        _ = try await client.ping(using: configuration)
        #expect(try await statistics.summary().allTime == 1)

        for (status, body) in [(500, #"{"ok":false}"#), (200, #"{"ok":false}"#)] {
            let failingClient = makeClient(status: status, body: body, statistics: statistics)
            await #expect(throws: (any Error).self) {
                try await failingClient.send(.nextPage, using: configuration)
            }
        }
        #expect(try await statistics.summary().allTime == 1)
    }

    @Test func statisticsFailureDoesNotFailDeliveredCommand() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "counts.json")
        try Data("invalid".utf8).write(to: fileURL)
        let statistics = PageTurnStatistics(fileURL: fileURL)
        let client = makeClient(status: 200, body: #"{"ok":true}"#, statistics: statistics)

        let response = try await client.send(.nextPage, using: configuration)
        #expect(response.ok)
        #expect(try Data(contentsOf: fileURL) == Data("invalid".utf8))
    }

    @Test func distinguishesUncertainDelivery() async {
        let client = makeClient { _ in throw URLError(.networkConnectionLost) }
        await #expect(throws: KindleClientError.deliveryUncertain) {
            try await client.send(.nextPage, using: configuration)
        }
    }

    @Test func preservesCancellation() async {
        let client = makeClient { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            try await client.ping(using: configuration)
        }
    }

    @Test func decodesSuccessfulResponse() async throws {
        let client = makeClient(status: 200, body: #"{"ok":true,"message":"ready"}"#)
        let response = try await client.ping(using: configuration)
        #expect(response == ActionResponse(ok: true, message: "ready"))
    }

    @Test(arguments: [(401, KindleClientError.authenticationFailed), (409, .replayRejected)])
    func mapsStatusErrors(_ status: Int, _ expected: KindleClientError) async {
        let client = makeClient(status: status, body: #"{"ok":false,"message":"no"}"#)
        await #expect(throws: expected) {
            try await client.send(.nextPage, using: configuration)
        }
    }

    @Test func sendsAuthenticatedActionContract() async throws {
        let recorder = RequestRecorder()
        let pairing = try configuration
        let client = makeClient { request in
            recorder.record(request)
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        _ = try await client.send(.previousPage, using: pairing)

        let request = try #require(recorder.request)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "http://kindle.local:9090/v1/action")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")

        let body = try #require(request.httpBody)
        let signed = try JSONDecoder().decode(CapturedSignedRequest.self, from: body)
        #expect(signed.version == ProtocolConstants.version)
        #expect(signed.action == RemoteAction.previousPage.rawValue)
        #expect(!signed.nonce.isEmpty)
        #expect(signed.mac == RequestSigner.mac(
            version: signed.version,
            action: signed.action,
            nonce: signed.nonce,
            secret: pairing.secret
        ))
    }

    @Test func rejectsMalformedSuccessPayload() async {
        let client = makeClient(status: 200, body: #"{"ok":false}"#)
        await #expect(throws: KindleClientError.invalidResponse) {
            try await client.ping(using: configuration)
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

    private func makeClient(status: Int, body: String, statistics: PageTurnStatistics? = nil) -> KindleClient {
        makeClient(statistics: statistics) { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
    }

    private func makeClient(
        statistics: PageTurnStatistics? = nil,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> KindleClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = handler
        let isolatedStatistics = statistics ?? PageTurnStatistics(
            fileURL: FileManager.default.temporaryDirectory.appending(path: "KORemoteTests-\(UUID().uuidString)/counts.json")
        )
        return KindleClient(session: URLSession(configuration: config), statistics: isolatedStatistics)
    }
}

private struct CapturedSignedRequest: Decodable {
    let version: Int
    let action: String
    let nonce: String
    let mac: String
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequest: URLRequest?

    var request: URLRequest? {
        lock.withLock { storedRequest }
    }

    func record(_ request: URLRequest) {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1_024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            captured.httpBody = data
        }
        lock.withLock { storedRequest = captured }
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

private struct FailingDeleteSecretStore: SecretStoring {
    func load() throws -> Data? { Data(repeating: 4, count: 32) }
    func save(_ secret: Data) throws {}
    func delete() throws { throw StorageError.keychain(-1) }
}
