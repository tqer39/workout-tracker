import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: WorkoutSession

    private var setsByExercise: [(Exercise, [SetRecord])] {
        let grouped = Dictionary(grouping: session.sets) { $0.exercise?.id ?? UUID() }
        return grouped.compactMap { (_, sets) -> (Exercise, [SetRecord])? in
            guard let ex = sets.first?.exercise else { return nil }
            return (ex, sets.sorted { $0.performedAt < $1.performedAt })
        }
        .sorted { (a, b) in
            (a.1.first?.performedAt ?? .distantFuture) < (b.1.first?.performedAt ?? .distantFuture)
        }
    }

    var body: some View {
        List {
            Section("サマリ") {
                LabeledContent("開始") { Text(session.startedAt, style: .date) + Text(" ") + Text(session.startedAt, style: .time) }
                if let end = session.endedAt {
                    LabeledContent("終了") { Text(end, style: .time) }
                    LabeledContent("所要") { Text(duration(session.startedAt, end)) }
                }
                LabeledContent("総ボリューム") {
                    Text("\(formatVolume(totalVolume)) kg")
                }
                LabeledContent("総セット数") { Text("\(session.sets.count)") }
            }

            ForEach(setsByExercise, id: \.0.id) { (ex, sets) in
                Section(ex.name) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { i, s in
                        HStack {
                            Text("#\(i + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)
                            Text("\(formatWeight(s.weightKg)) kg × \(s.reps)")
                            if let rpe = s.rpe {
                                Text("RPE \(String(format: "%.1f", rpe))")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(s.performedAt, style: .time).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var totalVolume: Double {
        WorkoutMetrics.totalVolume(sets: session.sets.map {
            .init(weightKg: $0.weightKg, reps: $0.reps)
        })
    }

    private func formatVolume(_ v: Double) -> String { String(Int(v.rounded())) }
    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
    }

    private func duration(_ start: Date, _ end: Date) -> String {
        let seconds = Int(end.timeIntervalSince(start))
        let m = seconds / 60
        let s = seconds % 60
        return "\(m)分\(s)秒"
    }
}
