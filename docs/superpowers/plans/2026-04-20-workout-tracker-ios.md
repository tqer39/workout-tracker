# 筋トレ記録 iOS アプリ 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SwiftUI + SwiftData による個人用の iOS 筋トレ記録アプリを、MVP 機能（種目/テンプレート登録・セッション記録・休憩タイマー・履歴グラフ・HealthKit 連携）まで実装する。

**Architecture:** SwiftUI + SwiftData + MV パターン。単純な一覧は View から `@Query` 直読み、複数モデルにまたがるロジックは `@Observable` ViewModel に集約。サービス層（HealthKit/通知/タイマー）はプロトコル化してテスト可能にする。

**Tech Stack:** Swift 5.10+, SwiftUI (iOS 18+), SwiftData, Swift Charts, HealthKit, UserNotifications, XCTest, XcodeGen（プロジェクト定義を YAML で管理）。

**Spec:** `docs/superpowers/specs/2026-04-20-workout-tracker-ios-design.md`

---

## ファイル構成

生成後のトップレベル:

```
.tool-versions
.gitignore
project.yml                           # XcodeGen 設定
WorkoutTracker.xcodeproj              # 生成物（gitignore）
WorkoutTracker/
  App/
    WorkoutTrackerApp.swift
    RootView.swift
  Features/
    Home/HomeView.swift
    Recording/
      RecordingView.swift
      ActiveSessionView.swift
      SetInputRow.swift
      RestTimerView.swift
      RecordingViewModel.swift
    Menu/
      MenuView.swift
      Exercises/ExercisesListView.swift, ExerciseFormView.swift
      Templates/TemplatesListView.swift, TemplateEditorView.swift
    History/
      HistoryView.swift
      SessionDetailView.swift
      ExerciseChartsView.swift
      BodyCompositionView.swift
  Models/
    Enums.swift
    Exercise.swift
    WorkoutTemplate.swift
    TemplateExercise.swift
    WorkoutSession.swift
    SetRecord.swift
    BodyMetric.swift
    ModelContainerFactory.swift
  Services/
    HealthKitService.swift
    NotificationService.swift
    RestTimer.swift
    SeedService.swift
  Domain/
    WorkoutMetrics.swift
  Resources/
    Assets.xcassets
    Info.plist
WorkoutTrackerTests/
  TestHelpers/InMemoryContainer.swift
  ModelsTests/
    ExerciseTests.swift
    WorkoutSessionTests.swift
    BodyMetricTests.swift
  DomainTests/
    WorkoutMetricsTests.swift
  ServicesTests/
    RestTimerTests.swift
    SeedServiceTests.swift
    HealthKitServiceTests.swift
```

責務分割の原則: 1 ファイル = 1 責務。View と ViewModel は同じ Feature ディレクトリにまとめる。Domain（純粋ロジック）は UI/永続化から独立させテストしやすくする。

---

## 前提コマンド

ビルドとテストで使う共通コマンドを先に固定する:

```bash
# ビルド
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build

# テスト
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test

# プロジェクト再生成（project.yml を編集したら必ず実行）
xcodegen generate
```

シミュレータ `iPhone 16` は Xcode 16 に同梱。無ければ `xcrun simctl list devices available` で存在する名前に置換する。

---

## Task 1: プロジェクトスキャフォールド

**Files:**
- Create: `.tool-versions`
- Create: `project.yml`
- Create: `WorkoutTracker/Resources/Info.plist`
- Create: `WorkoutTracker/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `WorkoutTracker/Resources/Assets.xcassets/Contents.json`
- Modify: `.gitignore`

- [ ] **Step 1: `.tool-versions` を作成**

```
xcodegen 2.43.0
```

- [ ] **Step 2: `.gitignore` に Xcode / XcodeGen 用エントリを追記**

既存の `.gitignore` に以下を追加:

```
# Xcode
*.xcodeproj
DerivedData/
build/
*.xcuserstate
xcuserdata/
.swiftpm/

# XcodeGen
*.generated.yml
```

- [ ] **Step 3: `project.yml` を作成**

```yaml
name: WorkoutTracker
options:
  bundleIdPrefix: com.tqer39
  deploymentTarget:
    iOS: "18.0"
  developmentLanguage: ja
settings:
  base:
    SWIFT_VERSION: "5.10"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    TARGETED_DEVICE_FAMILY: "1"  # iPhone only
    CODE_SIGN_STYLE: Automatic
targets:
  WorkoutTracker:
    type: application
    platform: iOS
    sources:
      - path: WorkoutTracker
    resources:
      - path: WorkoutTracker/Resources/Assets.xcassets
    info:
      path: WorkoutTracker/Resources/Info.plist
      properties:
        CFBundleDisplayName: 筋トレ記録
        UILaunchScreen: {}
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
        NSHealthShareUsageDescription: 体重・体脂肪率の推移をアプリに取り込みます。
        NSHealthUpdateUsageDescription: 体重・体脂肪率をヘルスケアへ保存します。
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tqer39.WorkoutTracker
  WorkoutTrackerTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: WorkoutTrackerTests
    dependencies:
      - target: WorkoutTracker
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tqer39.WorkoutTrackerTests
schemes:
  WorkoutTracker:
    build:
      targets:
        WorkoutTracker: all
        WorkoutTrackerTests: [test]
    test:
      targets:
        - WorkoutTrackerTests
```

- [ ] **Step 4: 最小 `Info.plist` を作成**

`WorkoutTracker/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

（残りのキーは `project.yml` 側で注入される）

- [ ] **Step 5: Assets カタログを作成**

`WorkoutTracker/Resources/Assets.xcassets/Contents.json`:

```json
{ "info": { "author": "xcode", "version": 1 } }
```

`WorkoutTracker/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images": [
    { "idiom": "universal", "platform": "ios", "size": "1024x1024" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 6: 仮のエントリポイントを置いて xcodegen がビルド可能な状態にする**

`WorkoutTracker/App/WorkoutTrackerApp.swift`:

```swift
import SwiftUI

@main
struct WorkoutTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("筋トレ記録")
        }
    }
}
```

`WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`（空のプレースホルダ、後で中身を書く）:

```swift
import Foundation
```

- [ ] **Step 7: XcodeGen を実行**

```bash
mise install
xcodegen generate
```

期待: `WorkoutTracker.xcodeproj/` が生成される。

- [ ] **Step 8: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

期待: `BUILD SUCCEEDED`

- [ ] **Step 9: コミット**

```bash
git add .tool-versions .gitignore project.yml WorkoutTracker/
git commit -m "🎉 feat: iOS プロジェクトをスキャフォールド"
```

---

## Task 2: ルート TabView スケルトン

**Files:**
- Create: `WorkoutTracker/App/RootView.swift`
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`
- Create: `WorkoutTracker/Features/Home/HomeView.swift`
- Create: `WorkoutTracker/Features/Recording/RecordingView.swift`
- Create: `WorkoutTracker/Features/Menu/MenuView.swift`
- Create: `WorkoutTracker/Features/History/HistoryView.swift`

- [ ] **Step 1: 各タブの空 View を作成**

`WorkoutTracker/Features/Home/HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("ホーム")
                .navigationTitle("ホーム")
        }
    }
}

#Preview { HomeView() }
```

同様に `RecordingView.swift`, `MenuView.swift`, `HistoryView.swift` も作る（タイトルはそれぞれ「記録」「メニュー」「履歴」）。

