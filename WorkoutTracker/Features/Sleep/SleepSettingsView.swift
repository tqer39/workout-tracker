import SwiftUI

struct SleepSettingsView: View {
    @AppStorage("sleep.targetHours") private var targetHours: Double = 7.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("睡眠目標時間") {
                    Stepper(value: $targetHours, in: 5.0...10.0, step: 0.5) {
                        Text(String(format: "%.1f h", targetHours))
                    }
                }
            }
            .navigationTitle("睡眠設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

#Preview { SleepSettingsView() }
