# Walking as Step 1 / ほのぼの強化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ホーム画面を歩く主役に再構成し、旅タブを「歩く」へリネーム、水彩イラスト 17 枚を gpt-image-1 で生成して同梱、CompanionLines を 200 件以上に拡張、テスト fixture を整備する。

**Architecture:** 9 フェーズ順次実装。基盤（テスト fixture）→ 静的リネーム（Asset path）→ タブ機構 → 画像パイプライン（Python） → イラスト投入 → 背景置換 → 文言拡張 → ホーム再構成 → 仕上げ。各フェーズは独立コミット、ロールバック可能、build + test green を維持。

**Tech Stack:** Swift 5.10 / SwiftUI / SwiftData / iOS 18+ / xcodegen / XCTest / Python 3.12 + uv / OpenAI gpt-image-1 / TOML / JSON

**Spec:** `docs/superpowers/specs/2026-05-08-walking-as-step1-design.md`

---

## 共通コマンド

ビルド:
```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

全テスト:
```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

単一テスト（クラス指定例）:
```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/DomainTests/CompanionDialogTests
```

`project.yml` 変更後は必ず:
```bash
xcodegen generate
```

---

## ファイル構造一覧

**新規作成:**
- `WorkoutTracker/App/AppTab.swift`
- `WorkoutTracker/Features/Home/StepHeroCard.swift`
- `WorkoutTracker/Features/Home/JourneyMiniCard.swift`
- `WorkoutTracker/Features/Walk/TimeOfDayScenery.swift`
- `WorkoutTracker/Domain/CompanionLineFilter.swift`
- `WorkoutTracker/TestSupport/Fixtures.swift`
- `WorkoutTracker/TestSupport/DateHelpers.swift`
- `WorkoutTracker/TestSupport/StubHealthKitService.swift`
- `WorkoutTracker/TestSupport/JourneyServicePreview.swift`
- `WorkoutTracker/Resources/CompanionLines.json`
- `WorkoutTrackerTests/TestSupport/FixturesTests.swift`
- `WorkoutTrackerTests/TestSupport/DateHelpersTests.swift`
- `WorkoutTrackerTests/DomainTests/CompanionLineFilterTests.swift`
- `WorkoutTrackerTests/FeaturesTests/StepHeroCardLogicTests.swift`
- `WorkoutTrackerTests/FeaturesTests/JourneyMiniCardLogicTests.swift`
- `scripts/illustrations/generate.py`
- `scripts/illustrations/prompts.toml`
- `scripts/illustrations/style_guide.md`
- `scripts/illustrations/pyproject.toml`
- `scripts/illustrations/.gitignore`
- `.envrc.example`
- 17 PNG: `WorkoutTracker/Resources/Assets.xcassets/Scenery/<id>.imageset/<id>.png`

**変更:**
- `WorkoutTracker/App/RootView.swift`
- `WorkoutTracker/Features/Home/HomeView.swift`
- `WorkoutTracker/Features/Walk/WalkView.swift`
- `WorkoutTracker/Domain/JourneyRoute.swift`
- `WorkoutTracker/Features/History/BodyCompositionView.swift`（参照あれば）
- `WorkoutTracker/Domain/CompanionDialog.swift`
- `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`
- `WorkoutTrackerTests/DomainTests/JourneyEngineTests.swift`
- `WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift`
- `WorkoutTrackerTests/ModelsTests/StepDailyRecordTests.swift`
- `WorkoutTrackerTests/ModelsTests/CheckpointAchievementTests.swift`
- `project.yml`
- `.tool-versions`
- `README.md`

**削除:**
- `WorkoutTracker/Features/Walk/TimeOfDayBackground.swift`
- `WorkoutTracker/Resources/Assets.xcassets/Badges/`（リネーム先 `Scenery/` で置換）

---

### Task 1: project.yml に TestSupport ディレクトリを追加

**Files:**
- Modify: `project.yml`

`TestSupport/` ディレクトリを sources に含める準備。既存の `path: WorkoutTracker` が再帰的に拾うため確認のみだが、明示する方がスキーマで安全。

- [ ] **Step 1: project.yml の sources を確認**

Read: `project.yml` の `targets.WorkoutTracker.sources`

現状:
```yaml
sources:
  - path: WorkoutTracker
```

`WorkoutTracker/` 配下の Swift ファイルは再帰的に含まれるため変更不要。Task 1 はスキップして OK。検証のため次ステップへ。

- [ ] **Step 2: 確認のため xcodegen generate を実行**

```bash
xcodegen generate
```

Expected: `Created project at WorkoutTracker.xcodeproj`、エラーなし。

- [ ] **Step 3: ビルドが通ることを確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: コミットなし（変更なしのため）**

確認のみで Task 1 完了。

---

### Task 2: DateHelpers ユーティリティ作成

**Files:**
- Create: `WorkoutTracker/TestSupport/DateHelpers.swift`
- Create: `WorkoutTrackerTests/TestSupport/DateHelpersTests.swift`

`#if DEBUG` で Date の相対計算ヘルパーを提供。

- [ ] **Step 1: テストファイル作成**

`WorkoutTrackerTests/TestSupport/DateHelpersTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

#if DEBUG
final class DateHelpersTests: XCTestCase {
    func test_daysAgo_returnsDateInPast() {
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let yesterday = DateHelpers.daysAgo(1, from: now)
        let diff = now.timeIntervalSince(yesterday)
        XCTAssertEqual(diff, 86_400, accuracy: 1.0)
    }

    func test_daysAgo_zero_returnsSameDay() {
        let now = Date()
        let same = DateHelpers.daysAgo(0, from: now)
        XCTAssertEqual(now.timeIntervalSince(same), 0, accuracy: 1.0)
    }

    func test_startOfDay_alignsToCalendarMidnight() {
        let date = Date(timeIntervalSince1970: 1_730_045_000)  // 2024-10-27 some time
        let start = DateHelpers.startOfDay(date)
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: start)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
    }
}
#endif
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/TestSupport/DateHelpersTests
```

Expected: FAIL（`DateHelpers` が未定義）

- [ ] **Step 3: 実装ファイル作成**

`WorkoutTracker/TestSupport/DateHelpers.swift`:

```swift
import Foundation

#if DEBUG
enum DateHelpers {
    static func daysAgo(_ days: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: base) ?? base
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
#endif
```

- [ ] **Step 4: xcodegen 再生成 + テスト実行**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/TestSupport/DateHelpersTests
```

Expected: PASS

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/TestSupport/DateHelpers.swift \
        WorkoutTrackerTests/TestSupport/DateHelpersTests.swift \
        WorkoutTracker.xcodeproj
git commit -m "🧪 DateHelpers ユーティリティを追加 (#if DEBUG)"
```

---

### Task 3: Fixtures 構造体作成（Steps + ビルダー）

**Files:**
- Create: `WorkoutTracker/TestSupport/Fixtures.swift`
- Create: `WorkoutTrackerTests/TestSupport/FixturesTests.swift`

代表値 1234 歩を含む Steps enum とビルダー関数群。

- [ ] **Step 1: テストファイル作成**

`WorkoutTrackerTests/TestSupport/FixturesTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

#if DEBUG
@MainActor
final class FixturesTests: XCTestCase {
    func test_Steps_representativeIs1234() {
        XCTAssertEqual(Fixtures.Steps.representative, 1234)
    }

    func test_stepRecord_buildsRecordWithCount() {
        let record = Fixtures.stepRecord(1234, daysAgo: 0)
        XCTAssertEqual(record.count, 1234)
    }

    func test_stepRecord_daysAgoSetsDate() {
        let now = Date()
        let record = Fixtures.stepRecord(500, daysAgo: 3)
        let diff = now.timeIntervalSince(record.date)
        XCTAssertEqual(diff, 86_400 * 3, accuracy: 1.0)
    }

    func test_achievement_setsCheckpointId() {
        let ach = Fixtures.achievement("tokyo", daysAgo: 1)
        XCTAssertEqual(ach.checkpointId, "tokyo")
        XCTAssertFalse(ach.celebrated)
    }

    func test_bodyMetric_defaultWeight() {
        let metric = Fixtures.bodyMetric()
        XCTAssertEqual(metric.weightKg, 72.4, accuracy: 0.01)
    }

    func test_varietyWeek_hasSevenDistinctValues() {
        XCTAssertEqual(Fixtures.varietyWeek.count, 7)
        XCTAssertEqual(Set(Fixtures.varietyWeek).count, 7)
    }

    func test_streak4Days_allAboveTypicalGoal() {
        XCTAssertEqual(Fixtures.streak4Days.count, 4)
        XCTAssertTrue(Fixtures.streak4Days.allSatisfy { $0 >= 8000 })
    }

    func test_midJourneyAchievements_returnsFourCheckpoints() {
        let achievements = Fixtures.midJourneyAchievements()
        XCTAssertEqual(achievements.count, 4)
        XCTAssertEqual(achievements.map(\.checkpointId),
                       ["tokyo", "yokohama", "atami", "shizuoka"])
    }
}
#endif
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/TestSupport/FixturesTests
```

