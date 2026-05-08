import SwiftUI
import SwiftData
import Charts

struct StepHistoryView: View {
    @Query(sort: [SortDescriptor(\StepDailyRecord.dayStart, order: .reverse)])
    private var records: [StepDailyRecord]

    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    @State private var rangeDays: Int = 30

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("期間", selection: $rangeDays) {
                        Text("30 日").tag(30)
                        Text("90 日").tag(90)
                    }
                    .pickerStyle(.segmented)
                }

                Section("サマリ") {
                    HStack {
                        SummaryItem(title: "ストリーク", value: "\(streak) 日")
                        Spacer()
                        SummaryItem(title: "平均歩数", value: "\(averageSteps) 歩")
                    }
                }

                Section("日別歩数") {
                    Chart(filtered) { r in
                        BarMark(
                            x: .value("日付", r.dayStart, unit: .day),
                            y: .value("歩数", r.steps)
                        )
                        .foregroundStyle(r.steps >= dailyGoal ? Color.green : Color.orange)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 220)
                }

                Section("記録") {
                    ForEach(filtered) { r in
                        HStack {
                            Text(r.dayStart, style: .date)
                            Spacer()
                            Text("\(r.steps) 歩")
                                .foregroundStyle(r.steps >= dailyGoal ? .green : .primary)
                        }
                    }
                }
            }
            .navigationTitle("歩数履歴")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView(
                        "データなし",
                        systemImage: "figure.walk",
                        description: Text("HealthKit から歩数を取得すると表示されます")
                    )
                }
            }
        }
    }

    private var filtered: [StepDailyRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
        return records.filter { $0.dayStart >= cutoff }.sorted { $0.dayStart < $1.dayStart }
    }

    private var streak: Int {
        StreakCalculator.currentStreak(records: records, dailyGoal: dailyGoal)
    }

    private var averageSteps: Int {
        guard !filtered.isEmpty else { return 0 }
        return filtered.map(\.steps).reduce(0, +) / filtered.count
    }
}

private struct SummaryItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    StepHistoryView()
        .modelContainer(for: [StepDailyRecord.self, CheckpointAchievement.self], inMemory: true)
}
