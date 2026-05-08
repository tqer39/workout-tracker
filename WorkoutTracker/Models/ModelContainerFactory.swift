import Foundation
import SwiftData

enum ModelContainerFactory {
    @MainActor
    static func makeShared() -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
            StepDailyRecord.self,
            CheckpointAchievement.self,
            SleepDailyRecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }
}
