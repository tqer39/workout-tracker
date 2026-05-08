import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @State private var lastCompanionLine: String?
    @State private var activeCelebration: CheckpointAchievement?
    @State private var showingHistory: Bool = false

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingHistory = true } label: {
                        Image(systemName: "chart.bar")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                StepHistoryView()
            }
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
                presentNextCelebrationIfNeeded()
            }
            .onChange(of: journey.pendingCelebrations.count) { _, _ in
                presentNextCelebrationIfNeeded()
            }
            .onDisappear {
                journey.stopObserving()
            }
            .fullScreenCover(item: $activeCelebration) { ach in
                if let cp = JourneyRoute.tokyoToHakata.first(where: { $0.id == ach.checkpointId }) {
                    CelebrationOverlay(achievement: ach, checkpoint: cp) {
                        journey.markCelebrated(ach)
                        activeCelebration = nil
                    }
                }
            }
        }
    }

    private func presentNextCelebrationIfNeeded() {
        guard activeCelebration == nil else { return }
        activeCelebration = journey.pendingCelebrations.first
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
