import SwiftUI
import SwiftData
import Charts

struct ExerciseChartsView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: [SortDescriptor(\Exercise.name)])
    private var exercises: [Exercise]

    @State private var selected: Exercise?

    enum Metric: String, CaseIterable, Identifiable {
        case oneRM = "推定1RM"
        case volume = "ボリューム"
        case topSet = "トップセット重量"
        var id: String { rawValue }
    }

    @State private var metric: Metric = .oneRM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Menu {
                    ForEach(exercises) { ex in
                        Button(ex.name) { selected = ex }
                    }
                } label: {
                    HStack {
                        Text(selected?.name ?? "種目を選択")
                        Image(systemName: "chevron.down")
                    }
                }
                Spacer()
                Picker("", selection: $metric) {
                    ForEach(Metric.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            if let ex = selected {
                let points = dataPoints(for: ex, metric: metric)
                if points.isEmpty {
                    ContentUnavailableView("データなし", systemImage: "chart.xyaxis.line")
                } else {
                    Chart(points) { p in
                        LineMark(x: .value("日付", p.date), y: .value(metric.rawValue, p.value))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("日付", p.date), y: .value(metric.rawValue, p.value))
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("種目を選択してください", systemImage: "chart.xyaxis.line")
            }
            Spacer()
        }
        .onAppear {
            if selected == nil { selected = exercises.first }
        }
    }

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func dataPoints(for ex: Exercise, metric: Metric) -> [Point] {
        let cal = Calendar.current
        let setsByDay = Dictionary(grouping: ex.setRecords) { cal.startOfDay(for: $0.performedAt) }
        return setsByDay
            .map { (day, sets) -> Point in
                let value: Double
                switch metric {
                case .oneRM:
                    value = sets.compactMap { WorkoutMetrics.epley1RM(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
                case .volume:
                    value = WorkoutMetrics.totalVolume(sets: sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) })
                case .topSet:
                    value = sets.map(\.weightKg).max() ?? 0
                }
                return Point(date: day, value: value)
            }
            .sorted { $0.date < $1.date }
    }
}
