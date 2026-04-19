import SwiftUI
import SwiftData

struct ExercisesListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Exercise.name)])
    private var exercises: [Exercise]

    @State private var editing: Exercise?
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(exercises.filter { !$0.isHidden }) { ex in
                Button { editing = ex } label: {
                    HStack {
                        Text(ex.name)
                        Spacer()
                        Text(ex.category.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("非表示", role: .destructive) {
                        ex.isHidden = true
                        try? ctx.save()
                    }
                }
            }
        }
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            ExerciseFormView(exercise: nil)
        }
        .sheet(item: $editing) { ex in
            ExerciseFormView(exercise: ex)
        }
    }
}

#Preview {
    NavigationStack { ExercisesListView() }
        .modelContainer(for: Exercise.self, inMemory: true)
}
