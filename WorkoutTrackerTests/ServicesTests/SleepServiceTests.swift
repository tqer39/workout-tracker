import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class SleepServiceTests: XCTestCase {
    func test_bootstrap_upserts_records_and_sets_lastNightMinutes() async throws {
        let container = try InMemoryContainer.make()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let stub = StubHealthKitService(
            latest: nil, range: [],
            sleepData: [
                .init(dayStart: yesterday, totalMinutes: 360, source: .healthKit),
                .init(dayStart: today,     totalMinutes: 432, source: .healthKit),
            ]
        )
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()

        let stored = try container.mainContext.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(svc.lastNightMinutes, 432)
    }

    func test_double_bootstrap_does_not_duplicate_records() async throws {
        let container = try InMemoryContainer.make()
        let today = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            sleepData: [.init(dayStart: today, totalMinutes: 420, source: .healthKit)]
        )
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()
        await svc.bootstrap()

        let stored = try container.mainContext.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.totalMinutes, 420)
    }

    func test_bootstrap_with_empty_sleep_keeps_lastNightMinutes_nil() async throws {
        let container = try InMemoryContainer.make()
        let stub = StubHealthKitService(latest: nil, range: [], sleepData: [])
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()

        XCTAssertNil(svc.lastNightMinutes)
    }

    func test_refreshOnAppear_upserts_today_records_from_recent_window() async throws {
        let container = try InMemoryContainer.make()
        let today = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(latest: nil, range: [], sleepData: [])
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()

        stub.sleepData = [.init(dayStart: today, totalMinutes: 420, source: .healthKit)]
        await svc.refreshOnAppear()

        XCTAssertEqual(svc.lastNightMinutes, 420)
        let stored = try container.mainContext.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.totalMinutes, 420)
    }
}
