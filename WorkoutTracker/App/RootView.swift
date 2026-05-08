import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(tabSelection: $selectedTab)
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

#Preview { RootView() }