- [ ] **Step 2: `RootView` を作成**

`WorkoutTracker/App/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            RecordingView()
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
            MenuView()
                .tabItem { Label("メニュー", systemImage: "list.bullet") }
            HistoryView()
                .tabItem { Label("履歴", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

#Preview { RootView() }
```

- [ ] **Step 3: App のルートを差し替え**

`WorkoutTracker/App/WorkoutTrackerApp.swift`:

```swift
import SwiftUI

@main
struct WorkoutTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 4: 再生成とビルド**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

期待: `BUILD SUCCEEDED`

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/
git commit -m "✨ feat: ルート TabView と 4 タブの空 View を追加"
```

---

## Task 3: ドメイン用 Enum とテスト基盤

**Files:**
- Create: `WorkoutTracker/Models/Enums.swift`
- Modify: `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`

- [ ] **Step 1: Enum 定義を書く**

`WorkoutTracker/Models/Enums.swift`:

```swift
import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case chest = "胸"
    case back = "背"
    case legs = "脚"
    case shoulders = "肩"
    case arms = "腕"
    case core = "体幹"
    case other = "その他"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum BodyMetricSource: String, Codable {
    case healthKit
    case manual
}
```

- [ ] **Step 2: in-memory ModelContainer ヘルパーを書く**

`WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`:

```swift
import Foundation
import SwiftData
@testable import WorkoutTracker

enum InMemoryContainer {
    @MainActor
    static func make() throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

（まだ `Exercise` 等が存在しないため、このファイルだけではビルドが通らない。次タスクでモデルを定義して完成させる）

- [ ] **Step 3: ビルドは通さずコミットだけは避け、Task 4 へ続ける**

この時点では commit しない（次タスクで合わせてコミット）。

---

## Task 4: SwiftData モデル定義（Exercise）

**Files:**
- Create: `WorkoutTracker/Models/Exercise.swift`
- Create: `WorkoutTrackerTests/ModelsTests/ExerciseTests.swift`

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/ModelsTests/ExerciseTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

final class ExerciseTests: XCTestCase {
    @MainActor
    func test_create_and_fetch_exercise() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let ex = Exercise(name: "ベンチプレス", category: .chest, defaultRestSeconds: 90)
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "ベンチプレス")
        XCTAssertEqual(fetched.first?.category, .chest)
        XCTAssertEqual(fetched.first?.defaultRestSeconds, 90)
        XCTAssertFalse(fetched.first?.isHidden ?? true)
    }
}
```

- [ ] **Step 2: テストを走らせて失敗を確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: `Exercise` 型が未定義でコンパイルエラー。

- [ ] **Step 3: `Exercise` モデルを実装**

`WorkoutTracker/Models/Exercise.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var defaultWeightKg: Double?
    var defaultRestSeconds: Int
    var notes: String?
    var isHidden: Bool

    @Relationship(deleteRule: .nullify, inverse: \SetRecord.exercise)
    var setRecords: [SetRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.exercise)
    var templateExercises: [TemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        defaultWeightKg: Double? = nil,
        defaultRestSeconds: Int = 90,
        notes: String? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.defaultWeightKg = defaultWeightKg
        self.defaultRestSeconds = defaultRestSeconds
        self.notes = notes
        self.isHidden = isHidden
    }
}
```

- [ ] **Step 4: テストを走らせてパスを確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: `SetRecord` と `TemplateExercise` が未定義でコンパイルエラー。次タスクで追加する。ここでは失敗を許容する。

- [ ] **Step 5: コミットはせず Task 5 へ続ける**

---

## Task 5: SwiftData モデル定義（残り）

**Files:**
- Create: `WorkoutTracker/Models/WorkoutTemplate.swift`
- Create: `WorkoutTracker/Models/TemplateExercise.swift`
- Create: `WorkoutTracker/Models/WorkoutSession.swift`
- Create: `WorkoutTracker/Models/SetRecord.swift`
- Create: `WorkoutTracker/Models/BodyMetric.swift`

- [ ] **Step 1: `WorkoutTemplate.swift`**

```swift
import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var order: Int

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    init(id: UUID = UUID(), name: String, order: Int = 0) {
        self.id = id
        self.name = name
        self.order = order
    }
}
```

- [ ] **Step 2: `TemplateExercise.swift`**

```swift
import Foundation
import SwiftData

@Model
final class TemplateExercise {
    var id: UUID
    var order: Int
    var exercise: Exercise?
    var template: WorkoutTemplate?
    var targetSets: Int
    var targetReps: Int
    var targetWeightKg: Double?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        exercise: Exercise,
        targetSets: Int,
        targetReps: Int,
        targetWeightKg: Double? = nil
    ) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightKg = targetWeightKg
    }
}
```

- [ ] **Step 3: `WorkoutSession.swift`**

```swift
import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var templateRef: WorkoutTemplate?
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.session)
    var sets: [SetRecord] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        templateRef: WorkoutTemplate? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.templateRef = templateRef
        self.notes = notes
    }
}
```

- [ ] **Step 4: `SetRecord.swift`**

```swift
import Foundation
import SwiftData

@Model
final class SetRecord {
    var id: UUID
    var exercise: Exercise?
    var session: WorkoutSession?
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var performedAt: Date
    var restSeconds: Int?

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        session: WorkoutSession? = nil,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        performedAt: Date = Date(),
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.session = session
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.performedAt = performedAt
        self.restSeconds = restSeconds
    }
}
```

- [ ] **Step 5: `BodyMetric.swift`**

```swift
import Foundation
import SwiftData

@Model
final class BodyMetric {
    var id: UUID
    var recordedAt: Date
    var weightKg: Double?
    var bodyFatPercent: Double?
    var source: BodyMetricSource

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        weightKg: Double? = nil,
        bodyFatPercent: Double? = nil,
        source: BodyMetricSource
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.source = source
    }
}
```

- [ ] **Step 6: テストを走らせて Task 4 のテストがパスすることを確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: `ExerciseTests` が PASS。

- [ ] **Step 7: コミット**

```bash
git add WorkoutTracker/Models WorkoutTrackerTests/
git commit -m "✨ feat: SwiftData モデルとテスト基盤を追加"
```

---

## Task 6: リレーション動作テスト

**Files:**
- Create: `WorkoutTrackerTests/ModelsTests/WorkoutSessionTests.swift`
- Create: `WorkoutTrackerTests/ModelsTests/BodyMetricTests.swift`

- [ ] **Step 1: セッションとセットのカスケード削除テストを書く**

`WorkoutTrackerTests/ModelsTests/WorkoutSessionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

final class WorkoutSessionTests: XCTestCase {
    @MainActor
    func test_session_cascade_deletes_sets() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let ex = Exercise(name: "スクワット", category: .legs)
        let session = WorkoutSession()
        let set = SetRecord(exercise: ex, session: session, weightKg: 100, reps: 5)
        ctx.insert(ex)
        ctx.insert(session)
        ctx.insert(set)
        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SetRecord>()).count, 1)
        ctx.delete(session)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SetRecord>()).count, 0)
    }

    @MainActor
    func test_template_cascade_deletes_template_exercises() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let ex = Exercise(name: "デッドリフト", category: .back)
        let tpl = WorkoutTemplate(name: "背中の日")
        let te = TemplateExercise(exercise: ex, targetSets: 3, targetReps: 5)
        te.template = tpl
        ctx.insert(ex); ctx.insert(tpl); ctx.insert(te)
        try ctx.save()

        ctx.delete(tpl)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<TemplateExercise>()).count, 0)
    }
}
```

