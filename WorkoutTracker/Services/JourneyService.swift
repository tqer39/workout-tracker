import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class JourneyService {
    var todaySteps: Int = 0
    var progress: JourneyProgress = .empty
    var pendingCelebrations: [CheckpointAchievement] = []

    private let healthKit: HealthKitService
    private let container: ModelContainer
    private let route: [Checkpoint]
    private let journeyStartedAtProvider: () -> Date?
    private let persistJourneyStartedAt: (Date) -> Void

    init(
        healthKit: HealthKitService,
        container: ModelContainer,
        route: [Checkpoint] = JourneyRoute.tokyoToHakata,
        journeyStartedAtProvider: @escaping () -> Date? = {
            UserDefaults.standard.object(forKey: "walk.journeyStartedAt") as? Date
        },
        persistJourneyStartedAt: @escaping (Date) -> Void = { date in
            UserDefaults.standard.set(date, forKey: "walk.journeyStartedAt")
        }
    ) {
        self.healthKit = healthKit
        self.container = container
        self.route = route
        self.journeyStartedAtProvider = journeyStartedAtProvider
        self.persistJourneyStartedAt = persistJourneyStartedAt
    }

    func bootstrap() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let started: Date
        if let existing = journeyStartedAtProvider() {
            started = cal.startOfDay(for: existing)
        } else {
            persistJourneyStartedAt(today)
            started = today
        }

        let from = min(started, cal.date(byAdding: .day, value: -7, to: today) ?? today)
        let to = today
        let dtos = (try? await healthKit.fetchDailySteps(from: from, to: to)) ?? []
        upsert(dtos: dtos)

        let totalSteps = sumSteps(from: started, to: today)
        todaySteps = (try? await healthKit.fetchTodaySteps()) ?? 0
        progress = JourneyEngine.computeProgress(totalSteps: totalSteps, route: route)

        ensureAchievements(totalSteps: totalSteps)
        refreshPendingCelebrations()
    }

    func refreshOnAppear() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let started = cal.startOfDay(for: journeyStartedAtProvider() ?? today)
        let dtos = (try? await healthKit.fetchDailySteps(from: today, to: today)) ?? []
        upsert(dtos: dtos)

        todaySteps = (try? await healthKit.fetchTodaySteps()) ?? 0
        let totalSteps = sumSteps(from: started, to: today)
        progress = JourneyEngine.computeProgress(totalSteps: totalSteps, route: route)
        ensureAchievements(totalSteps: totalSteps)
        refreshPendingCelebrations()
    }

    func startObserving() {
        healthKit.startObservingTodaySteps { [weak self] n in
            Task { @MainActor in
                guard let self else { return }
                self.todaySteps = n
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                self.upsert(dtos: [.init(dayStart: today, steps: n, source: .healthKit)])
                let started = cal.startOfDay(for: self.journeyStartedAtProvider() ?? today)
                let total = self.sumSteps(from: started, to: today)
                self.progress = JourneyEngine.computeProgress(totalSteps: total, route: self.route)
                self.ensureAchievements(totalSteps: total)
                self.refreshPendingCelebrations()
            }
        }
    }

    func stopObserving() {
        healthKit.stopObservingTodaySteps()
    }

    func markCelebrated(_ achievement: CheckpointAchievement) {
        achievement.celebrated = true
        try? container.mainContext.save()
        refreshPendingCelebrations()
    }

    func resetJourney(now: Date = .now) {
        let ctx = container.mainContext
        if let existing = try? ctx.fetch(FetchDescriptor<CheckpointAchievement>()) {
            for a in existing { ctx.delete(a) }
        }
        try? ctx.save()
        let day = Calendar.current.startOfDay(for: now)
        persistJourneyStartedAt(day)
        progress = .empty
        pendingCelebrations = []
    }

    func setDailyGoal(_ steps: Int) {
        UserDefaults.standard.set(steps, forKey: "walk.dailyGoalSteps")
    }

    private func upsert(dtos: [StepDailyDTO]) {
        let ctx = container.mainContext
        let cal = Calendar.current
        for dto in dtos {
            let day = cal.startOfDay(for: dto.dayStart)
            var fd = FetchDescriptor<StepDailyRecord>(
                predicate: #Predicate { $0.dayStart == day }
            )
            fd.fetchLimit = 1
            if let existing = try? ctx.fetch(fd).first {
                existing.steps = dto.steps
                existing.lastSyncedAt = Date()
            } else {
                ctx.insert(StepDailyRecord(
                    dayStart: day,
                    steps: dto.steps,
                    source: dto.source,
                    lastSyncedAt: Date()
                ))
            }
        }
        try? ctx.save()
    }

    private func sumSteps(from: Date, to: Date) -> Int {
        let ctx = container.mainContext
        let fromDay = Calendar.current.startOfDay(for: from)
        let toDay = Calendar.current.startOfDay(for: to)
        let fd = FetchDescriptor<StepDailyRecord>(
            predicate: #Predicate { $0.dayStart >= fromDay && $0.dayStart <= toDay }
        )
        let rows = (try? ctx.fetch(fd)) ?? []
        return rows.reduce(0) { $0 + $1.steps }
    }

    private func ensureAchievements(totalSteps: Int) {
        let ctx = container.mainContext
        let passed = JourneyEngine.passedCheckpointIds(totalSteps: totalSteps, route: route)
        let existing = (try? ctx.fetch(FetchDescriptor<CheckpointAchievement>())) ?? []
        let existingIds = Set(existing.map(\.checkpointId))
        for id in passed where !existingIds.contains(id) {
            ctx.insert(CheckpointAchievement(
                checkpointId: id,
                achievedAt: Date(),
                totalStepsAtAchievement: totalSteps,
                celebrated: id == "tokyo"
            ))
        }
        try? ctx.save()
    }

    private func refreshPendingCelebrations() {
        let ctx = container.mainContext
        let fd = FetchDescriptor<CheckpointAchievement>(
            predicate: #Predicate { $0.celebrated == false },
            sortBy: [SortDescriptor(\.achievedAt)]
        )
        pendingCelebrations = (try? ctx.fetch(fd)) ?? []
    }
}

#if DEBUG
extension JourneyService {
    func debugAddSteps(_ n: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var fd = FetchDescriptor<StepDailyRecord>(
            predicate: #Predicate { $0.dayStart == today }
        )
        fd.fetchLimit = 1
        let ctx = container.mainContext
        if let existing = try? ctx.fetch(fd).first {
            existing.steps += n
            existing.lastSyncedAt = Date()
        } else {
            ctx.insert(StepDailyRecord(
                dayStart: today, steps: n, source: .seed, lastSyncedAt: Date()
            ))
        }
        try? ctx.save()
        todaySteps += n
        let started = cal.startOfDay(for: journeyStartedAtProvider() ?? today)
        let total = sumSteps(from: started, to: today)
        progress = JourneyEngine.computeProgress(totalSteps: total, route: route)
        ensureAchievements(totalSteps: total)
        refreshPendingCelebrations()
    }
}
#endif
