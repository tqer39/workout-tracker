import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                        .padding(.horizontal)
                    JourneyHUD(
                        todaySteps: journey.todaySteps,
                        dailyGoal: dailyGoal,
                        progress: journey.progress
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
            }
            .onDisappear {
                journey.stopObserving()
            }
        }
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