Expected: FAIL（`Fixtures` 未定義）

- [ ] **Step 3: 実装ファイル作成**

`WorkoutTracker/TestSupport/Fixtures.swift`:

```swift
import Foundation
import SwiftData

#if DEBUG
@MainActor
enum Fixtures {
    enum Steps {
        static let representative = 1234
        static let goalAchieved   = 8500
        static let lazy           = 320
        static let highEffort     = 12_345
    }

    static let varietyWeek: [Int]   = [1234, 5432, 8500, 320, 9100, 6700, 4200]
    static let streak4Days: [Int]   = [8500, 8600, 8400, 8700]

    static func stepRecord(_ count: Int, daysAgo: Int = 0) -> StepDailyRecord {
        StepDailyRecord(
            date: DateHelpers.startOfDay(DateHelpers.daysAgo(daysAgo)),
            count: count
        )
    }

    static func achievement(_ checkpointId: String, daysAgo: Int = 0) -> CheckpointAchievement {
        CheckpointAchievement(
            checkpointId: checkpointId,
            achievedAt: DateHelpers.daysAgo(daysAgo),
            celebrated: false
        )
    }

    static func bodyMetric(weightKg: Double = 72.4,
                           bodyFatPercent: Double? = 22.0,
                           daysAgo: Int = 0) -> BodyMetric {
        BodyMetric(
            recordedAt: DateHelpers.daysAgo(daysAgo),
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercent
        )
    }

    static func session(startedDaysAgo: Int = 0,
                        sets: [(weightKg: Double, reps: Int)] = []) -> WorkoutSession {
        let session = WorkoutSession(startedAt: DateHelpers.daysAgo(startedDaysAgo))
        for (i, s) in sets.enumerated() {
            let rec = SetRecord(
                weightKg: s.weightKg,
                reps: s.reps,
                rpe: nil,
                order: i
            )
            session.sets.append(rec)
        }
        return session
    }

    static func midJourneyAchievements() -> [CheckpointAchievement] {
        ["tokyo", "yokohama", "atami", "shizuoka"]
            .enumerated()
            .map { i, id in achievement(id, daysAgo: 30 - i * 5) }
    }

    static func firstDayUser() -> [StepDailyRecord] {
        [stepRecord(Steps.representative, daysAgo: 0)]
    }
}
#endif
```

注: `BodyMetric` / `SetRecord` / `WorkoutSession` / `StepDailyRecord` / `CheckpointAchievement` のイニシャライザシグネチャは既存の Models 定義に合わせる必要がある。Step 4 でビルドエラーが出たら、`WorkoutTracker/Models/<Name>.swift` を読んで該当パラメータを修正する。

- [ ] **Step 4: ビルドが通ることを確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`。失敗した場合、`WorkoutTracker/Models/` 配下の各ファイルを読んでパラメータを合わせる。

- [ ] **Step 5: テスト実行**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/TestSupport/FixturesTests
```

Expected: 8 件すべて PASS

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/TestSupport/Fixtures.swift \
        WorkoutTrackerTests/TestSupport/FixturesTests.swift \
        WorkoutTracker.xcodeproj
git commit -m "🧪 Fixtures 構造体を追加（代表値 1234 歩 + ビルダー + シナリオプリセット）"
```

---

### Task 4: InMemoryContainer.seeded(_:) 拡張

**Files:**
- Modify: `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`

任意のクロージャでデータを seed できる便利関数。

- [ ] **Step 1: 既存ファイルの最後に拡張を追加**

`WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift` の末尾に追加:

```swift
#if DEBUG
extension InMemoryContainer {
    @MainActor
    static func seeded(_ build: (ModelContext) -> Void) throws -> ModelContainer {
        let container = try make()
        build(container.mainContext)
        try container.mainContext.save()
        return container
    }
}
#endif
```

- [ ] **Step 2: 動作確認テストを FixturesTests に追加**

`WorkoutTrackerTests/TestSupport/FixturesTests.swift` に以下のテストを追加:

```swift
    func test_seededContainer_holdsInsertedRecords() throws {
        let container = try InMemoryContainer.seeded { ctx in
            for (i, n) in Fixtures.varietyWeek.enumerated() {
                ctx.insert(Fixtures.stepRecord(n, daysAgo: i))
            }
        }
        let descriptor = FetchDescriptor<StepDailyRecord>()
        let records = try container.mainContext.fetch(descriptor)
        XCTAssertEqual(records.count, 7)
    }
```

- [ ] **Step 3: ビルド + テスト実行**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/TestSupport/FixturesTests
```

Expected: 9 件すべて PASS

- [ ] **Step 4: コミット**

```bash
git add WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift \
        WorkoutTrackerTests/TestSupport/FixturesTests.swift
git commit -m "🧪 InMemoryContainer.seeded(_:) を追加"
```

---

### Task 5: 既存テストを Fixtures 利用に置換（最小限）

**Files:**
- Modify: `WorkoutTrackerTests/ModelsTests/StepDailyRecordTests.swift`
- Modify: `WorkoutTrackerTests/ModelsTests/CheckpointAchievementTests.swift`

YAGNI で全置換はしない。新シナリオのみ追加。

- [ ] **Step 1: StepDailyRecordTests に 1234 fixture テスト追加**

`WorkoutTrackerTests/ModelsTests/StepDailyRecordTests.swift` の末尾（テストクラス内）に追加:

```swift
    func test_stepRecord_representativeFixture_persists() throws {
        let container = try InMemoryContainer.seeded { ctx in
            ctx.insert(Fixtures.stepRecord(Fixtures.Steps.representative))
        }
        let records = try container.mainContext.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.count, 1234)
    }
```

- [ ] **Step 2: CheckpointAchievementTests に midJourney テスト追加**

`WorkoutTrackerTests/ModelsTests/CheckpointAchievementTests.swift` の末尾に追加:

```swift
    func test_midJourneyAchievements_persistsInOrder() throws {
        let container = try InMemoryContainer.seeded { ctx in
            Fixtures.midJourneyAchievements().forEach { ctx.insert($0) }
        }
        let descriptor = FetchDescriptor<CheckpointAchievement>(
            sortBy: [SortDescriptor(\.achievedAt, order: .forward)]
        )
        let achievements = try container.mainContext.fetch(descriptor)
        XCTAssertEqual(achievements.count, 4)
        XCTAssertEqual(achievements.first?.checkpointId, "tokyo")
        XCTAssertEqual(achievements.last?.checkpointId, "shizuoka")
    }
```

- [ ] **Step 3: テスト実行**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/ModelsTests
```

Expected: 全 PASS（既存 + 新規 2 件）

- [ ] **Step 4: コミット**

```bash
git add WorkoutTrackerTests/ModelsTests/StepDailyRecordTests.swift \
        WorkoutTrackerTests/ModelsTests/CheckpointAchievementTests.swift
git commit -m "🧪 既存テストに Fixtures シナリオを追加（最小限の置換）"
```

---

### Task 6: Asset path リネーム — Badges → Scenery + sceneryAssetName

**Files:**
- Modify: `WorkoutTracker/Domain/JourneyRoute.swift`
- Modify: `WorkoutTracker/Resources/Assets.xcassets/Badges/` → リネーム
- Modify: `WorkoutTracker/Features/Walk/BadgesView.swift`
- Modify: `WorkoutTracker/Features/Walk/CelebrationOverlay.swift`

既存の `badgeAssetName` プロパティを `sceneryAssetName` に、Asset ディレクトリ `Badges/` を `Scenery/` にリネーム。

- [ ] **Step 1: git grep で参照箇所をすべて確認**

```bash
git grep -n "badgeAssetName"
git grep -n "Badges/"
```

参照箇所を一覧化（メモ帳に控える）。Expected: `JourneyRoute.swift`, `BadgesView.swift`, `CelebrationOverlay.swift` あたり。

- [ ] **Step 2: Assets.xcassets ディレクトリのリネーム**

```bash
git mv WorkoutTracker/Resources/Assets.xcassets/Badges \
       WorkoutTracker/Resources/Assets.xcassets/Scenery
```

- [ ] **Step 3: JourneyRoute.swift の改修**

`WorkoutTracker/Domain/JourneyRoute.swift` の `Checkpoint` struct を更新:

```swift
struct Checkpoint: Identifiable, Equatable {
    let id: String
    let name: String
    let cumulativeKm: Double
    let mapPosition: CGPoint
    let blurb: String
    let sceneryAssetName: String   // 旧: badgeAssetName
}
```

各 `.init(...)` 呼び出しの `badgeAssetName: "Badges/<id>"` を `sceneryAssetName: "Scenery/<id>"` に置換（13 箇所）。

例:
```swift
.init(id: "tokyo", name: "東京", cumulativeKm: 0,
      mapPosition: .init(x: 0.78, y: 0.45),
      blurb: "旅のはじまり。日本橋を出発、東海道五十三次の起点。",
      sceneryAssetName: "Scenery/tokyo"),
