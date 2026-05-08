import Foundation

#if DEBUG
final class StubHealthKitService: HealthKitService {
    var todaySteps: Int
    var dailySteps: [StepDailyDTO]
    var bodyMetrics: [BodyMetricDTO]

    init(
        todaySteps: Int = 5_400,
        dailySteps: [StepDailyDTO] = StubHealthKitService.defaultDailySteps(),
        bodyMetrics: [BodyMetricDTO] = []
    ) {
        self.todaySteps = todaySteps
        self.dailySteps = dailySteps
        self.bodyMetrics = bodyMetrics
    }

    func requestAuthorization() async throws {}
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? { bodyMetrics.last }
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] {
        bodyMetrics.filter { $0.recordedAt >= from && $0.recordedAt <= to }
    }

    func requestStepAuthorization() async throws {}
    func fetchTodaySteps() async throws -> Int { todaySteps }
    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)
        return dailySteps.filter { $0.dayStart >= fromDay && $0.dayStart <= toDay }
    }
    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void) {
        handler(todaySteps)
    }
    func stopObservingTodaySteps() {}

    private static func defaultDailySteps() -> [StepDailyDTO] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let counts = [3_200, 6_500, 8_400, 7_900, 9_100, 4_300, 5_400]
        return counts.enumerated().map { offset, steps in
            let day = cal.date(byAdding: .day, value: -(counts.count - 1 - offset), to: today) ?? today
            return StepDailyDTO(dayStart: day, steps: steps, source: .seed)
        }
    }
}
#endif
