import SwiftUI

struct MenuView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case exercises = "種目"
        case templates = "テンプレート"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .exercises

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch tab {
                case .exercises:
                    ExercisesListView()
                case .templates:
                    TemplatesListView()
                }
            }
            .navigationTitle("メニュー")
        }
    }
}

#Preview {
    MenuView()
        .modelContainer(for: [Exercise.self, WorkoutTemplate.self, TemplateExercise.self], inMemory: true)
}
