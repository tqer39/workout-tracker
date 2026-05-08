import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class SleepDailyRecordTests: XCTestCase {
    func test_basic_attributes_persist() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        let record = SleepDailyRecord(
            dayStart: day,
            totalMinutes: 432,
            source: .healthKit,
            lastSyncedAt: Date()
        )
        ctx.insert(record)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.totalMinutes, 432)
        XCTAssertEqual(fetched.first?.source, .healthKit)
    }

    func test_unique_dayStart_overwrites_via_explicit_replace() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        let first = SleepDailyRecord(
            dayStart: day, totalMinutes: 360, source: .healthKit, lastSyncedAt: Date()
        )
        ctx.insert(first)
        try ctx.save()

        var fd = FetchDescriptor<SleepDailyRecord>(
            predicate: #Predicate { $0.dayStart == day }
        )
        fd.fetchLimit = 1
        if let existing = try ctx.fetch(fd).first {
            existing.totalMinutes = 480
            existing.lastSyncedAt = Date()
        }
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.totalMinutes, 480)
    }
}
