import SwiftUI
import SwiftData

struct TemplatesListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\WorkoutTemplate.order), SortDescriptor(\WorkoutTemplate.name)])
    private var templates: [WorkoutTemplate]

    @State private var editing: WorkoutTemplate?
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(templates) { t in
                Button { editing = t } label: {
                    HStack {
                        Text(t.name)
                        Spacer()
                        Text("\(t.exercises.count) 種目")
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("削除", role: .destructive) {
                        ctx.delete(t)
                        try? ctx.save()
                    }
                }
            }
        }
        .overlay {
            if templates.isEmpty {
                ContentUnavailableView("テンプレートなし", systemImage: "list.clipboard",
                                       description: Text("＋からテンプレートを作成"))
            }
        }
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            TemplateEditorView(template: nil)
        }
        .sheet(item: $editing) { t in
            TemplateEditorView(template: t)
        }
    }
}

#Preview {
    NavigationStack { TemplatesListView() }
        .modelContainer(for: [WorkoutTemplate.self, Exercise.self, TemplateExercise.self], inMemory: true)
}
