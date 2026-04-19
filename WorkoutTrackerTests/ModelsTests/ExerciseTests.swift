import XCTest
import SwiftData
@testable import WorkoutTracker

final class ExerciseTests: XCTestCase {
    @MainActor
    func test_create_and_fetch_exercise() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let ex = Exercise(name: "ベンチプレス", category: .chest, defaultRestSeconds: 90)
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "ベンチプレス")
        XCTAssertEqual(fetched.first?.category, .chest)
        XCTAssertEqual(fetched.first?.defaultRestSeconds, 90)
        XCTAssertFalse(fetched.first?.isHidden ?? true)
    }
}
