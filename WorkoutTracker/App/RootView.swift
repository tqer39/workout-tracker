import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            RecordingView()
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
            MenuView()
                .tabItem { Label("メニュー", systemImage: "list.bullet") }
            HistoryView()
                .tabItem { Label("履歴", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

#Preview { RootView() }
