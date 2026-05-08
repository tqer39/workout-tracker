import SwiftUI
import SwiftData

struct BadgesView: View {
    @Query private var achievements: [CheckpointAchievement]

    @State private var detail: Checkpoint?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(JourneyRoute.tokyoToHakata) { cp in
                        BadgeCell(
                            checkpoint: cp,
                            achievement: achievements.first { $0.checkpointId == cp.id }
                        )
                        .onTapGesture {
                            if achievements.contains(where: { $0.checkpointId == cp.id }) {
                                detail = cp
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("バッジ")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $detail) { cp in
                BadgeDetailSheet(checkpoint: cp,
                                 achievement: achievements.first { $0.checkpointId == cp.id })
            }
        }
    }
}

private struct BadgeCell: View {
    let checkpoint: Checkpoint
    let achievement: CheckpointAchievement?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement != nil ? "rosette" : "lock")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(achievement != nil ? .yellow : .gray.opacity(0.5))
            Text(checkpoint.name)
                .font(.caption)
                .foregroundStyle(achievement != nil ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BadgeDetailSheet: View {
    let checkpoint: Checkpoint
    let achievement: CheckpointAchievement?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "rosette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.yellow)
                Text(checkpoint.name).font(.title).bold()
                Text(checkpoint.blurb)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let a = achievement {
                    VStack {
                        Text("到達日: \(a.achievedAt, style: .date)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(a.totalStepsAtAchievement) 歩で到達")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("バッジ")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    BadgesView()
        .modelContainer(for: [CheckpointAchievement.self, StepDailyRecord.self], inMemory: true)
}
