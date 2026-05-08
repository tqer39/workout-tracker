import Foundation
import SwiftData
@testable import WorkoutTracker

enum InMemoryContainer {
    @MainActor
    static func make() throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
            StepDailyRecord.self,
            CheckpointAchievement.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
