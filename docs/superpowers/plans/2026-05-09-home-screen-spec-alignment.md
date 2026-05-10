# ホーム画面仕様適合化 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 原典 spec §4.1 で要求されているがホーム画面に未実装の 3 項目（ホームからのワークアウト開始、直近 3 セッションサマリ、体重 30 日スパークライン）を実装し、`AppRouter` 経由でタブ間遷移を疎結合に保つ。

**Architecture:** 新規 `@Observable AppRouter` を Environment に注入し、`selectedTab` と `pendingStart` を保持。HomeView がカードタップ時に `pendingStart` を立てて `selectedTab = .recording` に切替、RecordingView が `.onChange` / `.onAppear` で `consumePendingStart()` し既存 `RecordingViewModel.startSession(...)` を呼び出す。直近 3 セッションは既存 `sessions` クエリから in-memory フィルタ、体重スパークラインは Swift Charts の軸非表示折れ線で描画。

**Tech Stack:** Swift 5.10 / SwiftUI / SwiftData / Swift Charts / XCTest / XcodeGen / iOS 18+。

**Spec:** `docs/superpowers/specs/2026-05-09-home-screen-spec-alignment-design.md`

---

## File Structure

### 新規ファイル

| パス | 役割 |
|------|------|
| `WorkoutTracker/App/AppRouter.swift` | `@Observable` クラス。`selectedTab` と `pendingStart` を保持し、`requestStart(...)` / `consumePendingStart()` を提供 |
| `WorkoutTrackerTests/AppRouterTests.swift` | `AppRouter` の振る舞い 4 ケース |

### 修正ファイル

| パス | 変更内容 |
|------|---------|
| `WorkoutTracker/App/WorkoutTrackerApp.swift` | `AppRouter` を生成・`.environment(...)` 注入 |
| `WorkoutTracker/App/RootView.swift` | `TabView(selection: $router.selectedTab)` にし、各タブに `.tag(...)` |
| `WorkoutTracker/Features/Recording/RecordingView.swift` | `AppRouter` を Environment 経由で取得し `pendingStart` 消費ロジック追加（既存 `startView` は残す） |
| `WorkoutTracker/Features/Home/HomeView.swift` | 「ワークアウト開始」横スクロール / 「直近 3 セッション」差し替え / 「体重トレンド」スパークライン追加 |

---

## Task 1: `AppRouter` を新規追加

**Files:**
- Create: `WorkoutTracker/App/AppRouter.swift`
- Create: `WorkoutTrackerTests/AppRouterTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

新規ファイル `WorkoutTrackerTests/AppRouterTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

@MainActor
final class AppRouterTests: XCTestCase {
    func test_initial_state_is_home_and_no_pending() {
        let router = AppRouter()
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertNil(router.pendingStart)
    }

    func test_requestStart_template_sets_pending_and_switches_tab() {
        let router = AppRouter()
        let id = UUID()
        router.requestStart(template: id)
        XCTAssertEqual(router.pendingStart, .template(id))
        XCTAssertEqual(router.selectedTab, .recording)
    }

    func test_requestStartEmpty_sets_pending_and_switches_tab() {
        let router = AppRouter()
        router.requestStartEmpty()
        XCTAssertEqual(router.pendingStart, .empty)
        XCTAssertEqual(router.selectedTab, .recording)
    }

    func test_consumePendingStart_returns_value_and_clears() {
        let router = AppRouter()
        let id = UUID()
        router.requestStart(template: id)

        let consumed = router.consumePendingStart()
        XCTAssertEqual(consumed, .template(id))
        XCTAssertNil(router.pendingStart)

        let consumedAgain = router.consumePendingStart()
        XCTAssertNil(consumedAgain)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/AppRouterTests
```

期待: コンパイルエラー（`AppRouter` 未定義）。

- [ ] **Step 3: 実装を書く**

新規ファイル `WorkoutTracker/App/AppRouter.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case home, recording, menu, history, walk
    }
    enum PendingStart: Equatable {
        case empty
        case template(UUID)
    }

