import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SleepService {
    var lastNightMinutes: Int?

    private let healthKit: HealthKitService
    private let container: ModelContainer

    init(healthKit: HealthKitService, container: ModelContainer) {
        self.healthKit = healthKit
        self.container = container
    }

    func bootstrap() async {
        try? await healthKit.requestSleepAuthorization()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -90, to: today) ?? today
        let dtos = (try? await healthKit.fetchSleep(from: from, to: today)) ?? []
        upsert(dtos: dtos)
        lastNightMinutes = latestStoredMinutes()
    }

    func refreshOnAppear() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dtos = (try? await healthKit.fetchSleep(from: today, to: today)) ?? []
        upsert(dtos: dtos)
        lastNightMinutes = latestStoredMinutes()
    }

    private func upsert(dtos: [SleepDailyDTO]) {
        let ctx = container.mainContext
        let cal = Calendar.current
        for dto in dtos {
            let day = cal.startOfDay(for: dto.dayStart)
            var fd = FetchDescriptor<SleepDailyRecord>(
                predicate: #Predicate { $0.dayStart == day }
            )
            fd.fetchLimit = 1
            if let existing = try? ctx.fetch(fd).first {
                existing.totalMinutes = dto.totalMinutes
                existing.lastSyncedAt = Date()
            } else {
                ctx.insert(SleepDailyRecord(
                    dayStart: day,
                    totalMinutes: dto.totalMinutes,
                    source: dto.source,
                    lastSyncedAt: Date()
                ))
            }
        }
        try? ctx.save()
    }

    private func latestStoredMinutes() -> Int? {
        let ctx = container.mainContext
        var fd = FetchDescriptor<SleepDailyRecord>(
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        fd.fetchLimit = 1
        return (try? ctx.fetch(fd))?.first?.totalMinutes
    }
}
