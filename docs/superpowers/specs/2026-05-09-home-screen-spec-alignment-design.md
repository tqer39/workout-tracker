# ホーム画面仕様適合化 設計書

- 作成日: 2026-05-09
- ステータス: 実装計画待ち
- 関連 spec: `docs/superpowers/specs/2026-04-20-workout-tracker-ios-design.md`（§4.1 ホーム）
- 対象ブランチ: worktree `worktree-ccw-tqer39-workout-tracker-260509-002702`

## 1. 目的とスコープ

原典 spec `2026-04-20-workout-tracker-ios-design.md` §4.1 で要求されているホーム画面の機能のうち未実装の 3 項目を実装し、仕様との乖離を解消する。

### 未実装項目

| 項目 | 仕様 | 現状 |
|------|------|------|
| ワークアウト開始ボタン | テンプレート選択 or 空セッションをホームから即起動 | 記録タブ経由のみ |
| 直近 3 セッションサマリ | 直近 3 件（日付・種目数・総ボリューム） | 直近 1 件のみ・種目数/ボリューム表示なし |
| 体重トレンド | 直近 30 日のスパークライン | 最新 1 件の数値表示のみ |

### スコープ内

- `AppRouter`（タブ切替 + 記録開始ペンディング）の新規追加
- `HomeView` の改修（横スクロールの開始セクション、3 セッション表示、体重スパークライン）
- `RecordingView` でのペンディング消費ロジック
- `RootView` の `TabView` を selection binding 化
- 上記に伴う最小限のユニットテスト（`AppRouter`）

### スコープ外

- 進行中セッションがある状態の冷却起動からの復元（VM が DB ソースに依存していないため別テーマ）
- ダークモード調整・アクセシビリティ最終確認（既存 spec §11 マイルストーン 9、別タスク）
- 他タブの仕様乖離確認・修正
- 体組成の体脂肪率トレンド表示（仕様は体重のみ）

## 2. 前提と制約

- 対応 OS: iOS 18 以降（既存 spec と同じ）
- Swift / SwiftUI / SwiftData / Swift Charts / XCTest / XcodeGen / iOS 18+
- ライト/ダーク両対応（追加スタイルも双方で破綻しないよう既存パレット内で組む）
- 既存テスト（睡眠・歩数・筋トレ）はそのまま通る前提

## 3. アーキテクチャ

```
┌──────────────────────────────────────────────┐
│              SwiftUI Views                   │
│   TabView(selection: $router.selectedTab)    │
│     Home / Recording / Menu / History / Walk │
└───────────────┬──────────────────────────────┘
                │ @Environment(AppRouter.self)
                ▼
┌──────────────────────────────────────────────┐
│  AppRouter（@Observable・新規）              │
│   - selectedTab: Tab                         │
│   - pendingStart: PendingStart?              │
└──────────────────────────────────────────────┘
```

設計上のポイント:

- `AppRouter` はタブ間の疎結合な「意思の受け渡し」役。HomeView が「記録タブで X を開始してほしい」を `pendingStart` に書く → RecordingView が `.onChange` で消費する
- 既存の `JourneyService` / `SleepService` は変更しない
- `RecordingViewModel` の API（`startEmptySession()` / `startSession(from:)`）は変更せず、呼び出し元を増やすだけ

## 4. データモデル

**変更なし。** 既存の `WorkoutTemplate` / `WorkoutSession` / `SetRecord` / `BodyMetric` をそのまま使う。

## 5. 新規型: `AppRouter`

ファイル: `WorkoutTracker/App/AppRouter.swift`

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

`requestStart(...)` / `consumePendingStart()` をメソッドとして用意することで、HomeView/RecordingView は内部表現に依存せず、テストしやすい。

## 6. 画面構成

### 6.1 RootView 変更

```swift
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
```

### 6.2 HomeView 改修

セクション構成（既存セクションは保持、★ が追加・差し替え）:

