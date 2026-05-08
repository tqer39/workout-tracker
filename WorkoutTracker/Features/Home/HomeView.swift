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
            List {
                Section("今日の歩数") {
                    todayWalkCard
                }

                Section("今週のサマリ") {
                    HStack {
                        SummaryTile(title: "セッション", value: "\(weekSessions.count)")
                        SummaryTile(title: "総ボリューム", value: "\(Int(weekVolume.rounded())) kg")
                        SummaryTile(title: "セット", value: "\(weekSets)")
                    }
                }

                if let last = sessions.first {
                    Section("直近のセッション") {
                        NavigationLink {
                            SessionDetailView(session: last)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(last.startedAt, style: .date).font(.headline)
                                Text("\(last.sets.count) セット")
                                    .font(.caption).foregroundStyle(.secondary)
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
    HomeView(tabSelection: .constant(.home))
        .modelContainer(for: [
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self,
            StepDailyRecord.self, CheckpointAchievement.self
        ], inMemory: true)
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
