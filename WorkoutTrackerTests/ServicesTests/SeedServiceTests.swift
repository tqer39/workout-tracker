import XCTest
import SwiftData
@testable import WorkoutTracker

final class SeedServiceTests: XCTestCase {
    @MainActor
    func test_seed_is_idempotent() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let flagStore = InMemoryFlagStore()
        SeedService.seedIfNeeded(context: ctx, flagStore: flagStore)
        let firstCount = try ctx.fetch(FetchDescriptor<Exercise>()).count
        XCTAssertGreaterThan(firstCount, 0)
        XCTAssertTrue(flagStore.didSeed)

        SeedService.seedIfNeeded(context: ctx, flagStore: flagStore)
        let secondCount = try ctx.fetch(FetchDescriptor<Exercise>()).count
        XCTAssertEqual(secondCount, firstCount, "既にシード済みなら重複挿入しない")
    }

    @MainActor
    func test_seed_contains_big3() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        SeedService.seedIfNeeded(context: ctx, flagStore: InMemoryFlagStore())
        let names = Set(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.name))
        XCTAssertTrue(names.contains("ベンチプレス"))
        XCTAssertTrue(names.contains("スクワット"))
        XCTAssertTrue(names.contains("デッドリフト"))
    }
}

final class InMemoryFlagStore: SeedFlagStore {
    private var flag: Bool
    init(initial: Bool = false) { self.flag = initial }
    var didSeed: Bool {
        get { flag }
        set { flag = newValue }
    }
}
