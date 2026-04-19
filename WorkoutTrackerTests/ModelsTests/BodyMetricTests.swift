import XCTest
import SwiftData
@testable import WorkoutTracker

final class BodyMetricTests: XCTestCase {
    @MainActor
    func test_body_metric_sources() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        ctx.insert(BodyMetric(recordedAt: Date(), weightKg: 70.0, source: .manual))
        ctx.insert(BodyMetric(recordedAt: Date(), weightKg: 70.2, source: .healthKit))
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<BodyMetric>())
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.source)), [.manual, .healthKit])
    }
}
