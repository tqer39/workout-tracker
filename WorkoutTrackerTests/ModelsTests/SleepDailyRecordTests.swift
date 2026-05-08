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

    func test_upsert_pattern_updates_existing_record() throws {
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

    func test_dayStart_unique_constraint() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        ctx.insert(SleepDailyRecord(
            dayStart: day, totalMinutes: 360, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        ctx.insert(SleepDailyRecord(
            dayStart: day, totalMinutes: 480, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(fetched.count, 1, "dayStart はユニーク制約で 1 件にまとまる")
        XCTAssertEqual(fetched.first?.totalMinutes, 480)
    }
}
