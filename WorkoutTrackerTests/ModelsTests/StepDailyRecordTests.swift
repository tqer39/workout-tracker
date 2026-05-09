import XCTest
import SwiftData
@testable import WorkoutTracker

final class StepDailyRecordTests: XCTestCase {
    @MainActor
    func test_insert_and_fetch() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        ctx.insert(StepDailyRecord(
            dayStart: day, steps: 8421, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.steps, 8421)
        XCTAssertEqual(fetched.first?.source, .healthKit)
    }

    @MainActor
    func test_dayStart_unique_constraint() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        ctx.insert(StepDailyRecord(
            dayStart: day, steps: 100, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        ctx.insert(StepDailyRecord(
            dayStart: day, steps: 200, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(fetched.count, 1, "dayStart はユニーク制約で 1 件にまとまる")
        XCTAssertEqual(fetched.first?.steps, 200)
    }

    @MainActor
    func test_stepRecord_representativeFixture_persists() throws {
        let container = try InMemoryContainer.seeded { ctx in
            ctx.insert(Fixtures.stepRecord(Fixtures.Steps.representative))
        }
        let records = try container.mainContext.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.steps, 1234)
    }
}