```
List {
    Section("ワークアウト開始") { workoutStartScroller }      ★新規
    Section("今日の歩数")       { todayWalkCard }              既存
    Section("昨夜の睡眠")       { lastNightSleepCard }         既存
    Section("今週のサマリ")     { weekSummary }                既存
    Section("直近 3 セッション") { recentSessionsList }         ★差し替え
    Section("体重トレンド")     { weightSparkline }            ★新規
    Section("最新の体組成")     { latestBodyMetric }           既存
}
```

#### 6.2.1 workoutStartScroller

- `ScrollView(.horizontal, showsIndicators: false)` + `LazyHStack(spacing: 12)`
- `WorkoutTemplate` を `@Query(sort: [SortDescriptor(\.order), SortDescriptor(\.name)])` で取得
- 左から各テンプレートを「テンプレートカード」、末尾に「空セッションカード」を 1 枚
- カードサイズ: `width: 160, height: 96`
- カード内容:
  - **テンプレートカード**: 上部に `t.name`（headline、2 行まで）、下部に `"\(t.exercises.count) 種目"`
  - **空セッションカード**: `Image(systemName: "plus.circle.fill")` + `Text("空セッション")`
- 背景: `.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))`
- タップ動作:
  - テンプレートカード: `router.requestStart(template: t.id)`
  - 空セッションカード: `router.requestStartEmpty()`
- 進行中セッションありの場合は両カードとも `.disabled(true)` + 透明度を下げる
  - 判定: `sessions.contains { $0.endedAt == nil }`（既存 `sessions` クエリを流用）
- テンプレート 0 件のときは「空セッション」カード 1 枚のみ表示

#### 6.2.2 recentSessionsList

既存の `sessions` クエリ（全セッション降順）から in-memory で完了済セッションだけ抽出する派生プロパティを追加し、新規 `@Query` は追加しない:

```swift
private var recentCompletedSessions: [WorkoutSession] {
    Array(sessions.lazy.filter { $0.endedAt != nil }.prefix(3))
}
```

- 表示は `recentCompletedSessions` を `ForEach`
- 各行 `NavigationLink { SessionDetailView(session: s) }`:

```
[日付]              <chevron>
3 種目 / 総ボリューム 4,250 kg
```

- 日付: `s.startedAt`、`headline`
- サブテキスト: 「\(uniqueExerciseCount(s)) 種目 / 総ボリューム \(Int(volume(s).rounded())) kg」、`caption / .secondary`
- `uniqueExerciseCount`: `Set(s.sets.map(\.exercise.id)).count`
- `volume`: `WorkoutMetrics.totalVolume(sets: s.sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) })`
- `recentCompletedSessions` が空なら Section ごと非表示

進行中セッション（`endedAt == nil`）はこのリストから除外する（履歴ではなく未完了であるため）。

#### 6.2.3 weightSparkline

- 取得: 既存の `metrics` クエリ（`@Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])`）を流用
- 直近 30 日に絞り、暦日ごとに `manual` 優先で 1 件選び、`weightKg != nil` のものだけ採用
- データ点を `recordedAt` 昇順にソート
- レンダリング:

```swift
Chart {
    ForEach(points) { p in
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
```

- ポイントが 0 件: `Text("データなし").font(.caption).foregroundStyle(.secondary)`
- ポイントが 1 件: 1 点のみで `LineMark` は描けないため、その値を Text で表示（fallback）

### 6.3 RecordingView 変更

- `@Environment(AppRouter.self) private var router` を追加
- `body` 末尾に `.onChange(of: router.pendingStart) { _, new in ... }` を付け、新値が非 nil なら `consumePendingStart()` で取り出して処理:

```swift
.onChange(of: router.pendingStart) { _, _ in
    handlePendingStartIfNeeded()
}
.onAppear {
    vm.bind(context: ctx)
    Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
    handlePendingStartIfNeeded()
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
```

- 既存の `startView`（記録タブを直接開いたユーザー向けの開始 UI）はそのまま残す
- `vm.session != nil`（進行中）の状態で `pendingStart` が来た場合は無視する（UI 側で disabled しているが二重防御）

### 6.4 WorkoutTrackerApp 変更

- `let router = AppRouter()` を生成
- `RootView()` チェーンに `.environment(router)` を追加（既存の `journey` / `sleep` と並列）

## 7. データフロー

### 7.1 ホームからのワークアウト開始

