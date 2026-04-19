import SwiftUI

struct SetInputRow: View {
    let exercise: Exercise
    let onSubmit: (_ weightKg: Double, _ reps: Int, _ rpe: Double?) -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var rpe: Double = 7.0
    @State private var showRPE: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("kg", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("×")
                TextField("回", text: $repsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button {
                    submit()
                } label: {
                    Label("追加", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
            Toggle("RPE を入力", isOn: $showRPE)
                .font(.caption)
            if showRPE {
                HStack {
                    Text("RPE \(String(format: "%.1f", rpe))")
                        .monospacedDigit()
                    Slider(value: $rpe, in: 5...10, step: 0.5)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { prefill() }
    }

    private var canSubmit: Bool {
        guard let w = parsedWeight, w > 0 else { return false }
        guard let r = parsedReps, r > 0 else { return false }
        return true
    }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }
    private var parsedReps: Int? { Int(repsText) }

    private func prefill() {
        if weightText.isEmpty, let dw = exercise.defaultWeightKg {
            weightText = formatWeight(dw)
        }
    }

    private func submit() {
        guard let w = parsedWeight, let r = parsedReps else { return }
        onSubmit(w, r, showRPE ? rpe : nil)
        repsText = ""
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
    }
}