- [ ] **Step 2: `BodyMetric` の基本テスト**

`WorkoutTrackerTests/ModelsTests/BodyMetricTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

final class BodyMetricTests: XCTestCase {
    @MainActor
    func test_body_metric_sources() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        ctx.insert(BodyMetric(recordedAt: Date(), weightKg: 70.0, source: .manual))
        ctx.insert(BodyMetric(recordedAt: Date(), weightKg: 70.2, source: .healthKit))
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<BodyMetric>())
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.source)), [.manual, .healthKit])
    }
}
```

- [ ] **Step 3: テスト実行**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: 全テスト PASS。

- [ ] **Step 4: コミット**

```bash
git add WorkoutTrackerTests/
git commit -m "🧪 test: モデルのリレーションとカスケード削除テストを追加"
```

---

## Task 7: ModelContainer セットアップとアプリ注入

**Files:**
- Create: `WorkoutTracker/Models/ModelContainerFactory.swift`
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`

- [ ] **Step 1: ファクトリを作成**

`WorkoutTracker/Models/ModelContainerFactory.swift`:

```swift
import Foundation
import SwiftData

enum ModelContainerFactory {
    @MainActor
    static func makeShared() -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer の作成に失敗: \(error)")
        }
    }
}
```

- [ ] **Step 2: App に注入**

`WorkoutTracker/App/WorkoutTrackerApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer

    init() {
        self.container = ModelContainerFactory.makeShared()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 3: ビルド確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/
git commit -m "✨ feat: ModelContainer を App に注入"
```

---

## Task 8: シードサービス

**Files:**
- Create: `WorkoutTracker/Services/SeedService.swift`
- Create: `WorkoutTrackerTests/ServicesTests/SeedServiceTests.swift`
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/ServicesTests/SeedServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

final class SeedServiceTests: XCTestCase {
    @MainActor
    func test_seed_is_idempotent() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        SeedService.seedIfNeeded(context: ctx, flagStore: InMemoryFlagStore())
        let firstCount = try ctx.fetch(FetchDescriptor<Exercise>()).count
        XCTAssertGreaterThan(firstCount, 0)

        SeedService.seedIfNeeded(context: ctx, flagStore: InMemoryFlagStore(initial: true))
        let secondCount = try ctx.fetch(FetchDescriptor<Exercise>()).count
        XCTAssertEqual(secondCount, firstCount, "既にシード済みなら重複挿入しない")
    }

    @MainActor
    func test_seed_contains_big3() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        SeedService.seedIfNeeded(context: ctx, flagStore: InMemoryFlagStore())
        let names = Set(try ctx.fetch(FetchDescriptor<Exercise>()).map(\.name))
        XCTAssertTrue(names.contains("ベンチプレス"))
        XCTAssertTrue(names.contains("スクワット"))
        XCTAssertTrue(names.contains("デッドリフト"))
    }
}

final class InMemoryFlagStore: SeedFlagStore {
    private var flag: Bool
    init(initial: Bool = false) { self.flag = initial }
    var didSeed: Bool {
        get { flag }
        set { flag = newValue }
    }
}
```

- [ ] **Step 2: テストを走らせて失敗を確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: `SeedService`, `SeedFlagStore` 未定義でコンパイルエラー。

- [ ] **Step 3: シード実装**

`WorkoutTracker/Services/SeedService.swift`:

```swift
import Foundation
import SwiftData

protocol SeedFlagStore: AnyObject {
    var didSeed: Bool { get set }
}

final class UserDefaultsSeedFlagStore: SeedFlagStore {
    private let key = "didSeedInitialData"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var didSeed: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

enum SeedService {
    struct Preset {
        let name: String
        let category: ExerciseCategory
    }

    static let presets: [Preset] = [
        .init(name: "ベンチプレス", category: .chest),
        .init(name: "スクワット", category: .legs),
        .init(name: "デッドリフト", category: .back),
        .init(name: "オーバーヘッドプレス", category: .shoulders),
        .init(name: "懸垂", category: .back),
        .init(name: "ラットプルダウン", category: .back),
        .init(name: "ベントオーバーロウ", category: .back),
        .init(name: "ダンベルカール", category: .arms),
        .init(name: "レッグプレス", category: .legs),
        .init(name: "レッグカール", category: .legs),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext, flagStore: SeedFlagStore) {
        guard !flagStore.didSeed else { return }
        for p in presets {
            context.insert(Exercise(name: p.name, category: p.category))
        }
        do {
            try context.save()
            flagStore.didSeed = true
        } catch {
            assertionFailure("seed 保存失敗: \(error)")
        }
    }
}
```

- [ ] **Step 4: テスト PASS を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- [ ] **Step 5: App 起動時にシードを呼ぶ**

`WorkoutTracker/App/WorkoutTrackerApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer

    init() {
        self.container = ModelContainerFactory.makeShared()
        Task { @MainActor in
            SeedService.seedIfNeeded(
                context: container.mainContext,
                flagStore: UserDefaultsSeedFlagStore()
            )
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
        .modelContainer(container)
    }
}
```

- [ ] **Step 6: ビルド + コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/ WorkoutTrackerTests/
git commit -m "✨ feat: 種目プリセットの初回シード"
```

---

## Task 9: ドメインロジック（総ボリュームと推定 1RM）

**Files:**
- Create: `WorkoutTracker/Domain/WorkoutMetrics.swift`
- Create: `WorkoutTrackerTests/DomainTests/WorkoutMetricsTests.swift`

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/DomainTests/WorkoutMetricsTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class WorkoutMetricsTests: XCTestCase {
    func test_totalVolume() {
        let volume = WorkoutMetrics.totalVolume(sets: [
            .init(weightKg: 80, reps: 10),
            .init(weightKg: 80, reps: 8),
            .init(weightKg: 60, reps: 12),
        ])
        XCTAssertEqual(volume, 80*10 + 80*8 + 60*12, accuracy: 0.001)
    }

    func test_epley_1rm_1rep_returns_weight() {
        XCTAssertEqual(WorkoutMetrics.epley1RM(weightKg: 100, reps: 1), 100, accuracy: 0.001)
    }

    func test_epley_1rm_formula() {
        // 80kg × 10 reps → 80 * (1 + 10/30) = 106.666...
        XCTAssertEqual(WorkoutMetrics.epley1RM(weightKg: 80, reps: 10), 80 * (1 + 10.0/30.0), accuracy: 0.001)
    }

    func test_epley_rejects_zero_reps() {
        XCTAssertNil(WorkoutMetrics.epley1RM(weightKg: 80, reps: 0))
    }
}
```

- [ ] **Step 2: 実行して失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: `WorkoutMetrics` 未定義。

- [ ] **Step 3: 実装**

`WorkoutTracker/Domain/WorkoutMetrics.swift`:

```swift
import Foundation

enum WorkoutMetrics {
    struct SetInput {
        let weightKg: Double
        let reps: Int
    }

    static func totalVolume(sets: [SetInput]) -> Double {
        sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    /// Epley 式: weight × (1 + reps / 30)
    /// reps が 0 以下の場合は nil を返す。
    static func epley1RM(weightKg: Double, reps: Int) -> Double? {
        guard reps > 0 else { return nil }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }
}
```

- [ ] **Step 4: テスト PASS**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Domain WorkoutTrackerTests/DomainTests
git commit -m "✨ feat: 総ボリュームと推定 1RM（Epley）を追加"
```

---

## Task 10: メニュー画面 — 種目一覧 + 追加/編集

**Files:**
- Modify: `WorkoutTracker/Features/Menu/MenuView.swift`
- Create: `WorkoutTracker/Features/Menu/Exercises/ExercisesListView.swift`
- Create: `WorkoutTracker/Features/Menu/Exercises/ExerciseFormView.swift`

- [ ] **Step 1: 種目一覧 View**

`WorkoutTracker/Features/Menu/Exercises/ExercisesListView.swift`:

```swift
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
                    Button("非表示", role: .destructive) { ex.isHidden = true }
                }
            }
        }
        .navigationTitle("種目")
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
```

- [ ] **Step 2: 追加/編集フォーム**

`WorkoutTracker/Features/Menu/Exercises/ExerciseFormView.swift`:

```swift
import SwiftUI
import SwiftData

