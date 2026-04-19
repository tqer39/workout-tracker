import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let template: WorkoutTemplate?

    @State private var name: String = ""
    @State private var items: [DraftItem] = []
    @State private var showingPicker = false

    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: [SortDescriptor(\Exercise.name)])
    private var exercises: [Exercise]

    struct DraftItem: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var targetSets: Int
        var targetReps: Int
        var targetWeightKg: Double?
    }

    private var isEditing: Bool { template != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("テンプレート名", text: $name)
                }
                Section("種目") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.exercise.name).font(.headline)
                            HStack {
                                Stepper("セット \(item.targetSets)", value: $item.targetSets, in: 1...20)
                            }
                            HStack {
                                Stepper("レップ \(item.targetReps)", value: $item.targetReps, in: 1...50)
                            }
                            HStack {
                                Text("重量")
                                TextField("kg", value: $item.targetWeightKg, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }

                    Button { showingPicker = true } label: {
                        Label("種目を追加", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(isEditing ? "テンプレート編集" : "テンプレート作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(exercises: exercises) { ex in
                    items.append(
                        DraftItem(
                            exercise: ex,
                            targetSets: 3,
                            targetReps: 10,
                            targetWeightKg: ex.defaultWeightKg
                        )
                    )
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let t = template else { return }
        name = t.name
        items = t.exercises
            .sorted { $0.order < $1.order }
            .compactMap { te in
                guard let ex = te.exercise else { return nil }
                return DraftItem(
                    exercise: ex,
                    targetSets: te.targetSets,
                    targetReps: te.targetReps,
                    targetWeightKg: te.targetWeightKg
                )
            }
    }

    private func save() {
        let target: WorkoutTemplate
        if let t = template {
            target = t
            target.name = name
            for te in t.exercises { ctx.delete(te) }
            target.exercises.removeAll()
        } else {
            target = WorkoutTemplate(name: name)
            ctx.insert(target)
        }
        for (i, item) in items.enumerated() {
            let te = TemplateExercise(
                order: i,
                exercise: item.exercise,
                targetSets: item.targetSets,
                targetReps: item.targetReps,
                targetWeightKg: item.targetWeightKg
            )
            te.template = target
            ctx.insert(te)
        }
        try? ctx.save()
        dismiss()
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [Exercise]
    let onPick: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            List(exercises) { ex in
                Button {
                    onPick(ex)
                    dismiss()
                } label: {
                    HStack {
                        Text(ex.name)
                        Spacer()
                        Text(ex.category.displayName).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}
