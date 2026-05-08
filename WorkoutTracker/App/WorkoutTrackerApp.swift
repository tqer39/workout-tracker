import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @State private var journey: JourneyService

    init() {
        let c = ModelContainerFactory.makeShared()
        self.container = c
        let svc = JourneyService(
            healthKit: LiveHealthKitService(),
            container: c
        )
        self._journey = State(initialValue: svc)

        Task { @MainActor [container = c] in
            SeedService.seedIfNeeded(
                context: container.mainContext,
                flagStore: UserDefaultsSeedFlagStore()
            )
        }
        Task { @MainActor in
            await svc.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(journey)
        }
        .modelContainer(container)
    }
}
