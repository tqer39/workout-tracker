import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Binding var tabSelection: AppTab
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    StepHeroCard(
                        todaySteps: journey.todaySteps,
                        dailyGoal: dailyGoal,
                        streakDays: journey.currentStreakDays
                    )

                    JourneyMiniCard(progress: journey.progress) {
                        tabSelection = .walk
                    }

                    workoutStartSection
                    sleepSection
                    weeklySummarySection

                    if !recentCompletedSessions.isEmpty {
                        recentCompletedSessionsSection
                    }

                    weightTrendSection

                    if let latest = metrics.first {
                        latestMetricSection(latest)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("ホーム")
        }
    }

    private var workoutStartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ワークアウト開始").font(.headline)
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
        }
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

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("昨夜の睡眠").font(.headline)
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
                            .font(.title3.bold())
                        Text(String(format: "目標 %.1f h", sleepTargetHours))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("昨夜の記録なし").font(.subheadline)
                        Text("HealthKit から取得後に表示")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var weeklySummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今週のサマリ").font(.headline)
            HStack(spacing: 12) {
                SummaryTile(title: "セッション", value: "\(weekSessions.count)")
                SummaryTile(title: "総ボリューム", value: "\(Int(weekVolume.rounded())) kg")
                SummaryTile(title: "セット", value: "\(weekSets)")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var recentCompletedSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("直近 3 セッション").font(.headline)
            VStack(spacing: 8) {
                ForEach(recentCompletedSessions) { s in
                    NavigationLink {
                        SessionDetailView(session: s)
                    } label: {
                        HStack {
                            sessionSummaryRow(s)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weightTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("体重トレンド").font(.headline)
            Group {
                if weightSparklinePoints.isEmpty {
                    Text("データなし")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    weightSparklineView
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private func latestMetricSection(_ metric: BodyMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最新の体組成").font(.headline)
            HStack {
                if let w = metric.weightKg {
                    Text("\(String(format: "%.1f", w)) kg").font(.title3.bold())
                }
                Spacer()
                if let f = metric.bodyFatPercent {
                    Text("\(String(format: "%.1f", f)) %").foregroundStyle(.secondary)
                }
                Text(metric.recordedAt, style: .date)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
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
        let exerciseCount = Set(s.sets.compactMap { $0.exercise?.id }).count
        let volume = WorkoutMetrics.totalVolume(
            sets: s.sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) }
        )
        return "\(exerciseCount) 種目 / 総ボリューム \(Int(volume.rounded())) kg"
    }

    private struct WeightPoint: Identifiable {
        let id: Date
        let date: Date
        let weight: Double
    }

    private var weightSparklinePoints: [WeightPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -29, to: today) ?? today

        var byDay: [Date: BodyMetric] = [:]
        for m in metrics {
            guard let _ = m.weightKg else { continue }
            let day = cal.startOfDay(for: m.recordedAt)
            guard day >= from && day <= today else { continue }
            if let existing = byDay[day] {
                if existing.source == .manual { continue }
                if m.source == .manual { byDay[day] = m; continue }
                if m.recordedAt > existing.recordedAt { byDay[day] = m }
            } else {
                byDay[day] = m
            }
        }

        return byDay
            .compactMap { (day, metric) -> WeightPoint? in
                guard let w = metric.weightKg else { return nil }
                return WeightPoint(id: day, date: day, weight: w)
            }
            .sorted(by: { $0.date < $1.date })
    }

    @ViewBuilder
    private var weightSparklineView: some View {
        if weightSparklinePoints.count == 1, let only = weightSparklinePoints.first {
            HStack {
                Text(String(format: "%.1f kg", only.weight))
                    .font(.headline)
                Spacer()
                Text("（30 日中 1 件）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Chart {
                ForEach(weightSparklinePoints) { p in
                    LineMark(
                        x: .value("date", p.date),
                        y: .value("kg", p.weight)
                    )
                    AreaMark(
                        x: .value("date", p.date),
                        y: .value("kg", p.weight)
                    )
                    .foregroundStyle(.tint.opacity(0.15))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 36)
        }
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
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HomeView(tabSelection: .constant(.home))
        .modelContainer(for: [
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self,
            StepDailyRecord.self, CheckpointAchievement.self,
            SleepDailyRecord.self,
            WorkoutTemplate.self, TemplateExercise.self
        ], inMemory: true)
        .environment(JourneyService.preview())
        .environment(SleepService(
            healthKit: StubHealthKitService(),
            container: PreviewModelContainer.make()
        ))
        .environment(AppRouter())
}
