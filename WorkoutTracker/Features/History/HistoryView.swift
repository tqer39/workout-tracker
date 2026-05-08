import SwiftUI
import SwiftData

struct HistoryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case sessions = "セッション"
        case charts = "グラフ"
        case body = "体組成"
        case sleep = "睡眠"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .sessions

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch tab {
                case .sessions: SessionsListView()
                case .charts: ExerciseChartsView()
                case .body: BodyCompositionView()
                case .sleep: SleepHistoryView()
                }
            }
            .navigationTitle("履歴")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self
        ], inMemory: true)
}