```
[Home] ScrollView 内のテンプレ/空セッションカードをタップ
  ↓
router.requestStart(template:) または requestStartEmpty()
  ↓ (selectedTab → .recording)
[Recording] .onChange(of: router.pendingStart) または .onAppear
  ↓ consumePendingStart() で取り出して
  ↓ vm.startEmptySession() / vm.startSession(from:)
[Recording] vm.session に新しい WorkoutSession が乗り、ActiveSessionView 表示
```

### 7.2 直近 3 セッション / 体重スパークライン

純粋に `@Query` のフィルタリング。書き込み副作用なし。

## 8. エラーハンドリング

| ケース | 扱い |
|---|---|
| `pendingStart.template(id)` 指定のテンプレが既に削除されている | `templates.first(where:)` が nil → `startEmptySession()` にフォールバック |
| `pendingStart` 受信時に既に進行中セッションあり | `consumePendingStart()` を呼ばずに無視（HomeView 側 disabled で先に防ぐ） |
| `BodyMetric` 0 件 | スパークラインセクションは「データなし」テキスト |
| `BodyMetric` 1 件のみ | 1 点では LineMark が描けないため、その値の Text 表示にフォールバック |
| `WorkoutTemplate` 0 件 | スクローラには「空セッション」カードのみ表示 |
| 完了済セッション 0 件 | 「直近 3 セッション」セクションを非表示 |

## 9. テスト戦略

### 9.1 新規テスト

`WorkoutTrackerTests/AppRouterTests.swift`:

- `test_initial_state`: `selectedTab == .home`、`pendingStart == nil`
- `test_requestStart_template_sets_pending_and_switches_tab`: `requestStart(template: id)` 後に `pendingStart == .template(id)` かつ `selectedTab == .recording`
- `test_consumePendingStart_returns_value_and_clears`: 一度 `requestStart` した後 `consumePendingStart()` が値を返し、再度呼ぶと nil
- `test_consumePendingStart_when_nil_returns_nil`: 初期状態の `consumePendingStart()` は nil を返す

### 9.2 既存テスト

- すべてそのまま通る前提（モデル変更なし）。変更があった `RootView` / `HomeView` / `RecordingView` はテスト対象外（Preview による目視確認）

### 9.3 UI / 統合

SwiftUI Preview で以下の状態を確認:

- HomeView: テンプレ 0 / 1 / 3 件、進行中セッションあり/なし、体組成 0 / 1 / 30 件
- RecordingView: `pendingStart` 注入時に正しく ActiveSessionView へ遷移
- RootView: タブ間の遷移が `selectedTab` の変更で起きること

XCUITest は MVP 外のまま。

## 10. ディレクトリ構成（差分）

```
WorkoutTracker/
  App/
    AppRouter.swift              ★新規
    WorkoutTrackerApp.swift      AppRouter 注入
    RootView.swift               TabView selection binding
  Features/
    Home/
      HomeView.swift             改修
    Recording/
      RecordingView.swift        pendingStart 消費
WorkoutTrackerTests/
  AppRouterTests.swift           ★新規
```

## 11. 実装マイルストーン

1. `AppRouter` を新規作成 + `AppRouterTests` 4 ケース
2. `WorkoutTrackerApp` で `AppRouter` を生成・注入、`RootView` を selection binding 化
3. `RecordingView` に `pendingStart` 消費ロジックを追加（既存 `startView` は残す）
4. `HomeView` に「ワークアウト開始」横スクロールセクションを追加（テンプレ + 空セッション、進行中時 disabled）
5. `HomeView` の「直近のセッション」を `prefix(3)`・種目数・総ボリューム表示に差し替え
6. `HomeView` に体重スパークラインセクションを追加（30 日、manual 優先、データなし fallback）
7. ビルド + 全テスト + シミュレータ目視確認

## 12. 用語

- **AppRouter**: タブ間の遷移意思を保持する `@Observable` 型
- **PendingStart**: 「次に記録タブが起こすべきセッション開始の意思」
- **スパークライン**: 軸ラベルなしの小さな折れ線/エリアグラフ
- **進行中セッション**: `endedAt == nil` の `WorkoutSession`
