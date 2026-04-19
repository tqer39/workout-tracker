import XCTest
@testable import WorkoutTracker

final class HealthKitServiceTests: XCTestCase {
    func test_mock_returns_injected_values() async throws {
        let stub = StubHealthKitService(
            latest: .init(recordedAt: Date(), weightKg: 70, bodyFatPercent: 18, source: .healthKit),
            range: []
        )
        let latest = try await stub.fetchLatestBodyMetric()
        XCTAssertEqual(latest?.weightKg, 70)
    }

    func test_mock_denied_throws_on_authorization() async throws {
        let stub = StubHealthKitService(
            latest: nil,
            range: [],
            authorizationError: HealthKitError.denied
        )
        do {
            try await stub.requestAuthorization()
            XCTFail("denied を投げるべき")
        } catch HealthKitError.denied {
            // OK
        }
    }
}

final class StubHealthKitService: HealthKitService {
    let latest: BodyMetricDTO?
    let range: [BodyMetricDTO]
    let authorizationError: Error?
    init(latest: BodyMetricDTO?, range: [BodyMetricDTO], authorizationError: Error? = nil) {
        self.latest = latest; self.range = range; self.authorizationError = authorizationError
    }
    func requestAuthorization() async throws {
        if let authorizationError { throw authorizationError }
    }
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? { latest }
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] { range }
}
