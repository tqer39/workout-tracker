import SwiftUI
import SwiftData

struct ExerciseFormView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?

    @State private var name: String = ""
    @State private var category: ExerciseCategory = .chest
    @State private var defaultWeightText: String = ""
    @State private var defaultRestSeconds: Int = 90
    @State private var notes: String = ""

    private var isEditing: Bool { exercise != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("種目名", text: $name)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                }
                Section("デフォルト") {
                    TextField("重量 (kg)", text: $defaultWeightText)
                        .keyboardType(.decimalPad)
                    Stepper("休憩 \(defaultRestSeconds) 秒", value: $defaultRestSeconds, in: 15...600, step: 15)
                }
                Section("メモ") {
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "種目を編集" : "種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let ex = exercise else { return }
        name = ex.name
        category = ex.category
        defaultWeightText = ex.defaultWeightKg.map { String($0) } ?? ""
        defaultRestSeconds = ex.defaultRestSeconds
        notes = ex.notes ?? ""
    }

    private func save() {
        let weight = Double(defaultWeightText.replacingOccurrences(of: ",", with: "."))
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ex = exercise {
            ex.name = name
            ex.category = category
            ex.defaultWeightKg = weight
            ex.defaultRestSeconds = defaultRestSeconds
            ex.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let new = Exercise(
                name: name,
                category: category,
                defaultWeightKg: weight,
                defaultRestSeconds: defaultRestSeconds,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            ctx.insert(new)
        }
        try? ctx.save()
        dismiss()
    }
}

#Preview {
    ExerciseFormView(exercise: nil)
        .modelContainer(for: Exercise.self, inMemory: true)
}