struct ExerciseFormView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?

    @State private var name: String = ""
    @State private var category: ExerciseCategory = .chest
    @State private var defaultRestSeconds: Int = 90
    @State private var defaultWeightKgText: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("種目名", text: $name)
                Picker("カテゴリ", selection: $category) {
                    ForEach(ExerciseCategory.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                Stepper("休憩 \(defaultRestSeconds) 秒", value: $defaultRestSeconds, in: 30...600, step: 15)
                TextField("既定の重量 (kg) 任意", text: $defaultWeightKgText)
                    .keyboardType(.decimalPad)
                TextField("メモ", text: $notes, axis: .vertical)
            }
            .navigationTitle(exercise == nil ? "種目を追加" : "種目を編集")
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
        defaultRestSeconds = ex.defaultRestSeconds
        defaultWeightKgText = ex.defaultWeightKg.map { String($0) } ?? ""
        notes = ex.notes ?? ""
    }

    private func save() {
        let weight = Double(defaultWeightKgText)
        if let ex = exercise {
            ex.name = name
            ex.category = category
            ex.defaultRestSeconds = defaultRestSeconds
            ex.defaultWeightKg = weight
            ex.notes = notes.isEmpty ? nil : notes
        } else {
            ctx.insert(Exercise(
                name: name, category: category,
                defaultWeightKg: weight,
                defaultRestSeconds: defaultRestSeconds,
                notes: notes.isEmpty ? nil : notes
            ))
        }
        try? ctx.save()
        dismiss()
    }
}
```

- [ ] **Step 3: `MenuView` から種目タブへ遷移**

`WorkoutTracker/Features/Menu/MenuView.swift`:

```swift
import SwiftUI

struct MenuView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case exercises = "種目"
        case templates = "テンプレート"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .exercises

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch segment {
                case .exercises:
                    ExercisesListView()
                case .templates:
                    TemplatesListView()
                }
            }
            .navigationTitle("メニュー")
        }
    }
}
```

（`TemplatesListView` は次タスクで作るため、一旦プレースホルダを置く）

- [ ] **Step 4: 仮の `TemplatesListView` を置く**

`WorkoutTracker/Features/Menu/Templates/TemplatesListView.swift`:

```swift
import SwiftUI

struct TemplatesListView: View {
    var body: some View { Text("（テンプレートは次タスクで実装）") }
}
```

- [ ] **Step 5: ビルド & コミット**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/
git commit -m "✨ feat: 種目の一覧と追加・編集フォーム"
```

---

## Task 11: メニュー画面 — テンプレート CRUD

**Files:**
- Modify: `WorkoutTracker/Features/Menu/Templates/TemplatesListView.swift`
- Create: `WorkoutTracker/Features/Menu/Templates/TemplateEditorView.swift`

- [ ] **Step 1: テンプレート一覧**

`WorkoutTracker/Features/Menu/Templates/TemplatesListView.swift`:

```swift
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
            ForEach(templates) { tpl in
                Button { editing = tpl } label: {
                    VStack(alignment: .leading) {
                        Text(tpl.name).font(.headline)
                        Text("\(tpl.exercises.count) 種目")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("削除", role: .destructive) {
                        ctx.delete(tpl); try? ctx.save()
                    }
                }
            }
        }
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) {
            TemplateEditorView(template: nil)
        }
        .sheet(item: $editing) { tpl in
            TemplateEditorView(template: tpl)
        }
    }
}
```

- [ ] **Step 2: テンプレート編集画面**

`WorkoutTracker/Features/Menu/Templates/TemplateEditorView.swift`:

```swift
import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate?

    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var name: String = ""
    @State private var items: [Item] = []
    @State private var pickingExercise = false

    struct Item: Identifiable, Hashable {
        let id = UUID()
        var exercise: Exercise
        var targetSets: Int = 3
        var targetReps: Int = 10
        var targetWeightKgText: String = ""
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("テンプレート名", text: $name)

                Section("種目") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading) {
                            Text(item.exercise.name).font(.headline)
                            HStack {
                                Stepper("\(item.targetSets) セット", value: $item.targetSets, in: 1...20)
                            }
                            HStack {
                                Stepper("\(item.targetReps) reps", value: $item.targetReps, in: 1...50)
                            }
                            TextField("目標重量 (kg) 任意", text: $item.targetWeightKgText)
                                .keyboardType(.decimalPad)
                        }
                    }
                    .onDelete { idx in items.remove(atOffsets: idx) }
                    .onMove { s, d in items.move(fromOffsets: s, toOffset: d) }

                    Button("種目を追加") { pickingExercise = true }
                }
            }
            .navigationTitle(template == nil ? "テンプレート追加" : "テンプレート編集")
            .toolbar {
                EditButton()
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
                }
            }
            .sheet(isPresented: $pickingExercise) {
                NavigationStack {
                    List(exercises) { ex in
                        Button(ex.name) {
                            items.append(.init(exercise: ex))
                            pickingExercise = false
                        }
                    }
                    .navigationTitle("種目を選択")
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let tpl = template else { return }
        name = tpl.name
        items = tpl.exercises
            .sorted(by: { $0.order < $1.order })
            .compactMap { te -> Item? in
                guard let ex = te.exercise else { return nil }
                return Item(
                    exercise: ex,
                    targetSets: te.targetSets,
                    targetReps: te.targetReps,
                    targetWeightKgText: te.targetWeightKg.map { String($0) } ?? ""
                )
            }
    }

    private func save() {
        let tpl: WorkoutTemplate
        if let existing = template {
            tpl = existing
            tpl.name = name
            for te in tpl.exercises { ctx.delete(te) }
            tpl.exercises = []
        } else {
            tpl = WorkoutTemplate(name: name)
            ctx.insert(tpl)
        }
        for (i, item) in items.enumerated() {
            let te = TemplateExercise(
                order: i,
                exercise: item.exercise,
                targetSets: item.targetSets,
                targetReps: item.targetReps,
                targetWeightKg: Double(item.targetWeightKgText)
            )
            te.template = tpl
            ctx.insert(te)
        }
        try? ctx.save()
        dismiss()
    }
}
```

