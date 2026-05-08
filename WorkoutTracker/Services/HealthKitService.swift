import Foundation
import HealthKit

struct BodyMetricDTO: Equatable {
    let recordedAt: Date
    let weightKg: Double?
    let bodyFatPercent: Double?
    let source: BodyMetricSource
}

struct StepDailyDTO: Equatable {
    let dayStart: Date
    let steps: Int
    let source: StepSource
}

enum HealthKitError: Error {
    case unavailable
    case denied
}

protocol HealthKitService {
    func requestAuthorization() async throws
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO?
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO]

    func requestStepAuthorization() async throws
    func fetchTodaySteps() async throws -> Int
    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO]
    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void)
    func stopObservingTodaySteps()
}

final class LiveHealthKitService: HealthKitService {
    private let store = HKHealthStore()
    private let weightType = HKQuantityType(.bodyMass)
    private let fatType = HKQuantityType(.bodyFatPercentage)
    private let stepType = HKQuantityType(.stepCount)

    private var observerQuery: HKObserverQuery?

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [weightType, fatType])
    }

    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? {
        let weight = try await latestQuantity(type: weightType, unit: .gramUnit(with: .kilo))
        let fat = try await latestQuantity(type: fatType, unit: .percent())
        let date = [weight?.date, fat?.date].compactMap { $0 }.max()
        guard let date else { return nil }
        return BodyMetricDTO(
            recordedAt: date,
            weightKg: weight?.value,
            bodyFatPercent: fat.map { $0.value * 100 },
            source: .healthKit
        )
    }

    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] {
        let weights = try await samples(type: weightType, unit: .gramUnit(with: .kilo), from: from, to: to)
        let fats = try await samples(type: fatType, unit: .percent(), from: from, to: to)
        var byDay: [Date: (Double?, Double?)] = [:]
        let cal = Calendar.current
        for s in weights {
            let day = cal.startOfDay(for: s.date)
            byDay[day, default: (nil, nil)].0 = s.value
        }
        for s in fats {
            let day = cal.startOfDay(for: s.date)
            byDay[day, default: (nil, nil)].1 = s.value * 100
        }
        return byDay
            .map {
                BodyMetricDTO(
                    recordedAt: $0.key,
                    weightKg: $0.value.0,
                    bodyFatPercent: $0.value.1,
                    source: .healthKit
                )
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func requestStepAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    func fetchTodaySteps() async throws -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        return try await stepsSum(from: start, to: end)
    }

    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
        return try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let interval = DateComponents(day: 1)
            let q = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { cont.resume(throwing: error); return }
                var out: [StepDailyDTO] = []
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    let day = cal.startOfDay(for: stats.startDate)
                    let value = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    let steps = max(0, Int(value.rounded()))
                    out.append(.init(dayStart: day, steps: steps, source: .healthKit))
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void) {
        stopObservingTodaySteps()
        let q = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil else { completion(); return }
            Task { @MainActor in
                if let n = try? await self?.fetchTodaySteps() {
                    handler(n)
                }
                completion()
            }
        }
        observerQuery = q
        store.execute(q)
    }

    func stopObservingTodaySteps() {
        if let q = observerQuery { store.stop(q) }
        observerQuery = nil
    }

    private struct Sample { let value: Double; let date: Date }

    private func latestQuantity(type: HKQuantityType, unit: HKUnit) async throws -> Sample? {
        try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                if let s = samples?.first as? HKQuantitySample {
                    cont.resume(returning: .init(value: s.quantity.doubleValue(for: unit), date: s.endDate))
                } else {
                    cont.resume(returning: nil)
                }
            }
            store.execute(q)
        }
    }

    private func samples(type: HKQuantityType, unit: HKUnit, from: Date, to: Date) async throws -> [Sample] {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let q = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let result = (samples ?? []).compactMap { $0 as? HKQuantitySample }
                    .map { Sample(value: $0.quantity.doubleValue(for: unit), date: $0.endDate) }
                cont.resume(returning: result)
            }
            store.execute(q)
        }
    }

    private func stepsSum(from: Date, to: Date) async throws -> Int {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let q = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: max(0, Int(value.rounded())))
            }
            store.execute(q)
        }
    }
}