```

- [ ] **Step 4: BadgesView.swift の参照更新**

`Features/Walk/BadgesView.swift` を Read してから、`badgeAssetName` の参照を `sceneryAssetName` に置換。`Badges/` 文字列リテラルがあれば `Scenery/` に。

- [ ] **Step 5: CelebrationOverlay.swift の参照更新**

`Features/Walk/CelebrationOverlay.swift` を Read してから同様の置換。

- [ ] **Step 6: 残存参照がないことを確認**

```bash
git grep -n "badgeAssetName"
git grep -n "Badges/"
```

Expected: 両方とも空（マッチなし）。

- [ ] **Step 7: ビルドが通ることを確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 8: 全テストが通ることを確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 全 PASS（リグレッションなし）

- [ ] **Step 9: コミット**

```bash
git add WorkoutTracker/Domain/JourneyRoute.swift \
        WorkoutTracker/Features/Walk/BadgesView.swift \
        WorkoutTracker/Features/Walk/CelebrationOverlay.swift \
        WorkoutTracker/Resources/Assets.xcassets/Scenery \
        WorkoutTracker.xcodeproj
git commit -m "♻️ Asset path を Badges/ → Scenery/、badgeAssetName → sceneryAssetName"
```

---

### Task 7: AppTab enum + RootView を TabView(selection:) 化

**Files:**
- Create: `WorkoutTracker/App/AppTab.swift`
- Modify: `WorkoutTracker/App/RootView.swift`

タブ切替を `@State` で制御可能にする。

- [ ] **Step 1: AppTab enum 作成**

`WorkoutTracker/App/AppTab.swift`:

```swift
import Foundation

enum AppTab: String, Hashable, CaseIterable {
    case home
    case recording
    case menu
    case history
    case walk
}
```

- [ ] **Step 2: RootView を改修**

`WorkoutTracker/App/RootView.swift` を全面置換:

```swift
import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(tabSelection: $selectedTab)
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(AppTab.home)
            RecordingView()
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
                .tag(AppTab.recording)
            MenuView()
                .tabItem { Label("メニュー", systemImage: "list.bullet") }
                .tag(AppTab.menu)
            HistoryView()
                .tabItem { Label("履歴", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.history)
            WalkView()
                .tabItem { Label("歩く", systemImage: "figure.walk") }
                .tag(AppTab.walk)
        }
    }
}

#Preview { RootView() }
```

注: `HomeView(tabSelection: $selectedTab)` は Task 14 の HomeView 改修で受けるため、このタイミングでは HomeView の init を一時的に空 binding 受けに修正する必要あり。次ステップ参照。

- [ ] **Step 3: HomeView の init に tabSelection パラメータを追加（暫定）**

`WorkoutTracker/Features/Home/HomeView.swift` の `struct HomeView: View` 直後（`@Environment` の前）に:

```swift
    @Binding var tabSelection: AppTab
```

`#Preview` ブロックの `HomeView()` を `HomeView(tabSelection: .constant(.home))` に変更。

- [ ] **Step 4: ビルドが通ることを確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`。タブアイコン「歩く 🚶」になっているはず。

- [ ] **Step 5: 全テスト実行**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 全 PASS

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/App/AppTab.swift \
        WorkoutTracker/App/RootView.swift \
        WorkoutTracker/Features/Home/HomeView.swift \
        WorkoutTracker.xcodeproj
git commit -m "🚶 AppTab enum 追加、RootView を TabView(selection:) 化、旅 → 歩く"
```

---

### Task 8: WalkView の navigationTitle を「歩く」に

**Files:**
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

- [ ] **Step 1: navigationTitle を変更**

`WalkView.swift` の `.navigationTitle("旅")` を `.navigationTitle("歩く")` に置換。

- [ ] **Step 2: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: コミット**

```bash
git add WorkoutTracker/Features/Walk/WalkView.swift
git commit -m "🚶 WalkView の navigationTitle を「歩く」に"
```

---

### Task 9: TimeOfDayScenery 作成（Image + gradient フォールバック）

**Files:**
- Create: `WorkoutTracker/Features/Walk/TimeOfDayScenery.swift`
- Delete: `WorkoutTracker/Features/Walk/TimeOfDayBackground.swift`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

イラストが投入される前でも gradient で動く構造。

- [ ] **Step 1: 既存 TimeOfDayBackground.swift を Read**

中身を確認して、gradient ロジックを TimeOfDayScenery にコピーする準備。

- [ ] **Step 2: TimeOfDayScenery.swift 作成**

`WorkoutTracker/Features/Walk/TimeOfDayScenery.swift`:

```swift
import SwiftUI

struct TimeOfDayScenery: View {
    let timeOfDay: TimeOfDay

    var body: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .background(gradient)
            .clipped()
    }

    private var assetName: String {
        switch timeOfDay {
        case .morning: "Scenery/morning"
        case .day:     "Scenery/day"
        case .evening: "Scenery/evening"
        case .night:   "Scenery/night"
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var gradientColors: [Color] {
        // 既存 TimeOfDayBackground の色を踏襲。Step 1 で確認した値を使用。
        switch timeOfDay {
        case .morning: [Color(red: 1.0, green: 0.85, blue: 0.7), Color(red: 1.0, green: 0.95, blue: 0.85)]
        case .day:     [Color(red: 0.6, green: 0.85, blue: 1.0), Color(red: 0.85, green: 0.95, blue: 1.0)]
        case .evening: [Color(red: 1.0, green: 0.6, blue: 0.5), Color(red: 0.7, green: 0.5, blue: 0.7)]
        case .night:   [Color(red: 0.15, green: 0.2, blue: 0.4), Color(red: 0.3, green: 0.35, blue: 0.55)]
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        TimeOfDayScenery(timeOfDay: .morning).frame(height: 100)
        TimeOfDayScenery(timeOfDay: .day).frame(height: 100)
        TimeOfDayScenery(timeOfDay: .evening).frame(height: 100)
        TimeOfDayScenery(timeOfDay: .night).frame(height: 100)
    }
}
```

注: Step 1 で確認した既存 gradient の色値を使う。違っていたら合わせる。

注: `Image(assetName)` で画像が見つからない場合 SwiftUI は空ビューを返すが、`.background(gradient)` があるので gradient が見える設計。

- [ ] **Step 3: WalkView の参照を TimeOfDayBackground → TimeOfDayScenery に置換**

`WorkoutTracker/Features/Walk/WalkView.swift` の:
```swift
TimeOfDayBackground(timeOfDay: timeOfDay)
```
を:
```swift
TimeOfDayScenery(timeOfDay: timeOfDay)
```
に置換。

- [ ] **Step 4: 旧 TimeOfDayBackground.swift を削除**

```bash
git rm WorkoutTracker/Features/Walk/TimeOfDayBackground.swift
```

- [ ] **Step 5: ビルド + テスト**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `BUILD SUCCEEDED` + 全テスト PASS

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Features/Walk/TimeOfDayScenery.swift \
        WorkoutTracker/Features/Walk/TimeOfDayBackground.swift \
        WorkoutTracker/Features/Walk/WalkView.swift \
        WorkoutTracker.xcodeproj
git commit -m "🎨 TimeOfDayBackground → TimeOfDayScenery（Image + gradient フォールバック）"
```

---

### Task 10: 画像生成パイプライン scaffold（uv + style_guide.md）

**Files:**
- Create: `scripts/illustrations/pyproject.toml`
- Create: `scripts/illustrations/style_guide.md`
- Create: `scripts/illustrations/.gitignore`
- Modify: `.tool-versions`
- Create: `.envrc.example`

- [ ] **Step 1: .tool-versions に python 追加**

既存の `xcodegen 2.43.0` の下に追記:

```
xcodegen 2.43.0
python 3.12.7
```

- [ ] **Step 2: scripts/illustrations/pyproject.toml 作成**

```toml
[project]
name = "illustrations"
version = "0.1.0"
description = "WorkoutTracker watercolor illustration generator (gpt-image-1)"
requires-python = ">=3.12"
dependencies = [
    "openai>=1.50.0",
    "pillow>=10.0.0",
]

[tool.uv]
package = false
```

- [ ] **Step 3: scripts/illustrations/.gitignore 作成**

```
.cache/
.venv/
__pycache__/
*.pyc
```

- [ ] **Step 4: scripts/illustrations/style_guide.md 作成**

```markdown
# 水彩イラストスタイルガイド

## 共通テイスト
- 水彩タッチ、パステル基調、人物なし、文字なし
- 紙の質感を残す、柔らかいエッジ
- ほのぼの・温かみのある雰囲気

