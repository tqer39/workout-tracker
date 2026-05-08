import SwiftUI

struct JourneyHUD: View {
    let todaySteps: Int
    let dailyGoal: Int
    let progress: JourneyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            todayCard
            journeyCard
            nextCard
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日の歩数").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("目標 \(dailyGoal) 歩").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(todaySteps)").font(.system(size: 36, weight: .bold))
                Text("歩").font(.title3).foregroundStyle(.secondary)
                Spacer()
                Text("\(achievementPercent) %").font(.title2).bold()
            }
            ProgressView(value: min(1.0, Double(todaySteps) / Double(max(1, dailyGoal))))
                .tint(achievementPercent >= 100 ? .green : .orange)
        }
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var journeyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("旅の進行").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", progress.totalKm))
                    .font(.system(size: 28, weight: .bold))
                Text("km / 1,150 km").font(.body).foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: progress.progressRatio)
                .tint(.blue)
        }
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var nextCard: some View {
        if progress.isCompleted {
            HStack {
                Image(systemName: "flag.checkered").font(.title2)
                Text("旅完走！").font(.headline)
                Spacer()
            }
            .padding()
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else if let next = progress.nextCheckpoint {
            HStack {
                VStack(alignment: .leading) {
                    Text("次の地点").font(.caption).foregroundStyle(.secondary)
                    Text(next.name).font(.title3).bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("あと").font(.caption).foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", progress.metersToNext / 1000.0)) km")
                        .font(.title3).bold()
                }
            }
            .padding()
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var achievementPercent: Int {
        guard dailyGoal > 0 else { return 0 }
        return Int(Double(todaySteps) / Double(dailyGoal) * 100)
    }
}

#Preview {
    JourneyHUD(
        todaySteps: 5400,
        dailyGoal: 8000,
        progress: JourneyEngine.computeProgress(
            totalSteps: 200_000, route: JourneyRoute.tokyoToHakata
        )
    )
    .padding()
}
