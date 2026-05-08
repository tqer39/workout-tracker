import Foundation

struct JourneyProgress: Equatable {
    let totalSteps: Int
    let totalKm: Double
    let progressRatio: Double
    let lastPassedCheckpoint: Checkpoint?
    let nextCheckpoint: Checkpoint?
    let metersToNext: Double
    let isCompleted: Bool

    static let empty = JourneyProgress(
        totalSteps: 0,
        totalKm: 0,
        progressRatio: 0,
        lastPassedCheckpoint: nil,
        nextCheckpoint: nil,
        metersToNext: 0,
        isCompleted: false
    )
}

enum JourneyEngine {
    static func computeProgress(
        totalSteps: Int,
        route: [Checkpoint],
        metersPerStep: Double = 1.0
    ) -> JourneyProgress {
        guard let last = route.last, !route.isEmpty else { return .empty }
        let totalMeters = Double(totalSteps) * metersPerStep
        let totalKm = totalMeters / 1000.0
        let routeTotalKm = last.cumulativeKm
        let isCompleted = totalKm >= routeTotalKm
        let clampedKm = min(totalKm, routeTotalKm)
        let ratio = routeTotalKm > 0 ? clampedKm / routeTotalKm : 0

        let passedIndex = route.lastIndex(where: { $0.cumulativeKm <= clampedKm }) ?? 0
        let lastPassed = route[passedIndex]
        let next: Checkpoint? = (passedIndex + 1 < route.count) ? route[passedIndex + 1] : nil
        let metersToNext = (next?.cumulativeKm ?? routeTotalKm) * 1000.0 - totalMeters

        return JourneyProgress(
            totalSteps: totalSteps,
            totalKm: clampedKm,
            progressRatio: ratio,
            lastPassedCheckpoint: lastPassed,
            nextCheckpoint: isCompleted ? nil : next,
            metersToNext: max(0, metersToNext),
            isCompleted: isCompleted
        )
    }

    static func passedCheckpointIds(
        totalSteps: Int,
        route: [Checkpoint],
        metersPerStep: Double = 1.0
    ) -> Set<String> {
        let totalKm = Double(totalSteps) * metersPerStep / 1000.0
        return Set(route.filter { $0.cumulativeKm <= totalKm }.map(\.id))
    }
}