## prompts.toml の `[style].suffix` で全件に付加する文言

```
soft watercolor illustration, gentle pastel palette, hand-painted texture,
warm and gentle atmosphere, no text, no people, slight paper grain
```

## 出力スペック
- サイズ: 1024x1024（正方形、SwiftUI で aspectRatio: .fill 表示）
- 形式: PNG
- 透明背景: 不要（風景なので背景色あり）

## 個別プロンプト指針
- **時間帯**（morning/day/evening/night）: 空・地平線中心、光の色味で時間帯を表現
- **チェックポイント** (13箇所): その土地を象徴する自然・建物・名物。観光ポスター風ではなく日常感
```

- [ ] **Step 5: .envrc.example 作成**

`/Users/takeruooyama/workspace/tqer39/workout-tracker/.claude/worktrees/ccw-tqer39-workout-tracker-260508-161751/.envrc.example`:

```sh
# OpenAI API key for scripts/illustrations/generate.py
# Copy this file to .envrc (gitignored) and fill in your key.
export OPENAI_API_KEY="sk-..."
```

- [ ] **Step 6: .gitignore に .envrc 追加**

`.gitignore` を Read して、`.envrc` を追加（既にあれば skip）。

- [ ] **Step 7: uv sync でセットアップ確認**

```bash
cd scripts/illustrations
uv sync
```

Expected: `.venv/` 作成、エラーなし。注: `mise install python` が先に必要かもしれない。

- [ ] **Step 8: コミット**

```bash
cd /Users/takeruooyama/workspace/tqer39/workout-tracker/.claude/worktrees/ccw-tqer39-workout-tracker-260508-161751
git add scripts/illustrations/ .tool-versions .envrc.example .gitignore
git commit -m "🐍 画像生成パイプライン scaffold（uv + style_guide.md + .envrc.example）"
```

---

### Task 11: prompts.toml に 17 件のプロンプト定義

**Files:**
- Create: `scripts/illustrations/prompts.toml`

- [ ] **Step 1: prompts.toml 作成**

```toml
[style]
suffix = "soft watercolor illustration, gentle pastel palette, hand-painted texture, warm and gentle atmosphere, no text, no people, slight paper grain"
size    = "1024x1024"
quality = "high"

# === 時間帯背景 (4枚) ===

[scenery.morning]
prompt = "A peaceful early morning sky over distant blue mountains, faint pink sunrise glow, soft clouds, calm horizon"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/morning.imageset/morning.png"

[scenery.day]
prompt = "A bright clear daytime sky, gentle white clouds, distant green hills, soft sunlight"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/day.imageset/day.png"

[scenery.evening]
prompt = "A warm sunset sky with orange and pink hues, silhouette of distant hills, golden light"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/evening.imageset/evening.png"

[scenery.night]
prompt = "A calm night sky with soft moonlight, gentle stars, distant dark blue mountains"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/night.imageset/night.png"

# === チェックポイント挿絵 (13枚) ===

[scenery.tokyo]
prompt = "Tokyo cityscape with Nihonbashi bridge silhouette and Tokyo Tower in distance, calm morning street view"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/tokyo.imageset/tokyo.png"

[scenery.yokohama]
prompt = "Yokohama harbor scene with red brick warehouses, gentle sea, distant ships"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/yokohama.imageset/yokohama.png"

[scenery.atami]
prompt = "Atami seaside hot spring town, gentle hills meeting the ocean, soft mist"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/atami.imageset/atami.png"

[scenery.shizuoka]
prompt = "Shizuoka tea fields with Mt. Fuji in the background, soft green rows, blue sky"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/shizuoka.imageset/shizuoka.png"

[scenery.hamamatsu]
prompt = "Hamamatsu Lake Hamana scene with gentle reeds and a small boat, soft horizon"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/hamamatsu.imageset/hamamatsu.png"

[scenery.nagoya]
prompt = "Nagoya Castle with golden shachihoko silhouette, surrounded by trees, soft sky"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/nagoya.imageset/nagoya.png"

[scenery.kyoto]
prompt = "Kyoto temple with cherry blossoms, traditional wooden roofs, gentle hills behind"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/kyoto.imageset/kyoto.png"

[scenery.osaka]
prompt = "Osaka Dotonbori area with traditional storefronts and soft river reflection, twilight"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/osaka.imageset/osaka.png"

[scenery.kobe]
prompt = "Kobe harbor at dusk with Port Tower silhouette, gentle hills with city lights"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/kobe.imageset/kobe.png"

[scenery.okayama]
prompt = "Kurashiki Bikan historical district with white-walled buildings and willow trees by canal"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/okayama.imageset/okayama.png"

[scenery.hiroshima]
prompt = "Itsukushima Shrine torii gate at low tide, soft sea, distant mountains"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/hiroshima.imageset/hiroshima.png"

[scenery.shimonoseki]
prompt = "Kanmon Strait view with the bridge silhouette, gentle sea, soft sky"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/shimonoseki.imageset/shimonoseki.png"

