import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    var body: some View {
        NavigationStack {
            List {
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
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self
        ], inMemory: true)
}
