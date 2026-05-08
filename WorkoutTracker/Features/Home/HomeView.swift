import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var tabSelection: AppTab
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // 歩くこと（Step1）を主役に置く
                    StepHeroCard(
                        todaySteps: journey.todaySteps,
                        dailyGoal: dailyGoal,
                        streakDays: journey.currentStreakDays
                    )

                    // 旅は動機づけ：タップで walk タブへ
                    JourneyMiniCard(progress: journey.progress) {
                        tabSelection = .walk
                    }

                    weeklySummarySection

                    if let last = sessions.first {
                        recentSessionSection(last)
                    }

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

    private func recentSessionSection(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("直近のセッション").font(.headline)
            NavigationLink {
                SessionDetailView(session: session)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.startedAt, style: .date).font(.subheadline.bold())
                        Text("\(session.sets.count) セット")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
            StepDailyRecord.self, CheckpointAchievement.self
        ], inMemory: true)
        .environment(JourneyService.preview())
}
