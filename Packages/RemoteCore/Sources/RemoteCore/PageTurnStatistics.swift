//
//  PageTurnStatistics.swift
//  KORemote
//
//  Created by Max Oliinyk on 24.10.26.
//

import Foundation

public actor PageTurnStatistics {
    public struct Summary: Equatable, Sendable {
        public let thisMonth: Int
        public let allTime: Int
    }

    public static let shared = PageTurnStatistics()

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ProtocolConstants.appGroup
        ) ?? URL.applicationSupportDirectory
        self.fileURL = fileURL ?? container.appending(path: "PageTurnStatistics/counts.json")
    }

    public func recordNextPage(at date: Date = .now, timeZone: TimeZone = .current) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // Coordinate across the app and its extensions to avoid losing simultaneous turns.
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<Void, any Error>?
        coordinator.coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            result = Result {
                var counts = try readCounts(at: url)
                counts[monthKey(for: date, timeZone: timeZone), default: 0] += 1
                try JSONEncoder().encode(counts).write(to: url, options: .atomic)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        try result.get()
    }

    public func summary(at date: Date = .now, timeZone: TimeZone = .current) throws -> Summary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Summary(thisMonth: 0, allTime: 0)
        }
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<[String: Int], any Error>?
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            result = Result { try readCounts(at: url) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        let counts = try result.get()
        return Summary(
            thisMonth: counts[monthKey(for: date, timeZone: timeZone), default: 0],
            allTime: counts.values.reduce(0, +)
        )
    }

    private func readCounts(at url: URL) throws -> [String: Int] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: Int].self, from: Data(contentsOf: url))
    }

    private func monthKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year!)-\(components.month!)"
    }
}
