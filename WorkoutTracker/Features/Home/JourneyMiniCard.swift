import SwiftUI

/// ホーム画面用の控えめな旅進捗カード。
/// 「旅は動機づけであって主役ではない」方針のため StepHeroCard より小ぶりに設計。
/// 値駆動の純粋 View であり、@Environment や @Query を持たない。
struct JourneyMiniCard: View {
    let progress: JourneyProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    titleLine
                    subtitleLine
                    progressBar
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var thumbnail: some View {
        // 次のチェックポイント画像を優先し、なければ直前の通過済みチェックポイントを使う
        let assetName = progress.nextCheckpoint?.sceneryAssetName
            ?? progress.lastPassedCheckpoint?.sceneryAssetName
            ?? "Scenery/tokyo"
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.blue.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            Image(assetName)
                .resizable()
                .scaledToFill()
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var titleLine: some View {
        if progress.isCompleted {
            Text("博多到達！おつかれさま。")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        } else if let next = progress.nextCheckpoint {
            Text("\(next.name) まであと \(kmToNext) km")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        } else {
            Text("今日から旅をはじめよう")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var subtitleLine: some View {
        if progress.isCompleted {
            Text("\(Int(progress.totalKm)) km 走破")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let last = progress.lastPassedCheckpoint {
            Text("最後に通過: \(last.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("東京から博多 1,150 km")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // GeometryReader は Button 内でレイアウトが不安定になることがあるため固定幅で実装
    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.secondary.opacity(0.18))
            Capsule()
                .fill(progress.isCompleted ? Color.green : Color.orange)
                .frame(width: 200 * progress.progressRatio)
        }
        .frame(width: 200, height: 4)
    }

    private var kmToNext: String {
        String(format: "%.1f", progress.metersToNext / 1000.0)
    }

    private var accessibilityLabel: String {
        if progress.isCompleted {
            return "旅は完走しました。タップして詳細を見る"
        } else if let next = progress.nextCheckpoint {
            return "次は \(next.name)。あと \(kmToNext) キロメートル。タップして歩くタブへ"
        } else {
            return "旅を開始する。タップして歩くタブへ"
        }
    }
}

#Preview("進行中") {
    JourneyMiniCard(
        progress: JourneyProgress(
            totalSteps: 200_000,
            totalKm: 200,
            progressRatio: 0.17,
            lastPassedCheckpoint: JourneyRoute.tokyoToHakata[1],
            nextCheckpoint: JourneyRoute.tokyoToHakata[2],
            metersToNext: 5_000,
            isCompleted: false
        ),
        onTap: {}
    )
    .padding()
}

#Preview("スタート前") {
    JourneyMiniCard(progress: .empty, onTap: {})
        .padding()
}

#Preview("完走") {
    JourneyMiniCard(
        progress: JourneyProgress(
            totalSteps: 1_500_000,
            totalKm: 1_150,
            progressRatio: 1.0,
            lastPassedCheckpoint: JourneyRoute.tokyoToHakata.last,
            nextCheckpoint: nil,
            metersToNext: 0,
            isCompleted: true
        ),
        onTap: {}
    )
    .padding()
}
