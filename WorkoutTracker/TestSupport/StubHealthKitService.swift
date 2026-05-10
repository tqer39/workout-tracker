import Foundation

#if DEBUG
final class StubHealthKitService: HealthKitService {
    var todaySteps: Int
    var dailySteps: [StepDailyDTO]
    var bodyMetrics: [BodyMetricDTO]
    var sleepDtos: [SleepDailyDTO]

    init(
        todaySteps: Int = 5_400,
        dailySteps: [StepDailyDTO] = StubHealthKitService.defaultDailySteps(),
        bodyMetrics: [BodyMetricDTO] = [],
        sleepDtos: [SleepDailyDTO] = StubHealthKitService.defaultSleep()
    ) {
        self.todaySteps = todaySteps
        self.dailySteps = dailySteps
        self.bodyMetrics = bodyMetrics
        self.sleepDtos = sleepDtos
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

    func requestSleepAuthorization() async throws {}
    func fetchSleep(from: Date, to: Date) async throws -> [SleepDailyDTO] {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: from)
        let toDay = cal.startOfDay(for: to)
        return sleepDtos.filter { $0.dayStart >= fromDay && $0.dayStart <= toDay }
    }

    private static func defaultDailySteps() -> [StepDailyDTO] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let counts = [3_200, 6_500, 8_400, 7_900, 9_100, 4_300, 5_400]
        return counts.enumerated().map { offset, steps in
            let day = cal.date(byAdding: .day, value: -(counts.count - 1 - offset), to: today) ?? today
            return StepDailyDTO(dayStart: day, steps: steps, source: .seed)
        }
    }

    private static func defaultSleep() -> [SleepDailyDTO] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let minutes = [380, 420, 450, 410, 470, 360, 430]
        return minutes.enumerated().map { offset, m in
            let day = cal.date(byAdding: .day, value: -(minutes.count - 1 - offset), to: today) ?? today
            return SleepDailyDTO(dayStart: day, totalMinutes: m, source: .seed)
        }
    }
}
#endif