- [ ] **Step 3: ビルド & コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/
git commit -m "✨ feat: テンプレートの作成・編集・削除"
```

---

## Task 12: RestTimer サービス + テスト

**Files:**
- Create: `WorkoutTracker/Services/RestTimer.swift`
- Create: `WorkoutTrackerTests/ServicesTests/RestTimerTests.swift`

- [ ] **Step 1: 失敗テスト**

`WorkoutTrackerTests/ServicesTests/RestTimerTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class RestTimerTests: XCTestCase {
    func test_remaining_when_running() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = RestTimer(now: { now })
        timer.start(duration: 90)
        XCTAssertEqual(timer.remainingSeconds(at: now), 90)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(30)), 60)
        XCTAssertEqual(timer.remainingSeconds(at: now.addingTimeInterval(100)), 0)
    }

    func test_not_running_when_idle() {
        let timer = RestTimer()
        XCTAssertFalse(timer.isRunning)
    }

    func test_cancel() {
        let timer = RestTimer()
        timer.start(duration: 90)
        XCTAssertTrue(timer.isRunning)
        timer.cancel()
        XCTAssertFalse(timer.isRunning)
    }

    func test_completed_when_elapsed() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = RestTimer(now: { now })
        timer.start(duration: 60)
        XCTAssertTrue(timer.hasCompleted(at: now.addingTimeInterval(60)))
        XCTAssertFalse(timer.hasCompleted(at: now.addingTimeInterval(59)))
    }
}
```

- [ ] **Step 2: 実行して失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- [ ] **Step 3: 実装**

`WorkoutTracker/Services/RestTimer.swift`:

```swift
import Foundation
import Observation

@Observable
final class RestTimer {
    private(set) var endAt: Date?
    private let nowProvider: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.nowProvider = now
    }

    var isRunning: Bool { endAt != nil }

    func start(duration: Int) {
        endAt = nowProvider().addingTimeInterval(TimeInterval(duration))
    }

    func cancel() {
        endAt = nil
    }

    func remainingSeconds(at date: Date? = nil) -> Int {
        guard let endAt else { return 0 }
        let current = date ?? nowProvider()
        return max(0, Int(endAt.timeIntervalSince(current).rounded()))
    }

    func hasCompleted(at date: Date? = nil) -> Bool {
        guard let endAt else { return false }
        let current = date ?? nowProvider()
        return current >= endAt
    }
}
```

- [ ] **Step 4: テスト PASS**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Services WorkoutTrackerTests/ServicesTests
git commit -m "✨ feat: 休憩タイマーの中核ロジック"
```

---

## Task 13: 通知サービス

**Files:**
- Create: `WorkoutTracker/Services/NotificationService.swift`

UI から離れた副作用中心の薄いラッパー。XCTest 対象外（手動検証）。

- [ ] **Step 1: 実装**

`WorkoutTracker/Services/NotificationService.swift`:

```swift
import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let current = await center.notificationSettings()
        guard current.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleRestEnd(after seconds: Int, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = "休憩終了"
        content.body = "次のセットへ！"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds), repeats: false
        )
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(req)
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

- [ ] **Step 2: ビルド & コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/Services/NotificationService.swift
git commit -m "✨ feat: ローカル通知サービスを追加"
```

---

## Task 14: 記録画面 — セッションの開始と一覧

**Files:**
- Modify: `WorkoutTracker/Features/Recording/RecordingView.swift`
- Create: `WorkoutTracker/Features/Recording/RecordingViewModel.swift`
- Create: `WorkoutTracker/Features/Recording/ActiveSessionView.swift`

- [ ] **Step 1: ViewModel**

`WorkoutTracker/Features/Recording/RecordingViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
final class RecordingViewModel {
    @MainActor
    func startSession(context: ModelContext, template: WorkoutTemplate? = nil) -> WorkoutSession {
        let session = WorkoutSession(startedAt: Date(), templateRef: template)
        context.insert(session)
        try? context.save()
        return session
    }

    @MainActor
    func endSession(_ session: WorkoutSession, context: ModelContext) {
        session.endedAt = Date()
        try? context.save()
    }
}
```

- [ ] **Step 2: 記録タブのルート**

`WorkoutTracker/Features/Recording/RecordingView.swift`:

```swift
import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var active: [WorkoutSession]

    @Query(sort: [SortDescriptor(\WorkoutTemplate.order)])
    private var templates: [WorkoutTemplate]

    private let vm = RecordingViewModel()
    @State private var pickingTemplate = false

    var body: some View {
        NavigationStack {
            Group {
                if let session = active.first {
                    ActiveSessionView(session: session)
                } else {
                    VStack(spacing: 16) {
                        Button {
                            _ = vm.startSession(context: ctx)
                        } label: {
                            Label("空のセッションを開始", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("テンプレートから開始") { pickingTemplate = true }
                            .disabled(templates.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("記録")
            .sheet(isPresented: $pickingTemplate) {
                NavigationStack {
                    List(templates) { tpl in
                        Button(tpl.name) {
                            _ = vm.startSession(context: ctx, template: tpl)
                            pickingTemplate = false
                        }
                    }
                    .navigationTitle("テンプレートを選択")
                }
            }
        }
    }
}
```

- [ ] **Step 3: アクティブセッション View（空の枠だけ）**

`WorkoutTracker/Features/Recording/ActiveSessionView.swift`:

```swift
import SwiftUI
import SwiftData

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var ctx
    let session: WorkoutSession

    var body: some View {
        VStack {
            Text("開始: \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("（セット入力は次タスクで実装）")
            Spacer()
            Button("ワークアウトを終了") {
                RecordingViewModel().endSession(session, context: ctx)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
            .padding()
        }
    }
}
```

- [ ] **Step 4: ビルド & コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/
git commit -m "✨ feat: セッションの開始と終了"
```

---

## Task 15: 記録画面 — セット入力 + 休憩タイマー UI

**Files:**
- Modify: `WorkoutTracker/Features/Recording/ActiveSessionView.swift`
- Create: `WorkoutTracker/Features/Recording/SetInputRow.swift`
- Create: `WorkoutTracker/Features/Recording/RestTimerView.swift`

- [ ] **Step 1: セット入力 Row**

`WorkoutTracker/Features/Recording/SetInputRow.swift`:

```swift
import SwiftUI

struct SetInputRow: View {
    @Binding var weightKgText: String
    @Binding var repsText: String
    var onAdd: () -> Void

    var body: some View {
        HStack {
            TextField("kg", text: $weightKgText)
                .keyboardType(.decimalPad)
                .frame(width: 80)
            TextField("回数", text: $repsText)
                .keyboardType(.numberPad)
                .frame(width: 60)
            Spacer()
            Button("追加", action: onAdd)
                .buttonStyle(.borderedProminent)
                .disabled(Double(weightKgText) == nil || Int(repsText) == nil)
        }
    }
}
```

- [ ] **Step 2: 休憩タイマー View**

`WorkoutTracker/Features/Recording/RestTimerView.swift`:

```swift
import SwiftUI

