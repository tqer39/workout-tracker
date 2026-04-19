import SwiftUI
import SwiftData

struct SessionsListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    var body: some View {
        List {
            ForEach(sessions) { s in
                NavigationLink {
                    SessionDetailView(session: s)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.startedAt, style: .date).font(.headline)
                        HStack {
                            Text(s.startedAt, style: .time)
                            if let end = s.endedAt {
                                Text("〜")
                                Text(end, style: .time)
                            } else {
                                Text("進行中").foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text("\(s.sets.count) セット ・ 総ボリューム \(formatVolume(totalVolume(s))) kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("削除", role: .destructive) {
                        ctx.delete(s)
                        try? ctx.save()
                    }
                }
            }
        }
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView("セッションなし", systemImage: "clock.arrow.circlepath",
                                       description: Text("記録タブから開始"))
            }
        }
    }

    private func totalVolume(_ s: WorkoutSession) -> Double {
        WorkoutMetrics.totalVolume(sets: s.sets.map {
            .init(weightKg: $0.weightKg, reps: $0.reps)
        })
    }

    private func formatVolume(_ v: Double) -> String {
        String(Int(v.rounded()))
    }
}
