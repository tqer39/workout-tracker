import Foundation

enum WorkoutMetrics {
    struct SetInput {
        let weightKg: Double
        let reps: Int
    }

    static func totalVolume(sets: [SetInput]) -> Double {
        sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    static func epley1RM(weightKg: Double, reps: Int) -> Double? {
        guard reps > 0 else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }
}
