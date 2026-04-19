import Foundation
import HealthKit

struct BodyMetricDTO: Equatable {
    let recordedAt: Date
    let weightKg: Double?
    let bodyFatPercent: Double?
    let source: BodyMetricSource
}

enum HealthKitError: Error {
    case unavailable
    case denied
}

protocol HealthKitService {
    func requestAuthorization() async throws
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO?
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO]
}

final class LiveHealthKitService: HealthKitService {
    private let store = HKHealthStore()
    private let weightType = HKQuantityType(.bodyMass)
    private let fatType = HKQuantityType(.bodyFatPercentage)

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
}
