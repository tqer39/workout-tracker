import SwiftUI

/// 今日の歩数を「Step1 主役」として見せるカードコンポーネント。
/// 値駆動の純粋 View であり、@Environment や @Query を持たない。
struct StepHeroCard: View {
    let todaySteps: Int
    let dailyGoal: Int
    let streakDays: Int

    private var ratio: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(todaySteps) / Double(dailyGoal))
    }

    private var achieved: Bool { dailyGoal > 0 && todaySteps >= dailyGoal }

    private var percent: Int { Int(ratio * 100) }

    // 達成状態に応じてアクセントカラーを切り替える
    private var accentColor: Color { achieved ? .green : .orange }

    var body: some View {
        VStack(spacing: 16) {
            // 進捗リング（直径 160pt, 線幅 12pt）
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(
                        // LinearGradient で始点〜終点を円の上端から時計回りに見せる
                        LinearGradient(
                            colors: achieved
                                ? [Color.green.opacity(0.5), Color.green]
                                : [Color.orange.opacity(0.45), Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: ratio)

                VStack(spacing: 2) {
                    Text("\(todaySteps)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("歩")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            // 達成率と目標歩数を横並びで表示
            HStack(spacing: 12) {
                Label(
                    achieved ? "達成" : "\(percent) %",
                    systemImage: achieved ? "checkmark.seal.fill" : "figure.walk"
                )
                .font(.subheadline.bold())
                .foregroundStyle(accentColor)

                Divider().frame(height: 14)

                Text("目標 \(dailyGoal) 歩")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 連続達成が 1 日以上あるときのみバッジを表示（YAGNI: 0 日の場合は非表示）
            if streakDays >= 1 {
                Label("\(streakDays) 日連続達成", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = ["今日の歩数 \(todaySteps) 歩、目標 \(dailyGoal) 歩、達成率 \(percent) パーセント"]
        if streakDays >= 1 {
            parts.append("\(streakDays) 日連続達成")
        }
        return parts.joined(separator: "、")
    }
}

#Preview("未達成") {
    StepHeroCard(todaySteps: 4_300, dailyGoal: 8000, streakDays: 0)
        .padding()
}

#Preview("達成・連続あり") {
    StepHeroCard(todaySteps: 9_500, dailyGoal: 8000, streakDays: 5)
        .padding()
}

#Preview("ちょうど達成・連続なし") {
    StepHeroCard(todaySteps: 8_000, dailyGoal: 8000, streakDays: 0)
        .padding()
}
