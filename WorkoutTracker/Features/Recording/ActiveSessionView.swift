import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Bindable var session: WorkoutSession
    let vm: RecordingViewModel

    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: [SortDescriptor(\Exercise.name)])
    private var exercises: [Exercise]

    @State private var showingPicker = false
    @State private var pickedExercise: Exercise?
    @State private var confirmEnd = false

    private var setsByExercise: [(Exercise, [SetRecord])] {
        let grouped = Dictionary(grouping: session.sets) { $0.exercise?.id ?? UUID() }
        return grouped.compactMap { (_, sets) -> (Exercise, [SetRecord])? in
            guard let ex = sets.first?.exercise else { return nil }
            return (ex, sets.sorted { $0.performedAt < $1.performedAt })
        }
        .sorted { (a, b) in
            (a.1.first?.performedAt ?? .distantFuture) < (b.1.first?.performedAt ?? .distantFuture)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RestTimerBar(timer: vm.restTimer)

            List {
                ForEach(setsByExercise, id: \.0.id) { (ex, sets) in
                    Section(ex.name) {
                        ForEach(sets) { s in
                            HStack {
                                Text("\(formatWeight(s.weightKg)) kg × \(s.reps)")
                                if let rpe = s.rpe {
                                    Text("RPE \(String(format: "%.1f", rpe))")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(s.performedAt, style: .time).foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button("削除", role: .destructive) {
                                    vm.deleteSet(s)
                                }
                            }
                        }
                        SetInputRow(exercise: ex) { weight, reps, rpe in
                            vm.addSet(exercise: ex, weightKg: weight, reps: reps, rpe: rpe)
                        }
                    }
                }

                Section {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("種目を追加", systemImage: "plus")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmEnd = true
                } label: {
                    Text("終了")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView(exercises: exercises) { ex in
                pickedExercise = ex
                addEmptySection(for: ex)
            }
        }
        .confirmationDialog("セッションを終了しますか?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("終了する", role: .destructive) { vm.endSession() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func addEmptySection(for ex: Exercise) {
        // セクションはセット追加時に自然に出現するので、ここでは何もしない。
        // ただし、まだセット無しでも種目選択を表示したい場合はダミー挿入が必要だが、
        // 「SetInputRow で 1 セット目を入力する」運用なので種目選択結果を保持するのみ。
        pickedExercise = ex
    }

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
    }
}

struct RestTimerBar: View {
    let timer: RestTimer
    @State private var tick = Date()

    var body: some View {
        Group {
            if timer.isRunning {
                let remaining = timer.remainingSeconds(at: tick)
                HStack {
                    Image(systemName: "timer")
                    Text("休憩: \(remaining) 秒")
                        .monospacedDigit()
                    Spacer()
                    Button("キャンセル") { timer.cancel() }
                        .buttonStyle(.bordered)
                }
                .padding()
                .background(remaining == 0 ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            tick = now
        }
    }
}
