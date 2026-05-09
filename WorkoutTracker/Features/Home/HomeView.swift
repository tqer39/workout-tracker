import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(JourneyService.self) private var journey
    @Environment(SleepService.self) private var sleep
    @Environment(AppRouter.self) private var router
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @AppStorage("sleep.targetHours") private var sleepTargetHours: Double = 7.0

    @Query(sort: [SortDescriptor(\WorkoutTemplate.order), SortDescriptor(\WorkoutTemplate.name)])
    private var templates: [WorkoutTemplate]

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    private var hasActiveSession: Bool {
        sessions.contains { $0.endedAt == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("ワークアウト開始") {
                    workoutStartScroller
                }

                Section("今日の歩数") {
                    todayWalkCard
                }

                Section("昨夜の睡眠") {
                    lastNightSleepCard
                }

                Section("今週のサマリ") {
                    HStack {
                        SummaryTile(title: "セッション", value: "\(weekSessions.count)")
                        SummaryTile(title: "総ボリューム", value: "\(Int(weekVolume.rounded())) kg")
                        SummaryTile(title: "セット", value: "\(weekSets)")
                    }
                }

                if !recentCompletedSessions.isEmpty {
                    Section("直近 3 セッション") {
                        ForEach(recentCompletedSessions) { s in
                            NavigationLink {
                                SessionDetailView(session: s)
                            } label: {
                                sessionSummaryRow(s)
                            }
                        }
                    }
                }

                if let latest = metrics.first {
                    Section("最新の体組成") {
                        HStack {
                            if let w = latest.weightKg {
                                Text("\(String(format: "%.1f", w)) kg").font(.title3)
                            }
                            Spacer()
                            if let f = latest.bodyFatPercent {
                                Text("\(String(format: "%.1f", f)) %").foregroundStyle(.secondary)
                            }
                            Text(latest.recordedAt, style: .date)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("ホーム")
        }
    }

    private var workoutStartScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(templates) { t in
                    Button {
                        router.requestStart(template: t.id)
                    } label: {
                        templateCard(t)
                    }
                    .buttonStyle(.plain)
                    .disabled(hasActiveSession)
                    .opacity(hasActiveSession ? 0.4 : 1.0)
                }
                Button {
                    router.requestStartEmpty()
                } label: {
                    emptySessionCard
                }
                .buttonStyle(.plain)
                .disabled(hasActiveSession)
                .opacity(hasActiveSession ? 0.4 : 1.0)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
    }

    private func templateCard(_ t: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t.name)
                .font(.headline)
                .lineLimit(2)
            Spacer()
            Text("\(t.exercises.count) 種目")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 160, height: 96, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptySessionCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
            Text("空セッション")
                .font(.headline)
        }
        .frame(width: 160, height: 96)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var todayWalkCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1.0, Double(journey.todaySteps) / Double(max(1, dailyGoal))))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(achievementPercent) %")
                    .font(.caption).bold()
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(journey.todaySteps) 歩")
                    .font(.title3).bold()
                Text("目標 \(dailyGoal) 歩")
                    .font(.caption).foregroundStyle(.secondary)
                if !journey.progress.isCompleted, let next = journey.progress.nextCheckpoint {
                    Text("旅: \(next.name) まであと \(String(format: "%.1f", journey.progress.metersToNext / 1000.0)) km")
                        .font(.caption).foregroundStyle(.secondary)
                } else if journey.progress.isCompleted {
                    Text("旅: 博多到達！").font(.caption).foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var achievementPercent: Int {
        guard dailyGoal > 0 else { return 0 }
        return Int(Double(journey.todaySteps) / Double(dailyGoal) * 100)
    }

    private var lastNightSleepCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: sleepProgress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(sleepAchievementPercent) %")
                    .font(.caption).bold()
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                if let m = sleep.lastNightMinutes {
                    Text(String(format: "%.1f h", Double(m) / 60.0))
                        .font(.title3).bold()
                    Text(String(format: "目標 %.1f h", sleepTargetHours))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("昨夜の記録なし").font(.title3)
                    Text("HealthKit から取得後に表示")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var sleepProgress: Double {
        guard let m = sleep.lastNightMinutes, sleepTargetHours > 0 else { return 0 }
        let target = sleepTargetHours * 60.0
        return min(1.0, Double(m) / target)
    }

    private var sleepAchievementPercent: Int {
        guard let m = sleep.lastNightMinutes, sleepTargetHours > 0 else { return 0 }
        let target = sleepTargetHours * 60.0
        return Int((Double(m) / target * 100).rounded())
    }

    private var recentCompletedSessions: [WorkoutSession] {
        Array(sessions.lazy.filter { $0.endedAt != nil }.prefix(3))
    }

    private func sessionSummaryRow(_ s: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.startedAt, style: .date)
                .font(.headline)
            Text(sessionSummaryCaption(s))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sessionSummaryCaption(_ s: WorkoutSession) -> String {
        let exerciseIDs: [UUID] = s.sets.compactMap { $0.exercise?.id }
        let exerciseCount = Set(exerciseIDs).count
        let volume = WorkoutMetrics.totalVolume(
            sets: s.sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) }
        )
        return "\(exerciseCount) 種目 / 総ボリューム \(Int(volume.rounded())) kg"
    }

    private var weekSessions: [WorkoutSession] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startedAt >= start }
    }

    private var weekSets: Int {
        weekSessions.reduce(0) { $0 + $1.sets.count }
    }

    private var weekVolume: Double {
        let allSets = weekSessions.flatMap(\.sets)
        return WorkoutMetrics.totalVolume(sets: allSets.map {
            .init(weightKg: $0.weightKg, reps: $0.reps)
        })
    }
}

struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self,
            StepDailyRecord.self, CheckpointAchievement.self,
            SleepDailyRecord.self,
            WorkoutTemplate.self, TemplateExercise.self
        ], inMemory: true)
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
        .environment(SleepService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
        .environment(AppRouter())
}