struct RestTimerView: View {
    let remaining: Int
    let totalDuration: Int
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
            Text("\(remaining) 秒")
                .font(.headline.monospacedDigit())
            ProgressView(value: Double(totalDuration - remaining), total: Double(totalDuration))
                .frame(maxWidth: 120)
            Button(role: .cancel) { onCancel() } label: {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: `ActiveSessionView` を拡張**

`WorkoutTracker/Features/Recording/ActiveSessionView.swift`（完全書き換え）:

```swift
import SwiftUI
import SwiftData
import Combine

struct ActiveSessionView: View {
    @Environment(\.modelContext) private var ctx
    let session: WorkoutSession

    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var selectedExerciseId: UUID?
    @State private var weightKgText: String = ""
    @State private var repsText: String = ""
    @State private var restTimer = RestTimer()
    @State private var timerTick = Date()
    @State private var totalRest: Int = 90

    private let timerId = "rest-timer"
    private let pulse = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var selectedExercise: Exercise? {
        exercises.first { $0.id == selectedExerciseId }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            exercisePicker
            if restTimer.isRunning {
                RestTimerView(
                    remaining: restTimer.remainingSeconds(at: timerTick),
                    totalDuration: totalRest,
                    onCancel: cancelTimer
                )
                .padding(.horizontal)
            }
            if let ex = selectedExercise {
                List {
                    Section("本日のセット") {
                        ForEach(session.sets.filter { $0.exercise?.id == ex.id }) { set in
                            HStack {
                                Text("\(set.weightKg, specifier: "%.1f") kg × \(set.reps)")
                                Spacer()
                                Text(set.performedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { idx in
                            let setsOfEx = session.sets.filter { $0.exercise?.id == ex.id }
                            idx.map { setsOfEx[$0] }.forEach(ctx.delete)
                            try? ctx.save()
                        }
                    }
                }
                SetInputRow(weightKgText: $weightKgText, repsText: $repsText, onAdd: addSet)
                    .padding()
            } else {
                Spacer()
                Text("種目を選択してください").foregroundStyle(.secondary)
                Spacer()
            }
            Button("ワークアウトを終了") {
                restTimer.cancel()
                NotificationService.shared.cancel(identifier: timerId)
                RecordingViewModel().endSession(session, context: ctx)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding()
        }
        .onReceive(pulse) { _ in
            timerTick = Date()
            if restTimer.hasCompleted(at: timerTick) {
                restTimer.cancel()
            }
        }
        .task {
            await NotificationService.shared.requestAuthorizationIfNeeded()
        }
    }

    private var header: some View {
        HStack {
            Text("開始: \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var exercisePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(exercises) { ex in
                    Button(ex.name) { selectedExerciseId = ex.id }
                        .buttonStyle(.bordered)
                        .tint(selectedExerciseId == ex.id ? .accentColor : .gray)
                }
            }
            .padding()
        }
    }

    private func addSet() {
        guard let ex = selectedExercise,
              let w = Double(weightKgText),
              let r = Int(repsText) else { return }
        let set = SetRecord(exercise: ex, session: session, weightKg: w, reps: r)
        ctx.insert(set)
        try? ctx.save()
        weightKgText = ""
        repsText = ""
        startTimer(for: ex)
    }

    private func startTimer(for ex: Exercise) {
        totalRest = ex.defaultRestSeconds
        restTimer.start(duration: totalRest)
        Task {
            await NotificationService.shared.scheduleRestEnd(after: totalRest, identifier: timerId)
        }
    }

    private func cancelTimer() {
        restTimer.cancel()
        NotificationService.shared.cancel(identifier: timerId)
    }
}
```

- [ ] **Step 4: ビルド確認 + シミュレータで手動確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

手動確認: シミュレータで起動→ セッション開始 → 種目選択 → 重量/回数入力 → タイマー動作 → セット削除。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/
git commit -m "✨ feat: セット入力と休憩タイマー UI"
```

---

## Task 16: 履歴画面 — セッション一覧と詳細

**Files:**
- Modify: `WorkoutTracker/Features/History/HistoryView.swift`
- Create: `WorkoutTracker/Features/History/SessionDetailView.swift`

- [ ] **Step 1: 履歴一覧**

`WorkoutTracker/Features/History/HistoryView.swift`:

```swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case sessions = "セッション"
        case exercises = "種目"
        case body = "体組成"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .sessions

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch tab {
                case .sessions: SessionsListView()
                case .exercises: ExerciseChartsView()
                case .body: BodyCompositionView()
                }
            }
            .navigationTitle("履歴")
        }
    }
}

