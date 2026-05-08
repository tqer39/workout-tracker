import Foundation

enum CompanionDialog {
    static func line(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        lastShown: String?
    ) -> String {
        let pool = pool(progress: progress, todaySteps: todaySteps,
                        dailyGoal: dailyGoal, timeOfDay: timeOfDay)
        let candidates = pool.filter { $0 != lastShown }
        let pick = candidates.isEmpty ? pool : candidates
        return pick.randomElement() ?? "今日もぼちぼちいこう。"
    }

    private static func pool(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay
    ) -> [String] {
        if progress.isCompleted {
            return [
                "ついに博多到着！本当におつかれさま。",
                "完走おめでとう！次の旅も楽しみだね。",
                "1,150 km をその足で踏破。すごいことだよ。",
            ]
        }

        let achieved = todaySteps >= dailyGoal
        let nextName = progress.nextCheckpoint?.name ?? "次の地点"
        let kmToNext = String(format: "%.1f", progress.metersToNext / 1000.0)

        if achieved {
            return [
                "今日の目標達成！えらい！",
                "目標クリア。ご褒美時間にしよ。",
                "目標達成、いい流れだね。",
                "\(nextName) まであと \(kmToNext) km。明日も歩こう。",
            ]
        }

        let remaining = max(0, dailyGoal - todaySteps)
        let timeOpener: String
        switch timeOfDay {
        case .morning: timeOpener = "おはよう。"
        case .day:     timeOpener = "今日もいいペースだね。"
        case .evening: timeOpener = "夕方のひと歩きで距離を稼ごう。"
        case .night:   timeOpener = "今日はもう少しだけ。"
        }

        return [
            "\(timeOpener) あと \(remaining) 歩で目標。",
            "\(timeOpener) \(nextName) まであと \(kmToNext) km。",
            "\(timeOpener) ゆっくりでいいよ、続けることが大事。",
            "\(nextName) で名物が待ってるよ。",
        ]
    }
}
