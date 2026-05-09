import Foundation

enum CompanionDialog {
    static func line(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        streakDays: Int,
        lastShown: String?,
        lines: [CompanionLine] = CompanionDialog.bundledLines
    ) -> String {
        let progressBand: ProgressBand = progress.isCompleted
            ? .completed
            : (todaySteps >= dailyGoal ? .achieved : .unmet)
        let distanceBand = DistanceBand.from(progress: progress.progressRatio)
        let streakBand = StreakBand.from(streakDays: streakDays)
        let filter = CompanionLineFilter(
            progress: progressBand,
            timeOfDay: timeOfDay,
            streak: streakBand,
            distance: distanceBand
        )

        var candidates = lines.filter { filter.matches($0) }

        // lastShown を除外。除外後に空になるなら lastShown を復活させる
        let withoutLast = candidates.filter { $0.text != lastShown }
        if !withoutLast.isEmpty { candidates = withoutLast }

        if candidates.isEmpty {
            // progress だけでフォールバック
            candidates = lines.filter { $0.progress == nil || $0.progress!.contains(progressBand) }
            let withoutLast2 = candidates.filter { $0.text != lastShown }
            if !withoutLast2.isEmpty { candidates = withoutLast2 }
        }

        if candidates.isEmpty { candidates = lines }

        return candidates.randomElement()?.text ?? "今日もぼちぼちいこう。"
    }

    static let bundledLines: [CompanionLine] = {
        guard let url = Bundle.main.url(forResource: "CompanionLines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CompanionLine].self, from: data) else {
            return []
        }
        return decoded
    }()
}