private struct SessionsListView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
    )
    private var sessions: [WorkoutSession]

    var body: some View {
        List(sessions) { s in
            NavigationLink(value: s.id) {
                VStack(alignment: .leading) {
                    Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    Text("\(s.sets.count) セット")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            SessionDetailView(sessionId: id)
        }
    }
}
```

空のプレースホルダを置いておく（次タスクで実装）:

`WorkoutTracker/Features/History/ExerciseChartsView.swift`:

```swift
import SwiftUI
struct ExerciseChartsView: View { var body: some View { Text("（次タスクで実装）") } }
```

`WorkoutTracker/Features/History/BodyCompositionView.swift`:

```swift
import SwiftUI
struct BodyCompositionView: View { var body: some View { Text("（次タスクで実装）") } }
```

- [ ] **Step 2: 詳細画面**

`WorkoutTracker/Features/History/SessionDetailView.swift`:

```swift
import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let sessionId: UUID
    @Query private var sessions: [WorkoutSession]
    init(sessionId: UUID) {
        self.sessionId = sessionId
        _sessions = Query(filter: #Predicate<WorkoutSession> { $0.id == sessionId })
    }

    var body: some View {
        if let s = sessions.first {
            List {
                Section("概要") {
                    LabeledContent("開始", value: s.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if let end = s.endedAt {
                        LabeledContent("終了", value: end.formatted(date: .omitted, time: .shortened))
                    }
                    LabeledContent("総ボリューム", value: String(format: "%.0f kg", WorkoutMetrics.totalVolume(sets: s.sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) })))
                }
                Section("セット") {
                    ForEach(groupedByExercise(s.sets), id: \.0) { name, sets in
                        VStack(alignment: .leading) {
                            Text(name).font(.headline)
                            ForEach(sets) { set in
                                Text("  \(set.weightKg, specifier: "%.1f") kg × \(set.reps)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("詳細")
        } else {
            Text("見つかりません")
        }
    }

    private func groupedByExercise(_ sets: [SetRecord]) -> [(String, [SetRecord])] {
        Dictionary(grouping: sets, by: { $0.exercise?.name ?? "（削除済）" })
            .sorted(by: { $0.key < $1.key })
    }
}
```

- [ ] **Step 3: ビルド & コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/
git commit -m "✨ feat: 履歴タブ（セッション一覧と詳細）"
```

---

## Task 17: 履歴画面 — 種目別グラフ

**Files:**
- Modify: `WorkoutTracker/Features/History/ExerciseChartsView.swift`

- [ ] **Step 1: 実装**

`WorkoutTracker/Features/History/ExerciseChartsView.swift`:

```swift
import SwiftUI
import SwiftData
import Charts

struct ExerciseChartsView: View {
    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var selectedId: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            Picker("種目", selection: $selectedId) {
                Text("選択してください").tag(UUID?.none)
                ForEach(exercises) { ex in
                    Text(ex.name).tag(UUID?.some(ex.id))
                }
            }
            .padding(.horizontal)

            if let ex = exercises.first(where: { $0.id == selectedId }) {
                ChartsFor(exercise: ex)
            } else {
                Spacer()
                Text("種目を選んでください").foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

private struct ChartsFor: View {
    let exercise: Exercise

    var sets: [SetRecord] {
        exercise.setRecords
            .filter { $0.session?.endedAt != nil }
            .sorted(by: { $0.performedAt < $1.performedAt })
    }

    var topWeightByDay: [(Date, Double)] {
        Dictionary(grouping: sets, by: { Calendar.current.startOfDay(for: $0.performedAt) })
            .map { ($0.key, $0.value.map(\.weightKg).max() ?? 0) }
            .sorted { $0.0 < $1.0 }
    }

    var est1RMByDay: [(Date, Double)] {
        Dictionary(grouping: sets, by: { Calendar.current.startOfDay(for: $0.performedAt) })
            .compactMap { (day, ss) -> (Date, Double)? in
                let values = ss.compactMap { WorkoutMetrics.epley1RM(weightKg: $0.weightKg, reps: $0.reps) }
                guard let best = values.max() else { return nil }
                return (day, best)
            }
            .sorted { $0.0 < $1.0 }
    }

    var volumeByDay: [(Date, Double)] {
        Dictionary(grouping: sets, by: { Calendar.current.startOfDay(for: $0.performedAt) })
            .map { ($0.key, WorkoutMetrics.totalVolume(sets: $0.value.map { .init(weightKg: $0.weightKg, reps: $0.reps) })) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(title: "最高重量 (kg)", data: topWeightByDay)
                section(title: "推定 1RM (kg)", data: est1RMByDay)
                section(title: "総ボリューム", data: volumeByDay)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func section(title: String, data: [(Date, Double)]) -> some View {
        Text(title).font(.headline)
        if data.isEmpty {
            Text("データがありません").foregroundStyle(.secondary)
        } else {
            Chart(data, id: \.0) { item in
                LineMark(x: .value("日付", item.0), y: .value(title, item.1))
                PointMark(x: .value("日付", item.0), y: .value(title, item.1))
            }
            .frame(height: 180)
        }
    }
}
```

- [ ] **Step 2: ビルド & コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/
git commit -m "✨ feat: 種目別グラフ（重量・推定 1RM・ボリューム）"
```

---

## Task 18: HealthKitService プロトコルとモックテスト

**Files:**
- Create: `WorkoutTracker/Services/HealthKitService.swift`
- Create: `WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift`

- [ ] **Step 1: 失敗テスト（モック実装ベース）**

`WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class HealthKitServiceTests: XCTestCase {
    func test_mock_returns_injected_values() async throws {
        let stub = StubHealthKitService(
            latest: .init(recordedAt: Date(), weightKg: 70, bodyFatPercent: 18, source: .healthKit),
            range: []
        )
        let latest = try await stub.fetchLatestBodyMetric()
        XCTAssertEqual(latest?.weightKg, 70)
    }

    func test_mock_denied_returns_nil() async throws {
        let stub = StubHealthKitService(
            latest: nil,
            range: [],
            authorizationError: HealthKitError.denied
        )
        do {
            try await stub.requestAuthorization()
            XCTFail("denied を投げるべき")
        } catch HealthKitError.denied {
            // OK
        }
    }
}

final class StubHealthKitService: HealthKitService {
    let latest: BodyMetricDTO?
    let range: [BodyMetricDTO]
    let authorizationError: Error?
    init(latest: BodyMetricDTO?, range: [BodyMetricDTO], authorizationError: Error? = nil) {
        self.latest = latest; self.range = range; self.authorizationError = authorizationError
    }
    func requestAuthorization() async throws {
        if let authorizationError { throw authorizationError }
    }
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? { latest }
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] { range }
}
```

- [ ] **Step 2: 実行して失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: `HealthKitService`, `BodyMetricDTO`, `HealthKitError` 未定義。

- [ ] **Step 3: プロトコルと DTO の実装**

`WorkoutTracker/Services/HealthKitService.swift`:

```swift
import Foundation
import HealthKit

struct BodyMetricDTO: Equatable {
    let recordedAt: Date
    let weightKg: Double?
    let bodyFatPercent: Double?
    let source: BodyMetricSource
}

enum HealthKitError: Error {
    case unavailable
    case denied
}

protocol HealthKitService {
    func requestAuthorization() async throws
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO?
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO]
}

final class LiveHealthKitService: HealthKitService {
    private let store = HKHealthStore()
    private let weightType = HKQuantityType(.bodyMass)
    private let fatType = HKQuantityType(.bodyFatPercentage)

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [weightType, fatType])
    }

    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? {
        let weight = try await latestQuantity(type: weightType, unit: .gramUnit(with: .kilo))
        let fat = try await latestQuantity(type: fatType, unit: .percent())
        let date = [weight?.date, fat?.date].compactMap { $0 }.max()
        guard let date else { return nil }
        return BodyMetricDTO(
            recordedAt: date,
            weightKg: weight?.value,
            bodyFatPercent: fat.map { $0.value * 100 },
            source: .healthKit
        )
    }

    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] {
        let weights = try await samples(type: weightType, unit: .gramUnit(with: .kilo), from: from, to: to)
        let fats = try await samples(type: fatType, unit: .percent(), from: from, to: to)
        var byDay: [Date: (Double?, Double?)] = [:]
        let cal = Calendar.current
        for s in weights {
            let day = cal.startOfDay(for: s.date)
            byDay[day, default: (nil, nil)].0 = s.value
        }
        for s in fats {
            let day = cal.startOfDay(for: s.date)
            byDay[day, default: (nil, nil)].1 = s.value * 100
        }
        return byDay
            .map { BodyMetricDTO(recordedAt: $0.key, weightKg: $0.value.0, bodyFatPercent: $0.value.1, source: .healthKit) }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    private struct Sample { let value: Double; let date: Date }

    private func latestQuantity(type: HKQuantityType, unit: HKUnit) async throws -> Sample? {
        try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                if let s = samples?.first as? HKQuantitySample {
                    cont.resume(returning: .init(value: s.quantity.doubleValue(for: unit), date: s.endDate))
                } else {
                    cont.resume(returning: nil)
                }
            }
            store.execute(q)
        }
    }

    private func samples(type: HKQuantityType, unit: HKUnit, from: Date, to: Date) async throws -> [Sample] {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let q = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let result = (samples ?? []).compactMap { $0 as? HKQuantitySample }
                    .map { Sample(value: $0.quantity.doubleValue(for: unit), date: $0.endDate) }
                cont.resume(returning: result)
            }
            store.execute(q)
        }
    }
}
```

- [ ] **Step 4: テスト PASS**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/ WorkoutTrackerTests/
git commit -m "✨ feat: HealthKit サービスのプロトコルと実装"
```

---

## Task 19: 体組成 View と HealthKit 連携

**Files:**
- Modify: `WorkoutTracker/Features/History/BodyCompositionView.swift`
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`

- [ ] **Step 1: 体組成 View**

`WorkoutTracker/Features/History/BodyCompositionView.swift`:

```swift
import SwiftUI
import SwiftData
import Charts

