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
            SleepDailyRecord.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

#if DEBUG
extension InMemoryContainer {
    @MainActor
    static func seeded(_ build: (ModelContext) -> Void) throws -> ModelContainer {
        let container = try make()
        build(container.mainContext)
        try container.mainContext.save()
        return container
    }
}
#endif
