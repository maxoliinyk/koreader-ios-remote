//
//  PageTurnStatisticsTests.swift
//  KORemote
//
//  Created by Max Oliinyk on 24.10.26.
//

import Foundation
import Testing
@testable import RemoteCore

@Suite("Page-turn statistics")
struct PageTurnStatisticsTests {
    @Test func persistsCountsAcrossMonthAndYearBoundaries() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "counts.json")
        let statistics = PageTurnStatistics(fileURL: fileURL)
        let utc = TimeZone(secondsFromGMT: 0)!
        let december = Date(timeIntervalSince1970: 1_798_761_599) // December 31, 2026, 23:59:59 UTC.
        let january = december.addingTimeInterval(1)

        #expect(try await statistics.summary(at: december, timeZone: utc).allTime == 0)
        try await statistics.recordNextPage(at: december, timeZone: utc)
        try await statistics.recordNextPage(at: december, timeZone: utc)
        #expect(try await statistics.summary(at: january, timeZone: utc).thisMonth == 0)
        try await statistics.recordNextPage(at: january, timeZone: utc)

        let reloaded = PageTurnStatistics(fileURL: fileURL)
        #expect(try await reloaded.summary(at: january, timeZone: utc).thisMonth == 1)
        #expect(try await reloaded.summary(at: january, timeZone: utc).allTime == 3)
        #expect(try await reloaded.summary(at: december, timeZone: utc).thisMonth == 2)
    }

    @Test func usesLocalMonthAtTheBoundary() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let statistics = PageTurnStatistics(fileURL: directory.appending(path: "counts.json"))
        let utc = TimeZone(secondsFromGMT: 0)!
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let date = Date(timeIntervalSince1970: 1_798_761_599)

        try await statistics.recordNextPage(at: date, timeZone: berlin)
        #expect(try await statistics.summary(at: date, timeZone: berlin).thisMonth == 1)
        #expect(try await statistics.summary(at: date, timeZone: utc).thisMonth == 0)
    }

    @Test func concurrentStoresDoNotLoseTurns() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "counts.json")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await PageTurnStatistics(fileURL: fileURL).recordNextPage()
                }
            }
            try await group.waitForAll()
        }
        #expect(try await PageTurnStatistics(fileURL: fileURL).summary().allTime == 20)
    }

    @Test func corruptStatisticsAreReportedAndPreserved() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "counts.json")
        let corruptData = Data("invalid".utf8)
        try corruptData.write(to: fileURL)
        let statistics = PageTurnStatistics(fileURL: fileURL)

        await #expect(throws: (any Error).self) { try await statistics.summary() }
        await #expect(throws: (any Error).self) { try await statistics.recordNextPage() }
        #expect(try Data(contentsOf: fileURL) == corruptData)
    }
}
