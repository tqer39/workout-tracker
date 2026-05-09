import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @State private var journey: JourneyService
    @State private var sleep: SleepService
    @State private var router: AppRouter

    init() {
        let c = ModelContainerFactory.makeShared()
        self.container = c
        let healthKit = LiveHealthKitService()
        let svc = JourneyService(healthKit: healthKit, container: c)
        self._journey = State(initialValue: svc)
        let sleepSvc = SleepService(healthKit: healthKit, container: c)
        self._sleep = State(initialValue: sleepSvc)
        self._router = State(initialValue: AppRouter())

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
                .environment(router)
        }
        .modelContainer(container)
    }
}
