import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @State private var lastCompanionLine: String?

    private var timeOfDay: TimeOfDay { .from(Date()) }

    private var companionLine: String {
        CompanionDialog.line(
            progress: journey.progress,
            todaySteps: journey.todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
            lastShown: lastCompanionLine
        )
    }

    private var companionMood: CompanionBubble.Mood {
        if journey.progress.isCompleted { return .celebrate }
        if journey.todaySteps >= dailyGoal { return .cheer }
        return .neutral
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                TimeOfDayBackground(timeOfDay: timeOfDay)
                    .frame(height: 220)

                ScrollView {
                    VStack(spacing: 16) {
                        CompanionBubble(line: companionLine, mood: companionMood)
                            .padding(.horizontal)
                            .onAppear { lastCompanionLine = companionLine }

                        WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                            .padding(.horizontal)
                        JourneyHUD(
                            todaySteps: journey.todaySteps,
                            dailyGoal: dailyGoal,
                            progress: journey.progress
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
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