struct BodyCompositionView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt)])
    private var metrics: [BodyMetric]

    @State private var showAdd = false
    @State private var syncing = false

    private let health: HealthKitService = LiveHealthKitService()

    var displayedWeight: [(Date, Double)] {
        dedupPreferringManual(\.weightKg)
    }
    var displayedFat: [(Date, Double)] {
        dedupPreferringManual(\.bodyFatPercent)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    Task { await syncFromHealthKit() }
                } label: {
                    Label(syncing ? "同期中..." : "HealthKit 同期", systemImage: "heart.text.square")
                }
                .disabled(syncing)
                Spacer()
                Button { showAdd = true } label: { Label("手入力", systemImage: "plus") }
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    chart(title: "体重 (kg)", data: displayedWeight)
                    chart(title: "体脂肪率 (%)", data: displayedFat)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAdd) { BodyMetricForm() }
    }

    @ViewBuilder
    private func chart(title: String, data: [(Date, Double)]) -> some View {
        Text(title).font(.headline)
        if data.isEmpty {
            Text("データがありません").foregroundStyle(.secondary)
        } else {
            Chart(data, id: \.0) { item in
                LineMark(x: .value("日付", item.0), y: .value(title, item.1))
            }
            .frame(height: 180)
        }
    }

    private func dedupPreferringManual(_ key: KeyPath<BodyMetric, Double?>) -> [(Date, Double)] {
        let cal = Calendar.current
        var byDay: [Date: BodyMetric] = [:]
        for m in metrics where m[keyPath: key] != nil {
            let d = cal.startOfDay(for: m.recordedAt)
            if let existing = byDay[d] {
                if existing.source == .healthKit && m.source == .manual {
                    byDay[d] = m
                }
            } else {
                byDay[d] = m
            }
        }
        return byDay
            .compactMap { day, m in m[keyPath: key].map { (day, $0) } }
            .sorted { $0.0 < $1.0 }
    }

    private func syncFromHealthKit() async {
        syncing = true
        defer { syncing = false }
        do {
            try await health.requestAuthorization()
            let from = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            let dtos = try await health.fetchBodyMetrics(from: from, to: Date())
            await MainActor.run { merge(dtos) }
        } catch {
            // 権限拒否や未対応はサイレントに無視（UI は手入力にフォールバック）
        }
    }

    @MainActor
    private func merge(_ dtos: [BodyMetricDTO]) {
        let cal = Calendar.current
        let existing = Dictionary(
            grouping: metrics.filter { $0.source == .healthKit },
            by: { cal.startOfDay(for: $0.recordedAt) }
        )
        for dto in dtos {
            let day = cal.startOfDay(for: dto.recordedAt)
            if let dup = existing[day]?.first {
                dup.weightKg = dto.weightKg
                dup.bodyFatPercent = dto.bodyFatPercent
                dup.recordedAt = dto.recordedAt
            } else {
                ctx.insert(BodyMetric(
                    recordedAt: dto.recordedAt,
                    weightKg: dto.weightKg,
                    bodyFatPercent: dto.bodyFatPercent,
                    source: .healthKit
                ))
            }
        }
        try? ctx.save()
    }
}

private struct BodyMetricForm: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var weightText = ""
    @State private var fatText = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日付", selection: $date, displayedComponents: .date)
                TextField("体重 (kg)", text: $weightText).keyboardType(.decimalPad)
                TextField("体脂肪率 (%)", text: $fatText).keyboardType(.decimalPad)
            }
            .navigationTitle("体組成を入力")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(Double(weightText) == nil && Double(fatText) == nil)
                }
            }
        }
    }

    private func save() {
        let metric = BodyMetric(
            recordedAt: date,
            weightKg: Double(weightText),
            bodyFatPercent: Double(fatText),
            source: .manual
        )
        ctx.insert(metric)
        try? ctx.save()
        dismiss()
    }
}
```

- [ ] **Step 2: ビルド & 手動確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

手動確認: シミュレータ Health アプリで体重サンプルを入力 → アプリで「HealthKit 同期」→ グラフに反映。

- [ ] **Step 3: コミット**

```bash
git add WorkoutTracker/
git commit -m "✨ feat: 体組成タブと HealthKit 同期"
```

---

## Task 20: ホーム画面

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`

- [ ] **Step 1: 実装**

`WorkoutTracker/Features/Home/HomeView.swift`:

```swift
import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var ctx

    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
    )
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt)])
    private var metrics: [BodyMetric]

    private let vm = RecordingViewModel()

    var recent3: [WorkoutSession] { Array(sessions.prefix(3)) }

    var last30DaysWeight: [(Date, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return metrics
            .filter { $0.recordedAt >= cutoff }
            .compactMap { m in m.weightKg.map { (m.recordedAt, $0) } }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        _ = vm.startSession(context: ctx)
                    } label: {
                        Label("今日のワークアウトを開始", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("最近のセッション") {
                    if recent3.isEmpty {
                        Text("まだ記録がありません").foregroundStyle(.secondary)
                    }
                    ForEach(recent3) { s in
                        VStack(alignment: .leading) {
                            Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            HStack(spacing: 16) {
                                Text("\(s.sets.count) セット")
                                Text(String(format: "%.0f kg", WorkoutMetrics.totalVolume(sets: s.sets.map { .init(weightKg: $0.weightKg, reps: $0.reps) })))
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("体重 (30 日)") {
                    if last30DaysWeight.isEmpty {
                        Text("データなし").foregroundStyle(.secondary)
                    } else {
                        Chart(last30DaysWeight, id: \.0) { item in
                            LineMark(x: .value("日付", item.0), y: .value("kg", item.1))
                        }
                        .frame(height: 80)
                    }
                }
            }
            .navigationTitle("ホーム")
        }
    }
}
```

- [ ] **Step 2: ビルド & コミット**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
git add WorkoutTracker/
git commit -m "✨ feat: ホーム画面（開始ボタン・最近のセッション・体重トレンド）"
```

---

## Task 21: 最終確認とドキュメント整備

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 全テストを走らせる**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
```

期待: 全テスト PASS。

- [ ] **Step 2: シミュレータで手動シナリオ確認**

以下のシナリオを順に試す:
1. 初回起動 → プリセット種目が 10 件以上表示
2. 種目追加・編集・非表示化
3. テンプレート作成 → 記録タブで開始 → セット追加 → 休憩タイマー動作 → 終了
4. 履歴タブで直近セッションを確認、種目別グラフを表示
5. 体組成: 手入力を追加、グラフに反映
6. ダークモード切替: 色・コントラストが崩れないか
7. Dynamic Type 最大で主要画面が読めるか

- [ ] **Step 3: `README.md` に開発手順を追記**

`README.md` を以下に置き換え:

```markdown
# workout-tracker

iOS app for registering workout menus and recording training sessions, built with Swift and SwiftUI.

## 開発環境

- Xcode 16+
- iOS 18+ / iPhone
- [mise](https://mise.jdx.dev/) + XcodeGen

## セットアップ

\`\`\`bash
mise install
xcodegen generate
open WorkoutTracker.xcodeproj
\`\`\`

## コマンド

\`\`\`bash
# ビルド
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' build

# テスト
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16' test
\`\`\`

## ドキュメント

- 設計: `docs/superpowers/specs/2026-04-20-workout-tracker-ios-design.md`
- 実装計画: `docs/superpowers/plans/2026-04-20-workout-tracker-ios.md`
```

- [ ] **Step 4: 最終コミット**

```bash
git add README.md WorkoutTracker/
git commit -m "📝 docs: README を整備、最終調整"
```

---

## 付録: トラブルシュート

- `xcodegen generate` で「target が見つからない」: `project.yml` のインデント崩れを確認。
- `ModelContainer` 初期化失敗: スキーマ変更時は iOS シミュレータのアプリを一度削除して再ビルド。
- HealthKit の権限ダイアログが出ない: `Info.plist` のキーとターゲットに Capability が反映されているか確認（XcodeGen は自動付与しないため、必要なら `entitlements` を `project.yml` に追加）。