    var selectedTab: Tab = .home
    var pendingStart: PendingStart?

    init(selectedTab: Tab = .home, pendingStart: PendingStart? = nil) {
        self.selectedTab = selectedTab
        self.pendingStart = pendingStart
    }

    func requestStart(template id: UUID) {
        pendingStart = .template(id)
        selectedTab = .recording
    }

    func requestStartEmpty() {
        pendingStart = .empty
        selectedTab = .recording
    }

    func consumePendingStart() -> PendingStart? {
        defer { pendingStart = nil }
        return pendingStart
    }
}
```

- [ ] **Step 4: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

期待: 警告なしで終わる。

- [ ] **Step 5: テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/AppRouterTests
```

期待: 4 テストが PASS。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/App/AppRouter.swift \
        WorkoutTrackerTests/AppRouterTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: AppRouter を追加（タブ切替 + ワークアウト開始ペンディング）

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `WorkoutTrackerApp` と `RootView` の AppRouter 連携

**Files:**
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`
- Modify: `WorkoutTracker/App/RootView.swift`

- [ ] **Step 1: `WorkoutTrackerApp` に AppRouter を生成・注入する**

`WorkoutTracker/App/WorkoutTrackerApp.swift` を以下に置き換える:

```swift
import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @State private var journey: JourneyService
    @State private var sleep: SleepService
    @State private var router: AppRouter

    init() {
        let c = ModelContainerFactory.makeShared()
        self.container = c
        let healthKit = LiveHealthKitService()
        let svc = JourneyService(healthKit: healthKit, container: c)
        self._journey = State(initialValue: svc)
        let sleepSvc = SleepService(healthKit: healthKit, container: c)
        self._sleep = State(initialValue: sleepSvc)
        self._router = State(initialValue: AppRouter())

        Task { @MainActor [container = c] in
            SeedService.seedIfNeeded(
                context: container.mainContext,
                flagStore: UserDefaultsSeedFlagStore()
            )
        }
        Task { @MainActor in
            await svc.bootstrap()
        }
        Task { @MainActor in
            await sleepSvc.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(journey)
                .environment(sleep)
                .environment(router)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: `RootView` を AppRouter binding に変更する**

`WorkoutTracker/App/RootView.swift` を以下に置き換える:

```swift
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tag(AppRouter.Tab.home)
                .tabItem { Label("ホーム", systemImage: "house") }
            RecordingView()
                .tag(AppRouter.Tab.recording)
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
            MenuView()
                .tag(AppRouter.Tab.menu)
                .tabItem { Label("メニュー", systemImage: "list.bullet") }
            HistoryView()
                .tag(AppRouter.Tab.history)
                .tabItem { Label("履歴", systemImage: "chart.line.uptrend.xyaxis") }
            WalkView()
                .tag(AppRouter.Tab.walk)
                .tabItem { Label("旅", systemImage: "map") }
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
}
```

- [ ] **Step 3: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 4: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。HomeView/RecordingView の Preview で `AppRouter` を要求するエラーは Task 4 / Task 3 で解消する。本ステップでは本体ビルドが通れば良い。

> もし `RootView` の Preview / `HomeView` / `RecordingView` の `#Preview` でビルドが落ちる場合は、各 Preview の最後に `.environment(AppRouter())` を追加して回避する（後続 Task で正式に追加される）。

- [ ] **Step 5: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS（既存 + Task 1 で追加した AppRouterTests）。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/App/WorkoutTrackerApp.swift \
        WorkoutTracker/App/RootView.swift
git commit -m "$(cat <<'EOF'
✨ feat: AppRouter をアプリに注入し RootView のタブ選択を binding 化

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `RecordingView` で `pendingStart` を消費する

**Files:**
- Modify: `WorkoutTracker/Features/Recording/RecordingView.swift`

- [ ] **Step 1: `RecordingView` に AppRouter 連携を追加する**

`WorkoutTracker/Features/Recording/RecordingView.swift` を以下に置き換える:

```swift
import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(SleepService.self) private var sleep
    @Environment(AppRouter.self) private var router
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
            handlePendingStartIfNeeded()
        }
        .onChange(of: router.pendingStart) { _, _ in
            handlePendingStartIfNeeded()
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

    private func handlePendingStartIfNeeded() {
        guard vm.session == nil, let start = router.consumePendingStart() else { return }
        switch start {
        case .empty:
            vm.startEmptySession()
        case .template(let id):
            if let t = templates.first(where: { $0.id == id }) {
                vm.startSession(from: t)
            } else {
                vm.startEmptySession()
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
        .environment(AppRouter())
}
```

- [ ] **Step 2: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 3: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 4: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS（既存 + AppRouterTests）。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Recording/RecordingView.swift
git commit -m "$(cat <<'EOF'
✨ feat: RecordingView で AppRouter の pendingStart を消費してセッション開始

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `HomeView` に「ワークアウト開始」横スクロールを追加

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`

このタスクではセクション追加のみ行い、直近セッション差し替え（Task 5）とスパークライン追加（Task 6）は分離する。

- [ ] **Step 1: `HomeView` に AppRouter / templates / 進行中判定を追加する**

`WorkoutTracker/Features/Home/HomeView.swift` の `import` 直下〜`var body` の直前を以下のように変更する。

(a) 既存の `@Query` の上に AppRouter と templates クエリを追加。

```swift
struct HomeView: View {
    @Environment(JourneyService.self) private var journey
    @Environment(SleepService.self) private var sleep
    @Environment(AppRouter.self) private var router
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @AppStorage("sleep.targetHours") private var sleepTargetHours: Double = 7.0

    @Query(sort: [SortDescriptor(\WorkoutTemplate.order), SortDescriptor(\WorkoutTemplate.name)])
    private var templates: [WorkoutTemplate]

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    private var hasActiveSession: Bool {
        sessions.contains { $0.endedAt == nil }
    }
```

(b) `body` の `List { ... }` 内、最上部（`Section("今日の歩数")` の直前）に新セクションを挿入:

```swift
            List {
                Section("ワークアウト開始") {
                    workoutStartScroller
                }

                Section("今日の歩数") {
                    todayWalkCard
                }
                ...
            }
```

(c) 既存の `private var todayWalkCard: some View {` の上に以下を追加:

```swift
    private var workoutStartScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(templates) { t in
                    Button {
                        router.requestStart(template: t.id)
                    } label: {
                        templateCard(t)
                    }
                    .buttonStyle(.plain)
                    .disabled(hasActiveSession)
                    .opacity(hasActiveSession ? 0.4 : 1.0)
                }
                Button {
                    router.requestStartEmpty()
                } label: {
                    emptySessionCard
                }
                .buttonStyle(.plain)
                .disabled(hasActiveSession)
                .opacity(hasActiveSession ? 0.4 : 1.0)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
    }

    private func templateCard(_ t: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t.name)
                .font(.headline)
                .lineLimit(2)
            Spacer()
            Text("\(t.exercises.count) 種目")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 160, height: 96, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptySessionCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
            Text("空セッション")
                .font(.headline)
        }
        .frame(width: 160, height: 96)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
```

(d) Preview チェーンに `AppRouter` を追加:

```swift
#Preview {
    HomeView()
        .modelContainer(for: [
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self,
            StepDailyRecord.self, CheckpointAchievement.self,
            SleepDailyRecord.self,
            WorkoutTemplate.self, TemplateExercise.self
        ], inMemory: true)
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
        .environment(SleepService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
        .environment(AppRouter())
}
```

- [ ] **Step 2: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 3: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 4: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
✨ feat: ホーム画面にワークアウト開始セクション（横スクロール）を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `HomeView` の直近セッションを 3 件サマリに差し替え

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`

- [ ] **Step 1: 既存の「直近のセッション」セクションを 3 件版に差し替える**

`WorkoutTracker/Features/Home/HomeView.swift` を編集する。

(a) `body` の List 内、既存の以下のブロックを置き換える:

```swift
                if let last = sessions.first {
                    Section("直近のセッション") {
                        NavigationLink {
                            SessionDetailView(session: last)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(last.startedAt, style: .date).font(.headline)
                                Text("\(last.sets.count) セット")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
```

→ 以下に置換:

```swift
                if !recentCompletedSessions.isEmpty {
                    Section("直近 3 セッション") {
                        ForEach(recentCompletedSessions) { s in
                            NavigationLink {
                                SessionDetailView(session: s)
                            } label: {
                                sessionSummaryRow(s)
                            }
                        }
                    }
                }
```

(b) 既存の `private var weekSessions: [WorkoutSession] { ... }` の上に以下を追加:

```swift
    private var recentCompletedSessions: [WorkoutSession] {
        Array(sessions.lazy.filter { $0.endedAt != nil }.prefix(3))
    }

    private func sessionSummaryRow(_ s: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.startedAt, style: .date)
                .font(.headline)
            Text(sessionSummaryCaption(s))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sessionSummaryCaption(_ s: WorkoutSession) -> String {
        let exerciseCount = Set(s.sets.map { $0.exercise.id }).count
        let volume = WorkoutMetrics.totalVolume(
            sets: s.sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) }
        )
        return "\(exerciseCount) 種目 / 総ボリューム \(Int(volume.rounded())) kg"
    }
```

- [ ] **Step 2: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 3: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 4: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
✨ feat: ホームの直近セッションを 3 件サマリ（種目数 + 総ボリューム）に差し替え

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `HomeView` に体重 30 日スパークラインを追加

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`

- [ ] **Step 1: スパークラインセクションと派生プロパティを追加する**

`WorkoutTracker/Features/Home/HomeView.swift` を編集する。

(a) ファイル冒頭の `import SwiftUI` の直下に以下を追加:

```swift
import Charts
```

(b) `body` の List 内、既存の「最新の体組成」セクションの**直前**に新セクションを挿入:

```swift
                if !weightSparklinePoints.isEmpty {
                    Section("体重トレンド") {
                        weightSparklineView
                    }
                } else {
                    Section("体重トレンド") {
                        Text("データなし")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
```

(c) `private var weekSessions: [WorkoutSession] { ... }` の上に以下を追加（`recentCompletedSessions` 等の隣）:

```swift
    private struct WeightPoint: Identifiable {
        let id: Date
        let date: Date
        let weight: Double
    }

    private var weightSparklinePoints: [WeightPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -29, to: today) ?? today

        var byDay: [Date: BodyMetric] = [:]
        for m in metrics {
            guard let _ = m.weightKg else { continue }
            let day = cal.startOfDay(for: m.recordedAt)
            guard day >= from && day <= today else { continue }
            if let existing = byDay[day] {
                if existing.source == .manual { continue }
                if m.source == .manual { byDay[day] = m; continue }
                if m.recordedAt > existing.recordedAt { byDay[day] = m }
            } else {
                byDay[day] = m
            }
        }

        return byDay
            .compactMap { (day, metric) -> WeightPoint? in
                guard let w = metric.weightKg else { return nil }
                return WeightPoint(id: day, date: day, weight: w)
            }
            .sorted(by: { $0.date < $1.date })
    }

    @ViewBuilder
    private var weightSparklineView: some View {
        if weightSparklinePoints.count == 1, let only = weightSparklinePoints.first {
            HStack {
                Text(String(format: "%.1f kg", only.weight))
                    .font(.headline)
                Spacer()
                Text("（30 日中 1 件）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Chart {
                ForEach(weightSparklinePoints) { p in
                    LineMark(
                        x: .value("date", p.date),
                        y: .value("kg", p.weight)
                    )
                    AreaMark(
                        x: .value("date", p.date),
                        y: .value("kg", p.weight)
                    )
                    .foregroundStyle(.tint.opacity(0.15))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 36)
        }
    }
```

> 備考: `BodyMetric.source` が `.manual` のレコードを優先採用する規則は原典 spec §7.4 に基づく。同日に複数レコードがある場合は manual を優先、両方 healthKit なら `recordedAt` が新しい方を採用する。

- [ ] **Step 2: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 3: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 4: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
✨ feat: ホームに体重 30 日スパークラインセクションを追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 最終ビルド + シミュレータ目視確認

**Files:** なし（確認のみ）

- [ ] **Step 1: 最終ビルド**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 2: 全テスト実行**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。AppRouterTests の 4 件が含まれる。

- [ ] **Step 3: シミュレータでの目視確認**

シミュレータでアプリを起動し、以下を順番に確認:

1. ホームタブの最上部に「ワークアウト開始」セクションがあり、テンプレートカードが横スクロールで並び、末尾に「空セッション」カードがあること
2. テンプレカードをタップすると記録タブへ遷移し、ActiveSessionView が表示されること（テンプレ由来のセッション）
3. ホームに戻り「空セッション」カードをタップすると、記録タブで空セッションが開始されること
4. セッション中はホームのカードが半透明になり、タップしても遷移しないこと
5. セッションを終了して履歴に表示された後、ホームの「直近 3 セッション」に最新の完了セッションが表示され、「N 種目 / 総ボリューム X kg」が表示されること
6. ホームの「体重トレンド」セクションに、データがあればスパークライン、無ければ「データなし」が表示されること
7. 各タブ（ホーム / 記録 / メニュー / 履歴 / 旅）が引き続き正常に切替できること

確認のみで commit は不要。

---

## Self-Review

### Spec coverage チェック

| Spec セクション | 実装タスク |
|----------------|----------|
| §3 アーキテクチャ（AppRouter） | Task 1, 2 |
| §5 AppRouter 型定義 | Task 1 |
| §6.1 RootView 変更 | Task 2 |
| §6.2.1 workoutStartScroller | Task 4 |
| §6.2.2 recentSessionsList | Task 5 |
| §6.2.3 weightSparkline | Task 6 |
| §6.3 RecordingView 変更 | Task 3 |
| §6.4 WorkoutTrackerApp 変更 | Task 2 |
| §7 データフロー | Task 3, 4（フロー確認は Task 7） |
| §8 エラーハンドリング | Task 3（テンプレ削除 fallback） / Task 4（テンプレ 0 件・進行中時 disabled） / Task 6（体重 0/1 件 fallback） |
| §9.1 AppRouterTests 4 ケース | Task 1 |

ギャップなし。

### Placeholder スキャン

- "TBD" / "TODO" / "implement later" / "fill in details" → なし
- 「なぜ」のコメントが必要なところは spec §7.4 の体重 manual 優先規則を備考で説明済み（Task 6）
- 全コードブロックは完全実装

### Type 整合チェック

- `AppRouter.Tab` enum: Task 1 で定義 → Task 2 の `RootView` で `AppRouter.Tab.home` 等を参照 ✓
- `AppRouter.PendingStart`: Task 1 で定義 → Task 3 の `switch start` で `.empty` / `.template(let id)` を網羅 ✓
- `AppRouter.requestStart(template:)` / `requestStartEmpty()` / `consumePendingStart()`: Task 1 で定義 → Task 3, 4 で利用 ✓
- `WorkoutMetrics.totalVolume(sets:)` および `WorkoutMetrics.SetInput`: 既存（変更なし）→ Task 5 で利用 ✓
- `BodyMetric.source` の `.manual` / `.healthKit`: 既存 enum → Task 6 で参照 ✓
