import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class RecordingViewModelTests: XCTestCase {
    func test_endSession_withZeroSets_deletesSession() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let vm = RecordingViewModel()
        vm.bind(context: ctx)
        vm.startEmptySession()
        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 1,
            "前提: startEmptySession でセッションが 1 件 insert される"
        )

        vm.endSession()

        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 0,
            "0 セットで終了したセッションは破棄されているはず"
        )
        XCTAssertNil(vm.session)
    }

    func test_endSession_withOneOrMoreSets_persistsSessionWithEndedAt() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let exercise = Exercise(name: "ベンチプレス", category: .chest)
        ctx.insert(exercise)
        try ctx.save()

        let vm = RecordingViewModel()
        vm.bind(context: ctx)
        vm.startEmptySession()
        vm.addSet(exercise: exercise, weightKg: 60.0, reps: 10, rpe: 8.0)

        vm.endSession()

        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1, "セットがあれば破棄されない")
        XCTAssertNotNil(sessions[0].endedAt, "endedAt が立っている")
        XCTAssertEqual(sessions[0].sets.count, 1)
        XCTAssertNil(vm.session)
    }
}
