import Foundation
import SwiftData

#if DEBUG
enum PreviewModelContainer {
    @MainActor
    static func make() -> ModelContainer {
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
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("PreviewModelContainer の作成に失敗: \(error)")
        }
    }
}
#endif
