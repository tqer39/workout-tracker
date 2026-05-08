import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class JourneyServiceTests: XCTestCase {
    func test_bootstrap_inserts_step_records() async throws {
        let container = try InMemoryContainer.make()
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            todaySteps: 6000,
            dailySteps: [
                .init(dayStart: day, steps: 6000, source: .healthKit),
                .init(dayStart: cal.date(byAdding: .day, value: -1, to: day)!,
                      steps: 9000, source: .healthKit),
            ]
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )

        await svc.bootstrap()

        let records = try container.mainContext.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(records.count, 2)
    }

    func test_bootstrap_creates_pending_celebrations_for_passed_checkpoints() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            todaySteps: 50_000,
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)]
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )

        await svc.bootstrap()

        XCTAssertTrue(svc.pendingCelebrations.contains { $0.checkpointId == "yokohama" })
        XCTAssertFalse(svc.pendingCelebrations.contains { $0.checkpointId == "tokyo" })
    }

    func test_bootstrap_idempotent() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            todaySteps: 50_000,
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)]
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )

        await svc.bootstrap()
        await svc.bootstrap()

        let achievements = try container.mainContext.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(achievements.count, 2)
    }

    func test_mark_celebrated_sets_flag_and_removes_from_pending() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            todaySteps: 50_000,
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)]
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )
        await svc.bootstrap()

        let target = svc.pendingCelebrations.first { $0.checkpointId == "yokohama" }!
        svc.markCelebrated(target)

        XCTAssertTrue(target.celebrated)
        XCTAssertFalse(svc.pendingCelebrations.contains { $0.checkpointId == "yokohama" })
    }

    func test_reset_journey_clears_achievements() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            todaySteps: 50_000,
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)]
        )
        var stored: Date? = day
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { stored ?? day },
            persistJourneyStartedAt: { stored = $0 }
        )
        await svc.bootstrap()

        svc.resetJourney(now: day.addingTimeInterval(86400))

        let achievements = try container.mainContext.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(achievements.count, 0)
        XCTAssertEqual(stored, day.addingTimeInterval(86400))
    }
}
