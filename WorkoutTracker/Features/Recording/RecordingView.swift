import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(SleepService.self) private var sleep
    @State private var vm = RecordingViewModel()
    @Query(sort: [SortDescriptor(\WorkoutTemplate.order), SortDescriptor(\WorkoutTemplate.name)])
    private var templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sleepHeader
                Group {
                    if let session = vm.session {
                        ActiveSessionView(session: session, vm: vm)
                    } else {
                        startView
                    }
                }
            }
            .navigationTitle("記録")
        }
        .onAppear {
            vm.bind(context: ctx)
            Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    @ViewBuilder
    private var sleepHeader: some View {
        if let m = sleep.lastNightMinutes {
            Text(String(format: "昨夜 %.1f h", Double(m) / 60.0))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 4)
        } else {
            EmptyView()
        }
    }

    private var startView: some View {
        List {
            Section {
                Button {
                    vm.startEmptySession()
                } label: {
                    Label("空のセッションを開始", systemImage: "play.fill")
                }
            }
            if !templates.isEmpty {
                Section("テンプレートから開始") {
                    ForEach(templates) { t in
                        Button {
                            vm.startSession(from: t)
                        } label: {
                            HStack {
                                Text(t.name)
                                Spacer()
                                Text("\(t.exercises.count) 種目")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: [
            Exercise.self, WorkoutSession.self, SetRecord.self,
            WorkoutTemplate.self, TemplateExercise.self,
            SleepDailyRecord.self
        ], inMemory: true)
        .environment(SleepService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
