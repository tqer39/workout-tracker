import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tag(AppRouter.Tab.home)
                .tabItem { Label("ホーム", systemImage: "house") }
            RecordingView()
                .tag(AppRouter.Tab.recording)
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
            MenuView()
                .tag(AppRouter.Tab.menu)
                .tabItem { Label("メニュー", systemImage: "list.bullet") }
            HistoryView()
                .tag(AppRouter.Tab.history)
                .tabItem { Label("履歴", systemImage: "chart.line.uptrend.xyaxis") }
            WalkView()
                .tag(AppRouter.Tab.walk)
                .tabItem { Label("旅", systemImage: "map") }
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
}
