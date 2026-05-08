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

    func test_stub_steps_today_default_zero() async throws {
        let stub = StubHealthKitService(latest: nil, range: [])
        let n = try await stub.fetchTodaySteps()
        XCTAssertEqual(n, 0)
    }

    func test_stub_steps_today_returns_injected() async throws {
        let stub = StubHealthKitService(latest: nil, range: [], todaySteps: 5432)
        let n = try await stub.fetchTodaySteps()
        XCTAssertEqual(n, 5432)
    }

    func test_stub_daily_steps_returns_injected() async throws {
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [.init(dayStart: day, steps: 8200, source: .healthKit)]
        )
        let result = try await stub.fetchDailySteps(from: day, to: day)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.steps, 8200)
    }

    func test_stub_observer_invokes_handler_with_injected_value() {
        let stub = StubHealthKitService(latest: nil, range: [], todaySteps: 1234)
        var received: Int?
        stub.startObservingTodaySteps { received = $0 }
        stub.triggerObserver()
        XCTAssertEqual(received, 1234)
    }
}

final class StubHealthKitService: HealthKitService {
    let latest: BodyMetricDTO?
    let range: [BodyMetricDTO]
    let authorizationError: Error?
    var todaySteps: Int
    var dailySteps: [StepDailyDTO]

    private var observerHandler: ((Int) -> Void)?

    init(
        latest: BodyMetricDTO?,
        range: [BodyMetricDTO],
        authorizationError: Error? = nil,
        todaySteps: Int = 0,
        dailySteps: [StepDailyDTO] = []
    ) {
        self.latest = latest
        self.range = range
        self.authorizationError = authorizationError
        self.todaySteps = todaySteps
        self.dailySteps = dailySteps
    }

    func requestAuthorization() async throws {
        if let authorizationError { throw authorizationError }
    }
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? { latest }
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] { range }

    func requestStepAuthorization() async throws {
        if let authorizationError { throw authorizationError }
    }
    func fetchTodaySteps() async throws -> Int { todaySteps }
    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO] { dailySteps }
    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void) {
        observerHandler = handler
    }
    func stopObservingTodaySteps() { observerHandler = nil }

    func triggerObserver() { observerHandler?(todaySteps) }
}
