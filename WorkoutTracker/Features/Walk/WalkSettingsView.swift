import SwiftUI

struct WalkSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JourneyService.self) private var journey

    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @AppStorage("walk.celebrationConfettiEnabled") private var confettiEnabled: Bool = true
    @AppStorage("walk.celebrationSoundEnabled") private var soundEnabled: Bool = true
    @AppStorage("walk.celebrationHapticEnabled") private var hapticEnabled: Bool = true

    @State private var showResetConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("1 日の歩数目標") {
                    Stepper(value: $dailyGoal, in: 2000...30000, step: 500) {
                        Text("\(dailyGoal) 歩")
                    }
                }
                Section("演出") {
                    Toggle("紙吹雪", isOn: $confettiEnabled)
                    Toggle("達成音", isOn: $soundEnabled)
                    Toggle("触覚フィードバック", isOn: $hapticEnabled)
                }
                Section("旅") {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("旅の進行をリセット", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .confirmationDialog(
                "旅の進行をリセットしますか？歩数履歴は保持されます。",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    journey.resetJourney()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

#Preview {
    WalkSettingsView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
