import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey

    var body: some View {
        NavigationStack {
            VStack {
                Text("旅 ＆ 万歩計")
                    .font(.title2)
                Text("ここにマップと HUD を実装する")
                    .foregroundStyle(.secondary)
                Text("今日の歩数: \(journey.todaySteps)")
                Text("進行: \(String(format: "%.1f", journey.progress.totalKm)) km / 1,150 km")
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
