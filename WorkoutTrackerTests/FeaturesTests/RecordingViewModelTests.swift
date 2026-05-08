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
}