[scenery.hakata]
prompt = "Fukuoka Hakata yatai street food stalls along the river at dusk, lanterns glowing softly"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/hakata.imageset/hakata.png"
```

- [ ] **Step 2: コミット**

```bash
git add scripts/illustrations/prompts.toml
git commit -m "🎨 17 件の水彩イラストプロンプトを定義"
```

---

### Task 12: generate.py（dry-run まで含む）

**Files:**
- Create: `scripts/illustrations/generate.py`

- [ ] **Step 1: generate.py 作成**

```python
#!/usr/bin/env python3
"""Generate watercolor illustrations for WorkoutTracker via OpenAI gpt-image-1."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
PROMPTS_FILE = SCRIPT_DIR / "prompts.toml"
CACHE_DIR = SCRIPT_DIR / ".cache"


@dataclass
class IllustrationSpec:
    name: str
    prompt: str
    output: Path
    size: str
    quality: str

    @property
    def cache_key(self) -> str:
        h = hashlib.sha256()
        h.update(self.prompt.encode("utf-8"))
        h.update(self.size.encode("utf-8"))
        h.update(self.quality.encode("utf-8"))
        return h.hexdigest()[:16]

    @property
    def cache_marker(self) -> Path:
        return CACHE_DIR / f"{self.name}-{self.cache_key}.done"


def load_specs() -> list[IllustrationSpec]:
    with open(PROMPTS_FILE, "rb") as f:
        data = tomllib.load(f)

    style = data["style"]
    suffix = style["suffix"]
    size = style["size"]
    quality = style["quality"]

    specs: list[IllustrationSpec] = []
    for name, entry in data["scenery"].items():
        full_prompt = f"{entry['prompt']}, {suffix}"
        output = REPO_ROOT / entry["output"]
        specs.append(IllustrationSpec(
            name=name,
            prompt=full_prompt,
            output=output,
            size=size,
            quality=quality,
        ))
    return specs


def filter_specs(specs: list[IllustrationSpec], names: list[str] | None) -> list[IllustrationSpec]:
    if not names:
        return specs
    keep = set(names)
    return [s for s in specs if s.name in keep]


def write_contents_json(image_path: Path) -> None:
    """imageset/Contents.json を作る（scale: 1x のみ）"""
    contents = {
        "images": [{"idiom": "universal", "filename": image_path.name, "scale": "1x"}],
        "info": {"version": 1, "author": "xcode"},
    }
    contents_path = image_path.parent / "Contents.json"
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def generate_one(spec: IllustrationSpec, *, force: bool, dry_run: bool) -> str:
    """戻り値: 'generated' / 'cached' / 'dry-run'"""
    if dry_run:
        print(f"[dry-run] {spec.name}")
        print(f"  prompt: {spec.prompt}")
        print(f"  output: {spec.output}")
        return "dry-run"

    if not force and spec.cache_marker.exists() and spec.output.exists():
        print(f"[cached]  {spec.name}")
        return "cached"

    from openai import OpenAI
    client = OpenAI()

    print(f"[generate] {spec.name}...")
    result = client.images.generate(
        model="gpt-image-1",
        prompt=spec.prompt,
        size=spec.size,
        quality=spec.quality,
    )
    b64 = result.data[0].b64_json
    if b64 is None:
        raise RuntimeError(f"No b64_json returned for {spec.name}")
    image_bytes = base64.b64decode(b64)

    spec.output.parent.mkdir(parents=True, exist_ok=True)
    spec.output.write_bytes(image_bytes)
    write_contents_json(spec.output)

    CACHE_DIR.mkdir(exist_ok=True)
    spec.cache_marker.write_text(spec.prompt + "\n")

    print(f"  → {spec.output}")
    return "generated"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate watercolor illustrations")
    parser.add_argument("--dry-run", action="store_true", help="プロンプトを print して API 呼ばず終了")
    parser.add_argument("--force", action="store_true", help="キャッシュを無視して再生成")
    parser.add_argument("--filter", type=str, default=None, help="カンマ区切りの name 部分指定")
    args = parser.parse_args()

    if not args.dry_run and not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY が未設定。.envrc を確認するか --dry-run を使う。", file=sys.stderr)
        return 1

    specs = load_specs()
    names = [n.strip() for n in args.filter.split(",")] if args.filter else None
    specs = filter_specs(specs, names)

    if not specs:
        print("該当する spec がない。")
        return 0

    counts = {"generated": 0, "cached": 0, "dry-run": 0}
    for spec in specs:
        result = generate_one(spec, force=args.force, dry_run=args.dry_run)
        counts[result] = counts.get(result, 0) + 1

    print(f"\n結果: generated={counts['generated']}, cached={counts['cached']}, dry-run={counts['dry-run']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 実行権限付与**

```bash
chmod +x scripts/illustrations/generate.py
```

- [ ] **Step 3: dry-run で全件出力確認**

```bash
cd scripts/illustrations
uv run python generate.py --dry-run
```

Expected: 17 件の `[dry-run]` 行が出力、各プロンプトと出力パスが見える。

- [ ] **Step 4: --filter の動作確認**

```bash
uv run python generate.py --dry-run --filter tokyo,kyoto
```

Expected: 2 件のみ出力。

- [ ] **Step 5: コミット**

```bash
cd /Users/takeruooyama/workspace/tqer39/workout-tracker/.claude/worktrees/ccw-tqer39-workout-tracker-260508-161751
git add scripts/illustrations/generate.py
git commit -m "🐍 generate.py 実装（gpt-image-1, --dry-run / --filter / --force / キャッシュ対応）"
```

---

### Task 13: イラスト生成・投入（手動実行 + コミット）

**Files:**
- Create: 17 PNGs + 17 Contents.json under `WorkoutTracker/Resources/Assets.xcassets/Scenery/`

注: このタスクは外部 API を叩くので、`OPENAI_API_KEY` が必要。コストは推定 $3〜7。

- [ ] **Step 1: API キーを設定**

ターミナルで（`.envrc` を作るなり一時的に export するなり）:

```bash
export OPENAI_API_KEY="sk-..."
```

- [ ] **Step 2: 全件生成**

```bash
cd scripts/illustrations
uv run python generate.py
```

Expected: 17 件 `[generate]`、`Scenery/<id>.imageset/<id>.png` と `Contents.json` が作られる。

- [ ] **Step 3: 目視チェック**

```bash
open WorkoutTracker/Resources/Assets.xcassets/Scenery/morning.imageset/morning.png
# 同様に day, evening, night, tokyo, ..., hakata を確認
```

水彩感が統一されていない、または期待と大きく違うものがあれば --force --filter <name> で再生成。

- [ ] **Step 4: 必要なら個別再生成**

```bash
uv run python generate.py --force --filter <name1>,<name2>
```

- [ ] **Step 5: ビルドが通ることを確認（イラスト投入後）**

```bash
cd /Users/takeruooyama/workspace/tqer39/workout-tracker/.claude/worktrees/ccw-tqer39-workout-tracker-260508-161751
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: シミュレータで歩くタブを目視確認**

Xcode から実行して、歩くタブで時間帯背景がイラストになっていることを確認。

- [ ] **Step 7: コミット**

```bash
git add WorkoutTracker/Resources/Assets.xcassets/Scenery
git commit -m "🎨 水彩イラスト 17 枚（時間帯 4 + チェックポイント 13）を投入"
```

---

### Task 14: CompanionLineFilter struct + テスト

**Files:**
- Create: `WorkoutTracker/Domain/CompanionLineFilter.swift`
- Create: `WorkoutTrackerTests/DomainTests/CompanionLineFilterTests.swift`

- [ ] **Step 1: テストファイル作成**

`WorkoutTrackerTests/DomainTests/CompanionLineFilterTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class CompanionLineFilterTests: XCTestCase {
    func test_distanceBand_early() {
        XCTAssertEqual(DistanceBand.from(progress: 0.0), .early)
        XCTAssertEqual(DistanceBand.from(progress: 0.29), .early)
    }

    func test_distanceBand_mid() {
        XCTAssertEqual(DistanceBand.from(progress: 0.30), .mid)
        XCTAssertEqual(DistanceBand.from(progress: 0.69), .mid)
    }

    func test_distanceBand_late() {
        XCTAssertEqual(DistanceBand.from(progress: 0.70), .late)
        XCTAssertEqual(DistanceBand.from(progress: 1.0), .late)
    }

    func test_streakBand_firstDay() {
        XCTAssertEqual(StreakBand.from(streakDays: 0), .firstDay)
        XCTAssertEqual(StreakBand.from(streakDays: 1), .firstDay)
    }

    func test_streakBand_threeDay() {
        XCTAssertEqual(StreakBand.from(streakDays: 3), .threeDay)
        XCTAssertEqual(StreakBand.from(streakDays: 6), .threeDay)
    }

    func test_streakBand_oneWeek() {
        XCTAssertEqual(StreakBand.from(streakDays: 7), .oneWeek)
        XCTAssertEqual(StreakBand.from(streakDays: 29), .oneWeek)
    }

    func test_streakBand_oneMonthPlus() {
        XCTAssertEqual(StreakBand.from(streakDays: 30), .oneMonthPlus)
    }

    func test_filter_matchesWildcardOnNil() {
        let filter = CompanionLineFilter(
            progress: .achieved,
            timeOfDay: .morning,
            streak: .threeDay,
            distance: .mid
        )
        let line = CompanionLine(
            text: "test",
            progress: nil,        // wildcard
            timeOfDay: nil,
            streak: nil,
            distance: nil
        )
        XCTAssertTrue(filter.matches(line))
    }

    func test_filter_rejectsOnExplicitMismatch() {
        let filter = CompanionLineFilter(
            progress: .achieved,
            timeOfDay: .morning,
            streak: .threeDay,
            distance: .mid
        )
        let line = CompanionLine(
            text: "test",
            progress: [.unmet],   // mismatch
            timeOfDay: nil,
            streak: nil,
            distance: nil
        )
        XCTAssertFalse(filter.matches(line))
    }

    func test_filter_acceptsOnArrayContains() {
        let filter = CompanionLineFilter(
            progress: .achieved,
            timeOfDay: .morning,
            streak: .threeDay,
            distance: .mid
        )
        let line = CompanionLine(
            text: "test",
            progress: [.achieved, .completed],   // 配列に含まれる
            timeOfDay: [.morning, .day],
            streak: nil,
            distance: nil
        )
        XCTAssertTrue(filter.matches(line))
    }
}
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/DomainTests/CompanionLineFilterTests
```

Expected: FAIL（型未定義）

- [ ] **Step 3: 実装ファイル作成**

`WorkoutTracker/Domain/CompanionLineFilter.swift`:

```swift
import Foundation

enum ProgressBand: String, Codable, Hashable {
    case unmet
    case achieved
    case completed
}

enum DistanceBand: String, Codable, Hashable {
    case early
    case mid
    case late

    static func from(progress: Double) -> DistanceBand {
        switch progress {
        case ..<0.30: return .early
        case ..<0.70: return .mid
        default:      return .late
        }
    }
}

enum StreakBand: String, Codable, Hashable {
    case firstDay
    case threeDay
    case oneWeek
    case oneMonthPlus

    static func from(streakDays: Int) -> StreakBand {
        switch streakDays {
        case ..<3:   return .firstDay
        case ..<7:   return .threeDay
        case ..<30:  return .oneWeek
        default:     return .oneMonthPlus
        }
    }
}

struct CompanionLine: Codable, Hashable {
    let text: String
    let progress: [ProgressBand]?
    let timeOfDay: [TimeOfDay]?
    let streak: [StreakBand]?
    let distance: [DistanceBand]?
}

struct CompanionLineFilter {
    let progress: ProgressBand
    let timeOfDay: TimeOfDay
    let streak: StreakBand
    let distance: DistanceBand

    func matches(_ line: CompanionLine) -> Bool {
        if let p = line.progress,    !p.contains(progress) { return false }
        if let t = line.timeOfDay,   !t.contains(timeOfDay) { return false }
        if let s = line.streak,      !s.contains(streak) { return false }
        if let d = line.distance,    !d.contains(distance) { return false }
        return true
    }
}
```

注: `TimeOfDay` enum は既存。`Codable` 適合が無ければ別途 extension で追加する必要あり（次ステップで判明）。

- [ ] **Step 4: TimeOfDay の Codable 適合（必要なら）**

`WorkoutTracker/Models/Enums.swift` を Read して、`TimeOfDay` enum を確認。`Codable` 未対応なら:

```swift
extension TimeOfDay: Codable {}
```

を `Domain/CompanionLineFilter.swift` の末尾に追加。`String` rawValue があれば自動 Codable 適合。

- [ ] **Step 5: ビルド + テスト**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/DomainTests/CompanionLineFilterTests
```

Expected: 10 件すべて PASS

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Domain/CompanionLineFilter.swift \
        WorkoutTrackerTests/DomainTests/CompanionLineFilterTests.swift \
        WorkoutTracker.xcodeproj
git commit -m "💬 CompanionLineFilter と各 Band enum を追加"
```

---

### Task 15: CompanionLines.json + CompanionDialog 改修

**Files:**
- Create: `WorkoutTracker/Resources/CompanionLines.json`
- Modify: `WorkoutTracker/Domain/CompanionDialog.swift`
- Modify: `WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift`

注: 200 件の文言は LLM で別途量産する想定。Phase 7 完了時にスケルトン JSON のみ投入し、運用で増やす。

- [ ] **Step 1: CompanionLines.json をスケルトンで作成**

`WorkoutTracker/Resources/CompanionLines.json`:

```json
{
  "lines": [
    { "text": "おはよう。今日もぼちぼちいこう。", "progress": ["unmet"], "timeOfDay": ["morning"], "streak": null, "distance": null },
    { "text": "おはよう。少しずつでいいよ。", "progress": ["unmet"], "timeOfDay": ["morning"], "streak": null, "distance": null },
    { "text": "今日もいいペースだね。", "progress": ["unmet"], "timeOfDay": ["day"], "streak": null, "distance": null },
    { "text": "夕方のひと歩きで距離を稼ごう。", "progress": ["unmet"], "timeOfDay": ["evening"], "streak": null, "distance": null },
    { "text": "今日はもう少しだけ。", "progress": ["unmet"], "timeOfDay": ["night"], "streak": null, "distance": null },
    { "text": "今日の目標達成！えらい！", "progress": ["achieved"], "timeOfDay": null, "streak": null, "distance": null },
    { "text": "目標クリア。ご褒美時間にしよ。", "progress": ["achieved"], "timeOfDay": null, "streak": null, "distance": null },
    { "text": "目標達成、いい流れだね。", "progress": ["achieved"], "timeOfDay": null, "streak": null, "distance": null },
    { "text": "ついに博多到着！本当におつかれさま。", "progress": ["completed"], "timeOfDay": null, "streak": null, "distance": null },
    { "text": "完走おめでとう！次の旅も楽しみだね。", "progress": ["completed"], "timeOfDay": null, "streak": null, "distance": null },
    { "text": "1,150 km をその足で踏破。すごいことだよ。", "progress": ["completed"], "timeOfDay": null, "streak": null, "distance": null },
    { "text": "3日続いてる。リズムができてきた。", "progress": null, "timeOfDay": null, "streak": ["threeDay"], "distance": null },
    { "text": "1週間続いた。大したもんだ。", "progress": null, "timeOfDay": null, "streak": ["oneWeek"], "distance": null },
    { "text": "1ヶ月以上続いてる。本物だね。", "progress": null, "timeOfDay": null, "streak": ["oneMonthPlus"], "distance": null },
    { "text": "旅の序盤、これからが楽しみ。", "progress": ["unmet", "achieved"], "timeOfDay": null, "streak": null, "distance": ["early"] },
    { "text": "ちょうど中盤。半分はもうすぐ。", "progress": ["unmet", "achieved"], "timeOfDay": null, "streak": null, "distance": ["mid"] },
    { "text": "ゴールが見えてきた。あとひとふんばり。", "progress": ["unmet", "achieved"], "timeOfDay": null, "streak": null, "distance": ["late"] }
  ]
}
```

注: 17 件のみのスケルトン。運用で 200 件以上に拡張する。

- [ ] **Step 2: project.yml の resources に CompanionLines.json を含める**

`project.yml` の `resources` を確認:

```yaml
    resources:
      - path: WorkoutTracker/Resources/Assets.xcassets
```

を以下に変更:

```yaml
    resources:
      - path: WorkoutTracker/Resources/Assets.xcassets
      - path: WorkoutTracker/Resources/CompanionLines.json
```

- [ ] **Step 3: CompanionDialog.swift を改修**

`WorkoutTracker/Domain/CompanionDialog.swift` を全面置換:

```swift
import Foundation

enum CompanionDialog {
    static func line(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        streakDays: Int,
        lastShown: String?
    ) -> String {
        let filter = makeFilter(
            progress: progress,
            todaySteps: todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
            streakDays: streakDays
        )

        let candidates = loadedLines
            .filter { filter.matches($0) }
            .map(\.text)

        let pool = candidates.isEmpty ? fallbackPool(filter: filter) : candidates
        let pickFrom = pool.filter { $0 != lastShown }
        let final = pickFrom.isEmpty ? pool : pickFrom
        return final.randomElement() ?? "今日もぼちぼちいこう。"
    }

    private static func makeFilter(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        streakDays: Int
    ) -> CompanionLineFilter {
        let progressBand: ProgressBand = {
            if progress.isCompleted { return .completed }
            if todaySteps >= dailyGoal { return .achieved }
            return .unmet
        }()
        let distanceFraction = JourneyRoute.totalKm > 0
            ? min(1.0, progress.completedMeters / 1000.0 / JourneyRoute.totalKm)
            : 0
        return CompanionLineFilter(
            progress: progressBand,
            timeOfDay: timeOfDay,
            streak: StreakBand.from(streakDays: streakDays),
            distance: DistanceBand.from(progress: distanceFraction)
        )
    }

    // MARK: - Loading

    private static let loadedLines: [CompanionLine] = {
        guard let url = Bundle.main.url(forResource: "CompanionLines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(CompanionLinesPayload.self, from: data) else {
            return []
        }
        return payload.lines
    }()

    private struct CompanionLinesPayload: Codable {
        let lines: [CompanionLine]
    }

    // MARK: - Fallback

    private static func fallbackPool(filter: CompanionLineFilter) -> [String] {
        switch filter.progress {
        case .completed:
            return [
                "ついに博多到着！本当におつかれさま。",
                "完走おめでとう！次の旅も楽しみだね。",
            ]
        case .achieved:
            return [
                "今日の目標達成！えらい！",
                "目標クリア。ご褒美時間にしよ。",
            ]
        case .unmet:
            return [
                "今日もぼちぼちいこう。",
                "ゆっくりでいいよ、続けることが大事。",
            ]
        }
    }
}
```

注: 既存の `CompanionDialog.line(...)` 呼び出し側（WalkView, HomeView）は引数が増えたので Task 16 / 17 で更新する。中間期間として WalkView の参照を確認:

`grep -rn "CompanionDialog.line" WorkoutTracker/`

呼び出し箇所を Step 4 で修正する。

- [ ] **Step 4: 既存呼び出し箇所の修正**

WalkView.swift の `CompanionDialog.line(...)` 呼び出しを更新:

```swift
private var companionLine: String {
    CompanionDialog.line(
        progress: journey.progress,
        todaySteps: journey.todaySteps,
        dailyGoal: dailyGoal,
        timeOfDay: timeOfDay,
        streakDays: journey.currentStreakDays,
        lastShown: lastCompanionLine
    )
}
```

注: `journey.currentStreakDays` は `JourneyService` に既に存在しているか要確認。`grep -n "currentStreak" WorkoutTracker/Services/JourneyService.swift`。なければ Step 5 で追加。

- [ ] **Step 5: JourneyService に currentStreakDays が無ければ追加**

`WorkoutTracker/Services/JourneyService.swift` を Read。既存に `streak` 系のプロパティ/メソッドがあれば再利用。なければ:

```swift
@MainActor
var currentStreakDays: Int {
    StreakCalculator.streakDays(records: stepHistory, goal: dailyGoal)
}
```

を追加。`StreakCalculator` は既存（`Domain/StreakCalculator.swift`）。

- [ ] **Step 6: 既存の CompanionDialogTests を更新**

`WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift` を確認。新シグネチャに合わせて呼び出しを修正、`streakDays:` を渡すよう変更。

例:
```swift
let line = CompanionDialog.line(
    progress: progress,
    todaySteps: 5000,
    dailyGoal: 8000,
    timeOfDay: .morning,
    streakDays: 0,
    lastShown: nil
)
XCTAssertFalse(line.isEmpty)
```

加えて、JSON ロード失敗時に fallback が動くテストを追加:

```swift
func test_line_fallbackWhenJSONMissing_returnsNonEmpty() {
    // CompanionLines.json はバンドルに含まれているが、loadedLines が空でも fallback で返ること
    // 実装の private 性により直接検証は困難。最低限、関数が空文字を返さないことを確認。
    let progress = JourneyProgress(completedMeters: 0, nextCheckpoint: nil, isCompleted: false, metersToNext: 0)
    let line = CompanionDialog.line(
        progress: progress,
        todaySteps: 0,
        dailyGoal: 8000,
        timeOfDay: .morning,
        streakDays: 0,
        lastShown: nil
    )
    XCTAssertFalse(line.isEmpty)
}
```

- [ ] **Step 7: ビルド + テスト**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 全 PASS

- [ ] **Step 8: コミット**

```bash
git add WorkoutTracker/Resources/CompanionLines.json \
        WorkoutTracker/Domain/CompanionDialog.swift \
        WorkoutTracker/Features/Walk/WalkView.swift \
        WorkoutTracker/Services/JourneyService.swift \
        WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift \
        project.yml \
        WorkoutTracker.xcodeproj
git commit -m "💬 CompanionLines.json と CompanionDialog の filter 化"
```

---

### Task 16: StubHealthKitService + JourneyService.preview helper

**Files:**
- Create: `WorkoutTracker/TestSupport/StubHealthKitService.swift`
- Create: `WorkoutTracker/TestSupport/JourneyServicePreview.swift`

- [ ] **Step 1: StubHealthKitService.swift 作成**

まず HealthKit プロトコル確認:

```bash
grep -n "protocol .*HealthKit\|class LiveHealthKit\|HealthKitService" WorkoutTracker/Services/HealthKitService.swift
```

既存の HealthKit プロトコル / クラスを確認した上で、それに準拠したスタブを書く。

`WorkoutTracker/TestSupport/StubHealthKitService.swift`:

```swift
import Foundation

#if DEBUG
final class StubHealthKitService: HealthKitServicing {  // 既存プロトコル名に合わせる
    var stubbedTodaySteps: Int = Fixtures.Steps.representative

    func authorize() async throws { /* no-op */ }

    func todayStepCount() async throws -> Int {
        stubbedTodaySteps
    }

    func dailyStepCounts(daysBack: Int) async throws -> [(date: Date, count: Int)] {
        Fixtures.varietyWeek.enumerated().map { i, n in
            (date: DateHelpers.daysAgo(i), count: n)
        }
    }
}
#endif
```

注: 実プロトコル名（`HealthKitServicing` 等）と method シグネチャは `WorkoutTracker/Services/HealthKitService.swift` に合わせる。

- [ ] **Step 2: JourneyServicePreview.swift 作成**

`WorkoutTracker/TestSupport/JourneyServicePreview.swift`:

```swift
import Foundation
import SwiftData

#if DEBUG
extension JourneyService {
    @MainActor
    static var preview: JourneyService {
        let container = (try? InMemoryContainer.make()) ?? ModelContainerFactory.makeShared()
        return JourneyService(
            healthKit: StubHealthKitService(),
            container: container
        )
    }
}
#endif
```

注: テストターゲット内の `InMemoryContainer.make()` は `@testable import` 必須。main ターゲットからは見えない。代わりに直接 `ModelContainer` を作るか、`ModelContainerFactory` 内に preview helper を作る。

代替実装:

```swift
#if DEBUG
extension JourneyService {
    @MainActor
    static var preview: JourneyService {
        let schema = Schema([
            Exercise.self, WorkoutTemplate.self, TemplateExercise.self,
            WorkoutSession.self, SetRecord.self, BodyMetric.self,
            StepDailyRecord.self, CheckpointAchievement.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = (try? ModelContainer(for: schema, configurations: [config]))
            ?? ModelContainerFactory.makeShared()
        return JourneyService(
            healthKit: StubHealthKitService(),
            container: container
        )
    }
}
#endif
```

- [ ] **Step 3: ビルド確認**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/TestSupport/StubHealthKitService.swift \
        WorkoutTracker/TestSupport/JourneyServicePreview.swift \
        WorkoutTracker.xcodeproj
git commit -m "🧪 StubHealthKitService と JourneyService.preview helper を追加"
```

---

### Task 17: StepHeroCard コンポーネント

**Files:**
- Create: `WorkoutTracker/Features/Home/StepHeroCard.swift`
- Create: `WorkoutTrackerTests/FeaturesTests/StepHeroCardLogicTests.swift`

- [ ] **Step 1: テストファイル作成**

`WorkoutTrackerTests/FeaturesTests/StepHeroCardLogicTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class StepHeroCardLogicTests: XCTestCase {
    func test_progressFraction_zero() {
        XCTAssertEqual(StepHeroCard.progressFraction(steps: 0, goal: 8000), 0.0, accuracy: 0.001)
    }

    func test_progressFraction_half() {
        XCTAssertEqual(StepHeroCard.progressFraction(steps: 4000, goal: 8000), 0.5, accuracy: 0.001)
    }

    func test_progressFraction_complete() {
        XCTAssertEqual(StepHeroCard.progressFraction(steps: 8000, goal: 8000), 1.0, accuracy: 0.001)
    }

    func test_progressFraction_overflow_capsAt1() {
        XCTAssertEqual(StepHeroCard.progressFraction(steps: 12_000, goal: 8000), 1.0, accuracy: 0.001)
    }

    func test_progressFraction_zeroGoal_returnsZero() {
        XCTAssertEqual(StepHeroCard.progressFraction(steps: 5000, goal: 0), 0.0, accuracy: 0.001)
    }

    func test_progressPercent_zero() {
        XCTAssertEqual(StepHeroCard.progressPercent(steps: 0, goal: 8000), 0)
    }

    func test_progressPercent_overflow_canExceed100() {
        XCTAssertEqual(StepHeroCard.progressPercent(steps: 12_000, goal: 8000), 150)
    }
}
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/FeaturesTests/StepHeroCardLogicTests
```

Expected: FAIL（StepHeroCard 未定義）

- [ ] **Step 3: 実装ファイル作成**

`WorkoutTracker/Features/Home/StepHeroCard.swift`:

```swift
import SwiftUI

struct StepHeroCard: View {
    let steps: Int
    let goal: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(steps)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("歩")
                    .font(.title3).foregroundStyle(.secondary)
            }
            ProgressView(value: Self.progressFraction(steps: steps, goal: goal))
                .progressViewStyle(.linear)
                .tint(.orange)
            HStack {
                Text("目標 \(goal) 歩")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Self.progressPercent(steps: steps, goal: goal)) %")
                    .font(.caption).bold()
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    static func progressFraction(steps: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0.0 }
        return min(1.0, Double(steps) / Double(goal))
    }

    static func progressPercent(steps: Int, goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return Int((Double(steps) / Double(goal) * 100).rounded())
    }
}

#Preview {
    VStack(spacing: 16) {
        StepHeroCard(steps: 0, goal: 8000)
        StepHeroCard(steps: 4000, goal: 8000)
        StepHeroCard(steps: 8500, goal: 8000)
    }
    .padding()
}
```

- [ ] **Step 4: ビルド + テスト**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/FeaturesTests/StepHeroCardLogicTests
```

Expected: 7 件すべて PASS

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Home/StepHeroCard.swift \
        WorkoutTrackerTests/FeaturesTests/StepHeroCardLogicTests.swift \
        WorkoutTracker.xcodeproj
git commit -m "🏠 StepHeroCard コンポーネントを追加（歩数 + 進捗バー）"
```

---

### Task 18: JourneyMiniCard コンポーネント

**Files:**
- Create: `WorkoutTracker/Features/Home/JourneyMiniCard.swift`
- Create: `WorkoutTrackerTests/FeaturesTests/JourneyMiniCardLogicTests.swift`

- [ ] **Step 1: テストファイル作成**

`WorkoutTrackerTests/FeaturesTests/JourneyMiniCardLogicTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class JourneyMiniCardLogicTests: XCTestCase {
    func test_summary_completed() {
        let progress = JourneyProgress(completedMeters: 1_150_000, nextCheckpoint: nil,
                                       isCompleted: true, metersToNext: 0)
        XCTAssertEqual(JourneyMiniCard.summary(progress: progress), "博多に到着！")
    }

    func test_summary_inProgress() {
        let nextCp = JourneyRoute.tokyoToHakata.first { $0.id == "nagoya" }!
        let progress = JourneyProgress(
            completedMeters: 350_000,
            nextCheckpoint: nextCp,
            isCompleted: false,
            metersToNext: 15_000
        )
        XCTAssertEqual(JourneyMiniCard.summary(progress: progress), "次: 名古屋 まで 15.0 km")
    }

    func test_summary_noNextCheckpoint() {
        let progress = JourneyProgress(completedMeters: 0, nextCheckpoint: nil,
                                       isCompleted: false, metersToNext: 0)
        XCTAssertEqual(JourneyMiniCard.summary(progress: progress), "旅のはじまり")
    }
}
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/FeaturesTests/JourneyMiniCardLogicTests
```

Expected: FAIL

- [ ] **Step 3: 実装ファイル作成**

`WorkoutTracker/Features/Home/JourneyMiniCard.swift`:

```swift
import SwiftUI

struct JourneyMiniCard: View {
    let progress: JourneyProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("旅")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(Self.summary(progress: progress))
                        .font(.subheadline).bold().foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    static func summary(progress: JourneyProgress) -> String {
        if progress.isCompleted { return "博多に到着！" }
        guard let next = progress.nextCheckpoint else { return "旅のはじまり" }
        let km = String(format: "%.1f", progress.metersToNext / 1000.0)
        return "次: \(next.name) まで \(km) km"
    }
}

#Preview {
    let nagoya = JourneyRoute.tokyoToHakata.first { $0.id == "nagoya" }!
    let progress = JourneyProgress(
        completedMeters: 350_000, nextCheckpoint: nagoya,
        isCompleted: false, metersToNext: 15_000
    )
    return JourneyMiniCard(progress: progress) { }
        .padding()
}
```

注: `JourneyProgress` のイニシャライザシグネチャは既存と合わせる。`completedMeters` ではなく別名なら修正。

- [ ] **Step 4: ビルド + テスト**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests/FeaturesTests/JourneyMiniCardLogicTests
```

Expected: 3 件 PASS

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Home/JourneyMiniCard.swift \
        WorkoutTrackerTests/FeaturesTests/JourneyMiniCardLogicTests.swift \
        WorkoutTracker.xcodeproj
git commit -m "🏠 JourneyMiniCard コンポーネントを追加（旅進捗ミニサマリ + タップで遷移）"
```

---

### Task 19: HomeView を ScrollView + LazyVStack に再構成

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`

最大の改修。上半分 = Walk Hero、下半分 = 筋トレサマリ。

- [ ] **Step 1: 既存 HomeView.swift をバックアップ表示**

Read してから、以下に全面置換する。

- [ ] **Step 2: 全面置換**

`WorkoutTracker/Features/Home/HomeView.swift`:

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var tabSelection: AppTab
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    @State private var lastCompanionLine: String?

    private var timeOfDay: TimeOfDay { .from(Date()) }

    private var companionLine: String {
        CompanionDialog.line(
            progress: journey.progress,
            todaySteps: journey.todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
            streakDays: journey.currentStreakDays,
            lastShown: lastCompanionLine
        )
    }

    private var companionMood: CompanionBubble.Mood {
        if journey.progress.isCompleted { return .celebrate }
        if journey.todaySteps >= dailyGoal { return .cheer }
        return .neutral
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    walkHero
                    weekSummaryCard
                    if let last = sessions.first {
                        recentSessionCard(last)
                    }
                    if let latest = metrics.first {
                        latestMetricsCard(latest)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("ホーム")
            .onAppear { lastCompanionLine = companionLine }
        }
    }

    // MARK: - Walk Hero (上半分)

    private var walkHero: some View {
        ZStack(alignment: .top) {
            TimeOfDayScenery(timeOfDay: timeOfDay)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            VStack(spacing: 12) {
                CompanionBubble(line: companionLine, mood: companionMood)
                    .padding(.horizontal)
                StepHeroCard(steps: journey.todaySteps, goal: dailyGoal)
                    .padding(.horizontal)
                JourneyMiniCard(progress: journey.progress) {
                    tabSelection = .walk
                }
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - 筋トレサマリ (下半分)

    private var weekSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今週のサマリ").font(.headline)
            HStack {
                SummaryTile(title: "セッション", value: "\(weekSessions.count)")
                SummaryTile(title: "総ボリューム", value: "\(Int(weekVolume.rounded())) kg")
                SummaryTile(title: "セット", value: "\(weekSets)")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func recentSessionCard(_ session: WorkoutSession) -> some View {
        NavigationLink {
            SessionDetailView(session: session)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("直近のセッション").font(.headline).foregroundStyle(.primary)
                Text(session.startedAt, style: .date)
                    .font(.subheadline).foregroundStyle(.primary)
                Text("\(session.sets.count) セット")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func latestMetricsCard(_ metric: BodyMetric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("最新の体組成").font(.headline)
            HStack {
                if let w = metric.weightKg {
                    Text("\(String(format: "%.1f", w)) kg").font(.title3)
                }
                Spacer()
                if let f = metric.bodyFatPercent {
                    Text("\(String(format: "%.1f", f)) %").foregroundStyle(.secondary)
                }
                Text(metric.recordedAt, style: .date)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 計算プロパティ

    private var weekSessions: [WorkoutSession] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startedAt >= start }
    }

    private var weekSets: Int {
        weekSessions.reduce(0) { $0 + $1.sets.count }
    }

    private var weekVolume: Double {
        let allSets = weekSessions.flatMap(\.sets)
        return WorkoutMetrics.totalVolume(sets: allSets.map {
            .init(weightKg: $0.weightKg, reps: $0.reps)
        })
    }
}

struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("中盤") {
    HomeView(tabSelection: .constant(.home))
        .modelContainer(try! InMemoryContainer.seeded { ctx in
            Fixtures.varietyWeek.enumerated().forEach { i, n in
                ctx.insert(Fixtures.stepRecord(n, daysAgo: i))
            }
            Fixtures.midJourneyAchievements().forEach { ctx.insert($0) }
        })
        .environment(JourneyService.preview)
}
#endif
```

注: `InMemoryContainer` は `WorkoutTrackerTests/` に居るので main ターゲットの Preview からは見えない。Preview を動かすには `InMemoryContainer.make()` 相当を main の `#if DEBUG` に切り出す必要あり。次ステップ参照。

- [ ] **Step 3: PreviewContainer.swift を main に追加**

`WorkoutTracker/TestSupport/PreviewContainer.swift`:

```swift
import Foundation
import SwiftData

#if DEBUG
@MainActor
enum PreviewContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
            StepDailyRecord.self,
            CheckpointAchievement.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func seeded(_ build: (ModelContext) -> Void) throws -> ModelContainer {
        let container = try make()
        build(container.mainContext)
        try container.mainContext.save()
        return container
    }
}
#endif
```

HomeView の `#Preview` ブロックの `InMemoryContainer.seeded` を `PreviewContainer.seeded` に置換:

```swift
#Preview("中盤") {
    HomeView(tabSelection: .constant(.home))
        .modelContainer(try! PreviewContainer.seeded { ctx in
            Fixtures.varietyWeek.enumerated().forEach { i, n in
                ctx.insert(Fixtures.stepRecord(n, daysAgo: i))
            }
            Fixtures.midJourneyAchievements().forEach { ctx.insert($0) }
        })
        .environment(JourneyService.preview)
}
```

- [ ] **Step 4: ビルド + 全テスト**

```bash
xcodegen generate
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `BUILD SUCCEEDED` + 全テスト PASS

- [ ] **Step 5: シミュレータで目視確認**

Xcode から Run → ホームタブの上半分が Walk Hero、下半分がカード3つ、ミニカードタップで歩くタブへジャンプすることを確認。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Features/Home/HomeView.swift \
        WorkoutTracker/TestSupport/PreviewContainer.swift \
        WorkoutTracker.xcodeproj
git commit -m "🏠 HomeView を ScrollView + LazyVStack に再構成（Walk Hero + 筋トレサマリ）"
```

---

### Task 20: 仕上げ — リグレッション確認 + ドキュメント更新

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 全テスト実行**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 全 PASS（既存 + 新規追加分）

- [ ] **Step 2: 端末別シミュレータでの目視確認**

Xcode のシミュレータを切り替えて以下で目視:
- iPhone SE (3rd generation) — レイアウト崩れなし
- iPhone 17 — 通常想定
- iPhone 17 Pro Max — 大画面で hero が間延びしないか

確認項目:
- [ ] ホームタブ起動時、上半分に水彩背景＋歩数＋コンパニオン＋ミニカードが見える
- [ ] ミニカードタップで歩くタブへ切り替わる
- [ ] 歩くタブのナビタイトルが「歩く」、TabItem が `figure.walk`
- [ ] 歩くタブの背景が水彩イラスト（時間帯で切り替わる）
- [ ] 記録／メニュー／履歴タブは挙動変化なし

- [ ] **Step 3: README.md の更新**

Read してから、Setup セクションに以下を追記:

```markdown
## イラスト生成（任意、開発者向け）

水彩イラストの再生成が必要な場合のみ:

```bash
cd scripts/illustrations
mise install python   # 初回のみ
uv sync               # 初回のみ
export OPENAI_API_KEY="sk-..."   # .envrc.example をコピーして埋める
uv run python generate.py --dry-run   # プロンプト確認
uv run python generate.py             # 全件生成（推定 $3〜7）
uv run python generate.py --filter tokyo,kyoto   # 部分再生成
```
```

- [ ] **Step 4: コミット**

```bash
git add README.md
git commit -m "📝 README にイラスト生成手順を追記"
```

- [ ] **Step 5: 最終ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: BUILD SUCCEEDED + 全 PASS

- [ ] **Step 6: 完了報告**

実装完了。差分確認:

```bash
git log --oneline 4ea123a..HEAD
```

期待されるコミット数: 約 15〜20 件（Task 1〜20 のうち実コミットがあるもの）。
