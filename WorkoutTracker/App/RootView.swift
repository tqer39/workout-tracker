import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView(tabSelection: $router.selectedTab)
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(AppTab.home)
            RecordingView()
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
                .tag(AppTab.recording)
            MenuView()
                .tabItem { Label("メニュー", systemImage: "list.bullet") }
                .tag(AppTab.menu)
            HistoryView()
                .tabItem { Label("履歴", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.history)
            WalkView()
                .tabItem { Label("歩く", systemImage: "figure.walk") }
                .tag(AppTab.walk)
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
}
