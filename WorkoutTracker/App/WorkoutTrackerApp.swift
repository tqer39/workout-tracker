import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @State private var journey: JourneyService
    @State private var sleep: SleepService

    init() {
        let c = ModelContainerFactory.makeShared()
        self.container = c
        let svc = JourneyService(
            healthKit: LiveHealthKitService(),
            container: c
        )
        self._journey = State(initialValue: svc)
        let sleepSvc = SleepService(
            healthKit: LiveHealthKitService(),
            container: c
        )
        self._sleep = State(initialValue: sleepSvc)

        Task { @MainActor [container = c] in
            SeedService.seedIfNeeded(
                context: container.mainContext,
                flagStore: UserDefaultsSeedFlagStore()
            )
        }
        Task { @MainActor in
            await svc.bootstrap()
        }
        Task { @MainActor in
            await sleepSvc.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(journey)
                .environment(sleep)
        }
        .modelContainer(container)
    }
}
