import SwiftUI
import SwiftData
import Charts

struct SleepHistoryView: View {
    @Environment(SleepService.self) private var sleep
    @AppStorage("sleep.targetHours") private var targetHours: Double = 7.0

    @Query(sort: [SortDescriptor(\SleepDailyRecord.dayStart, order: .reverse)])
    private var records: [SleepDailyRecord]

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @State private var rangeDays: Int = 30
    @State private var settingsPresented: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("", selection: $rangeDays) {
                    Text("30 日").tag(30)
                    Text("90 日").tag(90)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                summary
                chart
                list
            }
            .padding(.vertical, 8)
        }
        .task { await sleep.refreshOnAppear() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    settingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $settingsPresented) { SleepSettingsView() }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView(
                    "睡眠データなし",
                    systemImage: "moon.zzz",
                    description: Text("HealthKit から睡眠を取得すると表示されます")
                )
            }
        }
    }

    private var targetMinutes: Int { Int(targetHours * 60) }

    private var rangeRecords: [SleepDailyRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -(rangeDays - 1), to: today) ?? today
        return records
            .filter { $0.dayStart >= from && $0.dayStart <= today }
            .sorted(by: { $0.dayStart < $1.dayStart })
    }

    private var averageHours: Double {
        let r = rangeRecords
        guard !r.isEmpty else { return 0 }
        let total = r.reduce(0) { $0 + $1.totalMinutes }
        return Double(total) / Double(r.count) / 60.0
    }

    private var streakDays: Int {
        SleepStreak.currentStreak(records: records, targetMinutes: targetMinutes)
    }

    private var volumeByDay: [Date: Double] {
        let cal = Calendar.current
        var result: [Date: Double] = [:]
        for s in sessions {
            let key = cal.startOfDay(for: s.startedAt)
            let sets = s.sets.map { WorkoutMetrics.SetInput(weightKg: $0.weightKg, reps: $0.reps) }
            result[key, default: 0] += WorkoutMetrics.totalVolume(sets: sets)
        }
        return result
    }

    private var summary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("平均睡眠").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f h", averageHours)).font(.title3).bold()
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("ストリーク").font(.caption).foregroundStyle(.secondary)
                Text("\(streakDays) 日").font(.title3).bold()
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("目標").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f h", targetHours)).font(.title3).bold()
            }
        }
        .padding(.horizontal)
    }

    private var chart: some View {
        let volumes = volumeByDay
        let cal = Calendar.current
        return Chart {
            ForEach(rangeRecords, id: \.dayStart) { r in
                BarMark(
                    x: .value("日付", r.dayStart, unit: .day),
                    y: .value("睡眠 (h)", Double(r.totalMinutes) / 60.0)
                )
                .foregroundStyle(
                    Double(r.totalMinutes) >= Double(targetMinutes)
                    ? Color.green : Color.orange
                )
            }
            ForEach(rangeRecords, id: \.dayStart) { r in
                LineMark(
                    x: .value("日付", r.dayStart, unit: .day),
                    y: .value("ボリューム", volumes[cal.startOfDay(for: r.dayStart)] ?? 0)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("目標", targetHours))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .padding(.horizontal)
    }

    private var list: some View {
        let volumes = volumeByDay
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(rangeRecords.reversed(), id: \.dayStart) { r in
                HStack {
                    Text(r.dayStart, format: .dateTime.month().day())
                        .frame(width: 80, alignment: .leading)
                    Text(String(format: "%.1f h", Double(r.totalMinutes) / 60.0))
                        .foregroundStyle(
                            Double(r.totalMinutes) >= Double(targetMinutes)
                            ? .green : .orange
                        )
                    Spacer()
                    let vol = volumes[cal.startOfDay(for: r.dayStart)] ?? 0
                    Text(vol > 0 ? "vol \(Int(vol.rounded())) kg" : "vol --")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()
            }
        }
    }
}

#Preview {
    SleepHistoryView()
        .modelContainer(for: [
            SleepDailyRecord.self, WorkoutSession.self, SetRecord.self, Exercise.self
        ], inMemory: true)
        .environment(SleepService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
