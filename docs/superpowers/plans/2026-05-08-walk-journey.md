# 万歩計 + バーチャル旅行 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 既存 workout-tracker iOS アプリに、HealthKit 由来の日別歩数管理と「東京 → 博多」バーチャル旅行ゲーム（祝福演出・お供キャラ・ストリーク・バッジ・昼夜変化）を専用タブとして追加する。

**Architecture:** 既存の SwiftUI + SwiftData + MV パターンに統合。純粋ロジックは `Domain/` に、HealthKit と SwiftData をまとめる薄いオーケストレーション層 `JourneyService` を `@Observable` で実装。歩数取得・Observer Query は既存 `HealthKitService` プロトコルを拡張する。タブを 4 → 5 に増設。

**Tech Stack:** Swift 5.10+, SwiftUI (iOS 18+), SwiftData, Swift Charts, HealthKit (`HKQuantityTypeIdentifier.stepCount`, `HKStatisticsCollectionQuery`, `HKObserverQuery`), `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`, AVFoundation（達成音）, XCTest, XcodeGen。

**Spec:** `docs/superpowers/specs/2026-05-08-walk-journey-design.md`

---

## 追加されるファイル構成

```
WorkoutTracker/
  App/
    WorkoutTrackerApp.swift          [変更] JourneyService 注入
    RootView.swift                   [変更] 5 タブ化
  Models/
    Enums.swift                      [変更] StepSource / TimeOfDay 追記
    StepDailyRecord.swift            [新規]
    CheckpointAchievement.swift      [新規]
    ModelContainerFactory.swift      [変更] schema 追加
  Domain/
    JourneyRoute.swift               [新規] Checkpoint struct + 13 地点
    JourneyEngine.swift              [新規] 進行計算（純粋）
    StreakCalculator.swift           [新規] 連続達成日数（純粋）
    CompanionDialog.swift            [新規] セリフ辞書（純粋）
  Services/
    HealthKitService.swift           [変更] StepDailyDTO + 歩数メソッド
    JourneyService.swift             [新規] @Observable オーケストレーション
  Features/
    Walk/
      WalkView.swift                 [新規] タブのメインビュー
      WalkMapView.swift              [新規] イラストマップ + 進行ピン
      JourneyHUD.swift               [新規] HUD + Observer 連携
      TimeOfDayBackground.swift      [新規] 時刻に応じた背景
      CompanionBubble.swift          [新規] キャラ + セリフ
      CelebrationOverlay.swift       [新規] 紙吹雪・触覚・サウンド
      StepHistoryView.swift          [新規] 歩数履歴グラフ
      BadgesView.swift               [新規] 達成バッジ一覧
      WalkSettingsView.swift         [新規] 目標・演出 ON/OFF・リセット
    Home/
      HomeView.swift                 [変更] 「今日の歩数」ミニカード追加
  Resources/
    Info.plist                       [変更] HealthKit 説明文に歩数を追記
    Assets.xcassets/
      JapanMap.imageset/             [新規] 列島イラスト（PDF）
      Companion/                     [新規] キャラ立ち絵 + 表情差分
      Badges/                        [新規] 13 都市分のバッジアイコン
WorkoutTrackerTests/
  TestHelpers/
    InMemoryContainer.swift          [変更] schema 追加
  ModelsTests/
    StepDailyRecordTests.swift       [新規]
    CheckpointAchievementTests.swift [新規]
  DomainTests/
    JourneyRouteTests.swift          [新規]
    JourneyEngineTests.swift         [新規]
    StreakCalculatorTests.swift      [新規]
    CompanionDialogTests.swift       [新規]
  ServicesTests/
    HealthKitServiceTests.swift      [変更] Stub に歩数メソッド追加
    JourneyServiceTests.swift        [新規]
project.yml                          [変更] NSHealthShareUsageDescription 更新
```

---

## 前提コマンド

```bash
# プロジェクト再生成（project.yml 編集後は必須）
xcodegen generate

# ビルド
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build

# テスト
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`iPhone 17` シミュレータが見つからない場合は `xcrun simctl list devices available` で名前を確認して読み替える。

---

## Task 1: 列挙型と Info.plist の更新

**Files:**
- Modify: `WorkoutTracker/Models/Enums.swift`
- Modify: `project.yml`

歩数同期の HealthKit 説明文と、新規列挙（`StepSource` / `TimeOfDay`）を準備する。

- [ ] **Step 1: `Models/Enums.swift` に列挙を追記**

`WorkoutTracker/Models/Enums.swift` を以下で置換:

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

enum StepSource: String, Codable {
    case healthKit
    case seed   // 開発・テスト用ダミー
}

enum TimeOfDay: String, CaseIterable {
    case morning, day, evening, night

    static func from(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .morning
        case 11..<16: return .day
        case 16..<19: return .evening
        default:      return .night
        }
    }
}
```

- [ ] **Step 2: `project.yml` の HealthKit 説明文を更新**

`project.yml` の `NSHealthShareUsageDescription` を以下に変更（行内の文字列だけ書き換え）:

```yaml
NSHealthShareUsageDescription: 体重・体脂肪率・歩数の推移をアプリに取り込みます。
```

- [ ] **Step 3: Xcode プロジェクトを再生成して Info.plist を反映**

```bash
xcodegen generate
```

実行後 `WorkoutTracker/Resources/Info.plist` の `NSHealthShareUsageDescription` が「体重・体脂肪率・歩数の推移をアプリに取り込みます。」に更新されていること。

- [ ] **Step 4: ビルドが通ることを確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: BUILD SUCCEEDED。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Models/Enums.swift project.yml WorkoutTracker/Resources/Info.plist
git commit -m "✨ feat: StepSource/TimeOfDay 列挙と歩数 HealthKit 説明文を追加"
```

---

## Task 2: StepDailyRecord モデル + テスト

**Files:**
- Create: `WorkoutTracker/Models/StepDailyRecord.swift`
- Create: `WorkoutTrackerTests/ModelsTests/StepDailyRecordTests.swift`

日別歩数を SwiftData エンティティとして永続化。`dayStart` でユニーク。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/ModelsTests/StepDailyRecordTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

final class StepDailyRecordTests: XCTestCase {
    @MainActor
    func test_insert_and_fetch() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        ctx.insert(StepDailyRecord(
            dayStart: day, steps: 8421, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.steps, 8421)
        XCTAssertEqual(fetched.first?.source, .healthKit)
    }

    @MainActor
    func test_dayStart_unique_constraint() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        ctx.insert(StepDailyRecord(
            dayStart: day, steps: 100, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        // 同じ dayStart で 2 つ目を入れた場合は SwiftData が UPSERT 動作する
        ctx.insert(StepDailyRecord(
            dayStart: day, steps: 200, source: .healthKit, lastSyncedAt: Date()
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(fetched.count, 1, "dayStart はユニーク制約で 1 件にまとまる")
        XCTAssertEqual(fetched.first?.steps, 200)
    }
}
```

- [ ] **Step 2: テストを実行して失敗を確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: コンパイル失敗（`StepDailyRecord` が未定義）。

- [ ] **Step 3: モデルを実装**

`WorkoutTracker/Models/StepDailyRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class StepDailyRecord {
    var id: UUID
    @Attribute(.unique) var dayStart: Date
    var steps: Int
    var source: StepSource
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        dayStart: Date,
        steps: Int,
        source: StepSource,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.dayStart = dayStart
        self.steps = steps
        self.source = source
        self.lastSyncedAt = lastSyncedAt
    }
}
```

- [ ] **Step 4: `InMemoryContainer` の schema に追加**

`WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift` を以下で置換:

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
            StepDailyRecord.self,
            CheckpointAchievement.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

注: `CheckpointAchievement` は次の Task 3 で作成。Step 4 の時点ではまだ未定義なのでビルドは Task 3 完了まで通らない。**Task 3 までは一括の作業として続けて行う**こと。

- [ ] **Step 5: 次の Task まで進めてから Test 実行 + コミット**

Task 3 と一緒にまとめてビルド・テスト・コミットする（Step 5 の実行は Task 3 末尾）。

---

## Task 3: CheckpointAchievement モデル + テスト

**Files:**
- Create: `WorkoutTracker/Models/CheckpointAchievement.swift`
- Create: `WorkoutTrackerTests/ModelsTests/CheckpointAchievementTests.swift`
- Modify: `WorkoutTracker/Models/ModelContainerFactory.swift`

到達したチェックポイントの履歴。`checkpointId` でユニーク。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/ModelsTests/CheckpointAchievementTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

final class CheckpointAchievementTests: XCTestCase {
    @MainActor
    func test_insert_and_celebration_flag_default() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        ctx.insert(CheckpointAchievement(
            checkpointId: "yokohama",
            achievedAt: Date(),
            totalStepsAtAchievement: 30_000
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.checkpointId, "yokohama")
        XCTAssertEqual(fetched.first?.celebrated, false)
    }

    @MainActor
    func test_checkpointId_unique() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        ctx.insert(CheckpointAchievement(
            checkpointId: "tokyo", achievedAt: Date(), totalStepsAtAchievement: 0
        ))
        try ctx.save()
        ctx.insert(CheckpointAchievement(
            checkpointId: "tokyo", achievedAt: Date(), totalStepsAtAchievement: 100
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(fetched.count, 1)
    }
}
```

- [ ] **Step 2: モデルを実装**

`WorkoutTracker/Models/CheckpointAchievement.swift`:

```swift
import Foundation
import SwiftData

@Model
final class CheckpointAchievement {
    var id: UUID
    @Attribute(.unique) var checkpointId: String
    var achievedAt: Date
    var totalStepsAtAchievement: Int
    var celebrated: Bool

    init(
        id: UUID = UUID(),
        checkpointId: String,
        achievedAt: Date,
        totalStepsAtAchievement: Int,
        celebrated: Bool = false
    ) {
        self.id = id
        self.checkpointId = checkpointId
        self.achievedAt = achievedAt
        self.totalStepsAtAchievement = totalStepsAtAchievement
        self.celebrated = celebrated
    }
}
```

- [ ] **Step 3: `ModelContainerFactory` の schema に新モデルを追加**

`WorkoutTracker/Models/ModelContainerFactory.swift` を以下で置換:

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
            StepDailyRecord.self,
            CheckpointAchievement.self,
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

- [ ] **Step 4: テストを実行して PASS を確認（Task 2 のテストも合わせて）**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 既存テスト + `StepDailyRecordTests` + `CheckpointAchievementTests` がすべて PASS。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Models WorkoutTrackerTests/ModelsTests WorkoutTrackerTests/TestHelpers
git commit -m "✨ feat: StepDailyRecord と CheckpointAchievement モデルを追加"
```

---

## Task 4: JourneyRoute（Checkpoint 静的データ）+ テスト

**Files:**
- Create: `WorkoutTracker/Domain/JourneyRoute.swift`
- Create: `WorkoutTrackerTests/DomainTests/JourneyRouteTests.swift`

東京 → 博多 13 地点を Swift コードでハードコード。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/DomainTests/JourneyRouteTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class JourneyRouteTests: XCTestCase {
    func test_has_thirteen_checkpoints() {
        XCTAssertEqual(JourneyRoute.tokyoToHakata.count, 13)
    }

    func test_first_is_tokyo_last_is_hakata() {
        let route = JourneyRoute.tokyoToHakata
        XCTAssertEqual(route.first?.id, "tokyo")
        XCTAssertEqual(route.first?.cumulativeKm, 0)
        XCTAssertEqual(route.last?.id, "hakata")
        XCTAssertEqual(route.last?.cumulativeKm, 1150)
    }

    func test_cumulative_km_strictly_increasing() {
        let route = JourneyRoute.tokyoToHakata
        for (a, b) in zip(route, route.dropFirst()) {
            XCTAssertLessThan(a.cumulativeKm, b.cumulativeKm,
                              "\(a.id) < \(b.id) でなければならない")
        }
    }

    func test_map_position_within_unit_box() {
        for cp in JourneyRoute.tokyoToHakata {
            XCTAssertGreaterThanOrEqual(cp.mapPosition.x, 0)
            XCTAssertLessThanOrEqual(cp.mapPosition.x, 1)
            XCTAssertGreaterThanOrEqual(cp.mapPosition.y, 0)
            XCTAssertLessThanOrEqual(cp.mapPosition.y, 1)
        }
    }

    func test_blurb_non_empty() {
        for cp in JourneyRoute.tokyoToHakata {
            XCTAssertFalse(cp.blurb.isEmpty, "\(cp.id) の紹介文が空")
        }
    }
}
```

- [ ] **Step 2: 失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `JourneyRoute` 未定義でコンパイル失敗。

- [ ] **Step 3: 実装**

`WorkoutTracker/Domain/JourneyRoute.swift`:

```swift
import CoreGraphics
import Foundation

struct Checkpoint: Identifiable, Equatable {
    let id: String
    let name: String
    let cumulativeKm: Double
    let mapPosition: CGPoint   // イラストマップ上の正規化座標 (0...1)
    let blurb: String
    let badgeAssetName: String
}

enum JourneyRoute {
    static let totalKm: Double = 1150

    static let tokyoToHakata: [Checkpoint] = [
        .init(id: "tokyo", name: "東京", cumulativeKm: 0,
              mapPosition: .init(x: 0.78, y: 0.45),
              blurb: "旅のはじまり。日本橋を出発、東海道五十三次の起点。",
              badgeAssetName: "Badges/tokyo"),
        .init(id: "yokohama", name: "横浜", cumulativeKm: 30,
              mapPosition: .init(x: 0.76, y: 0.47),
              blurb: "港の街、開国の窓口。中華街と赤レンガ倉庫が見もの。",
              badgeAssetName: "Badges/yokohama"),
        .init(id: "atami", name: "熱海", cumulativeKm: 105,
              mapPosition: .init(x: 0.70, y: 0.50),
              blurb: "温泉と海を一度に楽しめる保養地。花火大会も有名。",
              badgeAssetName: "Badges/atami"),
        .init(id: "shizuoka", name: "静岡", cumulativeKm: 180,
              mapPosition: .init(x: 0.65, y: 0.52),
              blurb: "富士山を望む茶どころ。駿河湾の海の幸も豊富。",
              badgeAssetName: "Badges/shizuoka"),
        .init(id: "hamamatsu", name: "浜松", cumulativeKm: 260,
              mapPosition: .init(x: 0.60, y: 0.54),
              blurb: "うなぎと餃子の街。楽器産業の発祥地でもある。",
              badgeAssetName: "Badges/hamamatsu"),
        .init(id: "nagoya", name: "名古屋", cumulativeKm: 365,
              mapPosition: .init(x: 0.55, y: 0.55),
              blurb: "金鯱の街。ひつまぶし・味噌カツ・きしめんの食文化。",
              badgeAssetName: "Badges/nagoya"),
        .init(id: "kyoto", name: "京都", cumulativeKm: 515,
              mapPosition: .init(x: 0.49, y: 0.56),
              blurb: "千年の都。寺社仏閣と路地裏の風情、四季の美しさ。",
              badgeAssetName: "Badges/kyoto"),
        .init(id: "osaka", name: "大阪", cumulativeKm: 555,
              mapPosition: .init(x: 0.46, y: 0.57),
              blurb: "天下の台所。たこ焼き・お好み焼き・串カツの聖地。",
              badgeAssetName: "Badges/osaka"),
        .init(id: "kobe", name: "神戸", cumulativeKm: 590,
              mapPosition: .init(x: 0.44, y: 0.58),
              blurb: "港町と異人館。神戸ビーフと夜景の街。",
              badgeAssetName: "Badges/kobe"),
        .init(id: "okayama", name: "岡山", cumulativeKm: 730,
              mapPosition: .init(x: 0.36, y: 0.61),
              blurb: "桃太郎伝説と倉敷の白壁。瀬戸内の温暖な気候。",
              badgeAssetName: "Badges/okayama"),
        .init(id: "hiroshima", name: "広島", cumulativeKm: 890,
              mapPosition: .init(x: 0.28, y: 0.64),
              blurb: "平和記念都市と宮島。お好み焼きと牡蠣の名物。",
              badgeAssetName: "Badges/hiroshima"),
        .init(id: "shimonoseki", name: "下関", cumulativeKm: 1075,
              mapPosition: .init(x: 0.21, y: 0.67),
              blurb: "本州の最西端、ふくの本場。関門海峡を望む。",
              badgeAssetName: "Badges/shimonoseki"),
        .init(id: "hakata", name: "博多", cumulativeKm: 1150,
              mapPosition: .init(x: 0.18, y: 0.70),
              blurb: "旅のゴール。豚骨ラーメンと屋台、めんたいこの本場。",
              badgeAssetName: "Badges/hakata"),
    ]
}
```

- [ ] **Step 4: テストを実行して PASS 確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Domain/JourneyRoute.swift WorkoutTrackerTests/DomainTests/JourneyRouteTests.swift
git commit -m "✨ feat: 東京→博多のチェックポイント 13 地点を定義"
```

---

## Task 5: JourneyEngine（純粋ロジック）+ テスト

**Files:**
- Create: `WorkoutTracker/Domain/JourneyEngine.swift`
- Create: `WorkoutTrackerTests/DomainTests/JourneyEngineTests.swift`

累積歩数 → 進行 km、通過チェックポイント、進行率を計算する純粋関数群。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/DomainTests/JourneyEngineTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class JourneyEngineTests: XCTestCase {
    private let route = JourneyRoute.tokyoToHakata

    // MARK: - computeProgress

    func test_zero_steps_at_origin() {
        let p = JourneyEngine.computeProgress(totalSteps: 0, route: route)
        XCTAssertEqual(p.totalKm, 0, accuracy: 0.001)
        XCTAssertEqual(p.progressRatio, 0, accuracy: 0.001)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "tokyo")
        XCTAssertEqual(p.nextCheckpoint?.id, "yokohama")
        XCTAssertEqual(p.metersToNext, 30_000, accuracy: 0.001)
        XCTAssertFalse(p.isCompleted)
    }

    func test_just_before_checkpoint() {
        let steps = 29_999  // 横浜まで 30 km = 30,000 歩 の 1 歩前
        let p = JourneyEngine.computeProgress(totalSteps: steps, route: route)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "tokyo")
        XCTAssertEqual(p.nextCheckpoint?.id, "yokohama")
    }

    func test_at_checkpoint_boundary() {
        let p = JourneyEngine.computeProgress(totalSteps: 30_000, route: route)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "yokohama")
        XCTAssertEqual(p.nextCheckpoint?.id, "atami")
    }

    func test_mid_journey() {
        // 575 km = 575,000 歩 → 大阪 (555) と 神戸 (590) の間
        let p = JourneyEngine.computeProgress(totalSteps: 575_000, route: route)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "osaka")
        XCTAssertEqual(p.nextCheckpoint?.id, "kobe")
        XCTAssertEqual(p.totalKm, 575, accuracy: 0.001)
        XCTAssertEqual(p.progressRatio, 575.0 / 1150.0, accuracy: 0.001)
    }

    func test_completed_at_finish() {
        let p = JourneyEngine.computeProgress(totalSteps: 1_150_000, route: route)
        XCTAssertTrue(p.isCompleted)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "hakata")
        XCTAssertNil(p.nextCheckpoint)
        XCTAssertEqual(p.progressRatio, 1.0, accuracy: 0.001)
    }

    func test_overshoot_clamps_to_completed() {
        let p = JourneyEngine.computeProgress(totalSteps: 9_999_999, route: route)
        XCTAssertTrue(p.isCompleted)
        XCTAssertEqual(p.progressRatio, 1.0, accuracy: 0.001)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "hakata")
    }

    func test_meters_per_step_two() {
        // 1 歩 = 2 m なら 15,000 歩 = 30 km で横浜到達
        let p = JourneyEngine.computeProgress(totalSteps: 15_000, route: route, metersPerStep: 2.0)
        XCTAssertEqual(p.totalKm, 30, accuracy: 0.001)
        XCTAssertEqual(p.lastPassedCheckpoint?.id, "yokohama")
    }

    // MARK: - passedCheckpointIds

    func test_passed_set_initial() {
        let ids = JourneyEngine.passedCheckpointIds(totalSteps: 0, route: route)
        XCTAssertEqual(ids, ["tokyo"])
    }

    func test_passed_set_three_cities() {
        // 横浜・熱海・静岡まで通過: 180 km = 180,000 歩
        let ids = JourneyEngine.passedCheckpointIds(totalSteps: 180_000, route: route)
        XCTAssertEqual(ids, ["tokyo", "yokohama", "atami", "shizuoka"])
    }

    func test_passed_set_completed() {
        let ids = JourneyEngine.passedCheckpointIds(totalSteps: 1_200_000, route: route)
        XCTAssertEqual(ids.count, 13)
    }
}
```

- [ ] **Step 2: 失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 3: 実装**

`WorkoutTracker/Domain/JourneyEngine.swift`:

```swift
import Foundation

struct JourneyProgress: Equatable {
    let totalSteps: Int
    let totalKm: Double
    let progressRatio: Double          // 0.0...1.0
    let lastPassedCheckpoint: Checkpoint?
    let nextCheckpoint: Checkpoint?
    let metersToNext: Double
    let isCompleted: Bool

    static let empty = JourneyProgress(
        totalSteps: 0,
        totalKm: 0,
        progressRatio: 0,
        lastPassedCheckpoint: nil,
        nextCheckpoint: nil,
        metersToNext: 0,
        isCompleted: false
    )
}

enum JourneyEngine {
    /// 累積歩数とルートから進行状態を計算する。
    static func computeProgress(
        totalSteps: Int,
        route: [Checkpoint],
        metersPerStep: Double = 1.0
    ) -> JourneyProgress {
        guard let last = route.last, !route.isEmpty else { return .empty }
        let totalMeters = Double(totalSteps) * metersPerStep
        let totalKm = totalMeters / 1000.0
        let routeTotalKm = last.cumulativeKm
        let isCompleted = totalKm >= routeTotalKm
        let clampedKm = min(totalKm, routeTotalKm)
        let ratio = routeTotalKm > 0 ? clampedKm / routeTotalKm : 0

        // 最後に通過したチェックポイント = cumulativeKm <= clampedKm の最大
        let passedIndex = route.lastIndex(where: { $0.cumulativeKm <= clampedKm }) ?? 0
        let last_ = route[passedIndex]
        let next_: Checkpoint? = (passedIndex + 1 < route.count) ? route[passedIndex + 1] : nil
        let metersToNext = (next_?.cumulativeKm ?? routeTotalKm) * 1000.0 - totalMeters

        return JourneyProgress(
            totalSteps: totalSteps,
            totalKm: clampedKm,
            progressRatio: ratio,
            lastPassedCheckpoint: last_,
            nextCheckpoint: isCompleted ? nil : next_,
            metersToNext: max(0, metersToNext),
            isCompleted: isCompleted
        )
    }

    /// 既到達のチェックポイント ID 集合を返す（起点 tokyo は常に含む）。
    static func passedCheckpointIds(
        totalSteps: Int,
        route: [Checkpoint],
        metersPerStep: Double = 1.0
    ) -> Set<String> {
        let totalKm = Double(totalSteps) * metersPerStep / 1000.0
        return Set(route.filter { $0.cumulativeKm <= totalKm }.map(\.id))
    }
}
```

- [ ] **Step 4: テスト PASS 確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Domain/JourneyEngine.swift WorkoutTrackerTests/DomainTests/JourneyEngineTests.swift
git commit -m "✨ feat: JourneyEngine で累積歩数から進行状態を計算"
```

---

## Task 6: StreakCalculator + テスト

**Files:**
- Create: `WorkoutTracker/Domain/StreakCalculator.swift`
- Create: `WorkoutTrackerTests/DomainTests/StreakCalculatorTests.swift`

連続達成日数（ストリーク）を計算。当日が未達でも前日まで達成していれば前日からカウント。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/DomainTests/StreakCalculatorTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class StreakCalculatorTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private let goal = 8000

    private func day(_ offset: Int, from base: Date) -> Date {
        cal.date(byAdding: .day, value: offset, to: base)!
    }

    private func record(_ steps: Int, dayStart: Date) -> StepDailyRecord {
        StepDailyRecord(dayStart: dayStart, steps: steps, source: .seed, lastSyncedAt: dayStart)
    }

    func test_no_records_zero_streak() {
        let today = cal.startOfDay(for: Date())
        let s = StreakCalculator.currentStreak(records: [], dailyGoal: goal,
                                                today: today, calendar: cal)
        XCTAssertEqual(s, 0)
    }

    func test_today_only_met() {
        let today = cal.startOfDay(for: Date())
        let s = StreakCalculator.currentStreak(
            records: [record(9000, dayStart: today)],
            dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 1)
    }

    func test_today_unmet_yesterday_met_streak_one() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(3000, dayStart: today),
            record(8500, dayStart: day(-1, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        // 当日未達でも前日まで連続達成があれば前日からの連続を返す
        XCTAssertEqual(s, 1)
    }

    func test_three_consecutive_days_met() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(8200, dayStart: today),
            record(8500, dayStart: day(-1, from: today)),
            record(9000, dayStart: day(-2, from: today)),
            record(7900, dayStart: day(-3, from: today)),  // 達成失敗
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 3)
    }

    func test_gap_breaks_streak() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(9000, dayStart: today),
            // -1 日 のレコードなし → ストリーク途切れ
            record(8500, dayStart: day(-2, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 1)
    }

    func test_zero_today_zero_yesterday() {
        let today = cal.startOfDay(for: Date())
        let records = [
            record(0, dayStart: today),
            record(0, dayStart: day(-1, from: today)),
        ]
        let s = StreakCalculator.currentStreak(
            records: records, dailyGoal: goal, today: today, calendar: cal
        )
        XCTAssertEqual(s, 0)
    }
}
```

- [ ] **Step 2: 失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 3: 実装**

`WorkoutTracker/Domain/StreakCalculator.swift`:

```swift
import Foundation

enum StreakCalculator {
    /// 当日から逆向きに dailyGoal を達成した連続日数を返す。
    /// 当日が未達でも、前日まで連続して達成していればその連続数を返す。
    static func currentStreak(
        records: [StepDailyRecord],
        dailyGoal: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(uniqueKeysWithValues:
            records.map { (calendar.startOfDay(for: $0.dayStart), $0.steps) }
        )

        // 開始日: 当日が達成していれば当日、未達なら前日から数える
        var cursor = todayStart
        if (byDay[cursor] ?? 0) < dailyGoal {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while let steps = byDay[cursor], steps >= dailyGoal {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
```

- [ ] **Step 4: テスト PASS 確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Domain/StreakCalculator.swift WorkoutTrackerTests/DomainTests/StreakCalculatorTests.swift
git commit -m "✨ feat: StreakCalculator で連続達成日数を計算"
```

---

## Task 7: CompanionDialog（セリフ辞書）+ テスト

**Files:**
- Create: `WorkoutTracker/Domain/CompanionDialog.swift`
- Create: `WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift`

時間帯・達成度・進行率に応じたセリフ集。直前と同じセリフは避ける。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class CompanionDialogTests: XCTestCase {
    private let progress = JourneyProgress(
        totalSteps: 100_000,
        totalKm: 100,
        progressRatio: 0.087,
        lastPassedCheckpoint: JourneyRoute.tokyoToHakata[1],
        nextCheckpoint: JourneyRoute.tokyoToHakata[2],
        metersToNext: 5_000,
        isCompleted: false
    )

    func test_returns_non_empty_for_each_time_of_day() {
        for tod in TimeOfDay.allCases {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 4000,
                dailyGoal: 8000, timeOfDay: tod, lastShown: nil
            )
            XCTAssertFalse(line.isEmpty, "\(tod) でセリフが空")
        }
    }

    func test_avoids_repeating_lastShown() {
        // 100 回引いて、すべて lastShown と異なる
        for _ in 0..<100 {
            let last = "前回のセリフ"
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 4000,
                dailyGoal: 8000, timeOfDay: .day, lastShown: last
            )
            XCTAssertNotEqual(line, last)
        }
    }

    func test_completed_journey_has_celebration_message() {
        let done = JourneyProgress(
            totalSteps: 1_200_000, totalKm: 1150, progressRatio: 1.0,
            lastPassedCheckpoint: JourneyRoute.tokyoToHakata.last,
            nextCheckpoint: nil, metersToNext: 0, isCompleted: true
        )
        let line = CompanionDialog.line(
            progress: done, todaySteps: 9000,
            dailyGoal: 8000, timeOfDay: .day, lastShown: nil
        )
        XCTAssertFalse(line.isEmpty)
    }

    func test_goal_achieved_uses_celebration_pool() {
        // 目標達成時のセリフ群が引かれる
        var seen: Set<String> = []
        for _ in 0..<30 {
            let line = CompanionDialog.line(
                progress: progress, todaySteps: 9000,
                dailyGoal: 8000, timeOfDay: .day, lastShown: nil
            )
            seen.insert(line)
        }
        XCTAssertGreaterThan(seen.count, 1, "達成時セリフプールが複数件あること")
    }
}
```

- [ ] **Step 2: 失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 3: 実装**

`WorkoutTracker/Domain/CompanionDialog.swift`:

```swift
import Foundation

enum CompanionDialog {
    /// 状況に応じたセリフを返す。lastShown と同じ文字列は返さない。
    static func line(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay,
        lastShown: String?
    ) -> String {
        let pool = pool(progress: progress, todaySteps: todaySteps,
                        dailyGoal: dailyGoal, timeOfDay: timeOfDay)
        let candidates = pool.filter { $0 != lastShown }
        let pick = candidates.isEmpty ? pool : candidates
        return pick.randomElement() ?? "今日もぼちぼちいこう。"
    }

    private static func pool(
        progress: JourneyProgress,
        todaySteps: Int,
        dailyGoal: Int,
        timeOfDay: TimeOfDay
    ) -> [String] {
        if progress.isCompleted {
            return [
                "ついに博多到着！本当におつかれさま。",
                "完走おめでとう！次の旅も楽しみだね。",
                "1,150 km をその足で踏破。すごいことだよ。",
            ]
        }

        let achieved = todaySteps >= dailyGoal
        let nextName = progress.nextCheckpoint?.name ?? "次の地点"
        let kmToNext = String(format: "%.1f", progress.metersToNext / 1000.0)

        if achieved {
            return [
                "今日の目標達成！えらい！",
                "目標クリア。ご褒美時間にしよ。",
                "目標達成、いい流れだね。",
                "\(nextName) まであと \(kmToNext) km。明日も歩こう。",
            ]
        }

        let remaining = max(0, dailyGoal - todaySteps)
        let timeOpener: String
        switch timeOfDay {
        case .morning: timeOpener = "おはよう。"
        case .day:     timeOpener = "今日もいいペースだね。"
        case .evening: timeOpener = "夕方のひと歩きで距離を稼ごう。"
        case .night:   timeOpener = "今日はもう少しだけ。"
        }

        return [
            "\(timeOpener) あと \(remaining) 歩で目標。",
            "\(timeOpener) \(nextName) まであと \(kmToNext) km。",
            "\(timeOpener) ゆっくりでいいよ、続けることが大事。",
            "\(nextName) で名物が待ってるよ。",
        ]
    }
}
```

- [ ] **Step 4: テスト PASS 確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Domain/CompanionDialog.swift WorkoutTrackerTests/DomainTests/CompanionDialogTests.swift
git commit -m "✨ feat: お供キャラの状況依存セリフ辞書を追加"
```

---

## Task 8: HealthKitService 拡張（歩数）+ Stub 拡張 + テスト

**Files:**
- Modify: `WorkoutTracker/Services/HealthKitService.swift`
- Modify: `WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift`

歩数取得 / Observer Query を既存 protocol に追加。Stub を強化して Task 9 で `JourneyService` から再利用する。

- [ ] **Step 1: 失敗テストを書く（Stub の歩数挙動）**

`WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift` を以下で置換:

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

    func test_mock_denied_throws_on_authorization() async throws {
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

    func test_stub_steps_today_default_zero() async throws {
        let stub = StubHealthKitService(latest: nil, range: [])
        let n = try await stub.fetchTodaySteps()
        XCTAssertEqual(n, 0)
    }

    func test_stub_steps_today_returns_injected() async throws {
        let stub = StubHealthKitService(latest: nil, range: [], todaySteps: 5432)
        let n = try await stub.fetchTodaySteps()
        XCTAssertEqual(n, 5432)
    }

    func test_stub_daily_steps_returns_injected() async throws {
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [.init(dayStart: day, steps: 8200, source: .healthKit)]
        )
        let result = try await stub.fetchDailySteps(from: day, to: day)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.steps, 8200)
    }

    func test_stub_observer_invokes_handler_with_injected_value() {
        let stub = StubHealthKitService(latest: nil, range: [], todaySteps: 1234)
        var received: Int?
        stub.startObservingTodaySteps { received = $0 }
        stub.triggerObserver()  // テスト用フック
        XCTAssertEqual(received, 1234)
    }
}

final class StubHealthKitService: HealthKitService {
    let latest: BodyMetricDTO?
    let range: [BodyMetricDTO]
    let authorizationError: Error?
    var todaySteps: Int
    var dailySteps: [StepDailyDTO]

    private var observerHandler: ((Int) -> Void)?

    init(
        latest: BodyMetricDTO?,
        range: [BodyMetricDTO],
        authorizationError: Error? = nil,
        todaySteps: Int = 0,
        dailySteps: [StepDailyDTO] = []
    ) {
        self.latest = latest
        self.range = range
        self.authorizationError = authorizationError
        self.todaySteps = todaySteps
        self.dailySteps = dailySteps
    }

    // MARK: 体組成
    func requestAuthorization() async throws {
        if let authorizationError { throw authorizationError }
    }
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO? { latest }
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO] { range }

    // MARK: 歩数
    func requestStepAuthorization() async throws {
        if let authorizationError { throw authorizationError }
    }
    func fetchTodaySteps() async throws -> Int { todaySteps }
    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO] { dailySteps }
    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void) {
        observerHandler = handler
    }
    func stopObservingTodaySteps() { observerHandler = nil }

    // テスト用: Observer をトリガする
    func triggerObserver() { observerHandler?(todaySteps) }
}
```

- [ ] **Step 2: 失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

`StepDailyDTO` 等が未定義でコンパイル失敗。

- [ ] **Step 3: `HealthKitService.swift` に DTO と protocol/実装を追加**

`WorkoutTracker/Services/HealthKitService.swift` を以下で置換:

```swift
import Foundation
import HealthKit

struct BodyMetricDTO: Equatable {
    let recordedAt: Date
    let weightKg: Double?
    let bodyFatPercent: Double?
    let source: BodyMetricSource
}

struct StepDailyDTO: Equatable {
    let dayStart: Date     // 暦日 00:00
    let steps: Int
    let source: StepSource
}

enum HealthKitError: Error {
    case unavailable
    case denied
}

protocol HealthKitService {
    // 既存（体組成）
    func requestAuthorization() async throws
    func fetchLatestBodyMetric() async throws -> BodyMetricDTO?
    func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetricDTO]

    // 追加（歩数）
    func requestStepAuthorization() async throws
    func fetchTodaySteps() async throws -> Int
    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO]
    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void)
    func stopObservingTodaySteps()
}

final class LiveHealthKitService: HealthKitService {
    private let store = HKHealthStore()
    private let weightType = HKQuantityType(.bodyMass)
    private let fatType = HKQuantityType(.bodyFatPercentage)
    private let stepType = HKQuantityType(.stepCount)

    private var observerQuery: HKObserverQuery?

    // MARK: 体組成（既存）

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
            .map {
                BodyMetricDTO(
                    recordedAt: $0.key,
                    weightKg: $0.value.0,
                    bodyFatPercent: $0.value.1,
                    source: .healthKit
                )
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    // MARK: 歩数（新規）

    func requestStepAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    func fetchTodaySteps() async throws -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        return try await stepsSum(from: start, to: end)
    }

    func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyDTO] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
        return try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let interval = DateComponents(day: 1)
            let q = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { cont.resume(throwing: error); return }
                var out: [StepDailyDTO] = []
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    let day = cal.startOfDay(for: stats.startDate)
                    let value = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    let steps = max(0, Int(value.rounded()))
                    out.append(.init(dayStart: day, steps: steps, source: .healthKit))
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    func startObservingTodaySteps(_ handler: @escaping (Int) -> Void) {
        stopObservingTodaySteps()
        let q = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil else { completion(); return }
            Task { @MainActor in
                if let n = try? await self?.fetchTodaySteps() {
                    handler(n)
                }
                completion()
            }
        }
        observerQuery = q
        store.execute(q)
    }

    func stopObservingTodaySteps() {
        if let q = observerQuery { store.stop(q) }
        observerQuery = nil
    }

    // MARK: 内部ヘルパー

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

    private func stepsSum(from: Date, to: Date) async throws -> Int {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
            let q = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { cont.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: max(0, Int(value.rounded())))
            }
            store.execute(q)
        }
    }
}
```

- [ ] **Step 4: テスト PASS 確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Services/HealthKitService.swift WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift
git commit -m "✨ feat: HealthKitService に歩数取得 + Observer を追加"
```

---

## Task 9: JourneyService（@Observable）+ テスト

**Files:**
- Create: `WorkoutTracker/Services/JourneyService.swift`
- Create: `WorkoutTrackerTests/ServicesTests/JourneyServiceTests.swift`

`HealthKitService` + `JourneyEngine` + SwiftData をまとめる薄いオーケストレーション層。`@Observable` で UI から購読。

- [ ] **Step 1: 失敗テストを書く**

`WorkoutTrackerTests/ServicesTests/JourneyServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class JourneyServiceTests: XCTestCase {
    func test_bootstrap_inserts_step_records() async throws {
        let container = try InMemoryContainer.make()
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [
                .init(dayStart: day, steps: 6000, source: .healthKit),
                .init(dayStart: cal.date(byAdding: .day, value: -1, to: day)!,
                      steps: 9000, source: .healthKit),
            ],
            todaySteps: 6000
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )

        await svc.bootstrap()

        let records = try container.mainContext.fetch(FetchDescriptor<StepDailyRecord>())
        XCTAssertEqual(records.count, 2)
    }

    func test_bootstrap_creates_pending_celebrations_for_passed_checkpoints() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        // 横浜 (30 km = 30,000 歩) を超えて 50,000 歩
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)],
            todaySteps: 50_000
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )

        await svc.bootstrap()

        // 通過: tokyo, yokohama → 起点 tokyo は演出スキップ、yokohama のみ pending
        XCTAssertTrue(svc.pendingCelebrations.contains { $0.checkpointId == "yokohama" })
        XCTAssertFalse(svc.pendingCelebrations.contains { $0.checkpointId == "tokyo" })
    }

    func test_bootstrap_idempotent() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)],
            todaySteps: 50_000
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )

        await svc.bootstrap()
        await svc.bootstrap()

        let achievements = try container.mainContext.fetch(FetchDescriptor<CheckpointAchievement>())
        // tokyo + yokohama = 2 件、再呼び出しでも増えない
        XCTAssertEqual(achievements.count, 2)
    }

    func test_mark_celebrated_sets_flag_and_removes_from_pending() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)],
            todaySteps: 50_000
        )
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { day },
            persistJourneyStartedAt: { _ in }
        )
        await svc.bootstrap()

        let target = svc.pendingCelebrations.first { $0.checkpointId == "yokohama" }!
        svc.markCelebrated(target)

        XCTAssertTrue(target.celebrated)
        XCTAssertFalse(svc.pendingCelebrations.contains { $0.checkpointId == "yokohama" })
    }

    func test_reset_journey_clears_achievements() async throws {
        let container = try InMemoryContainer.make()
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            dailySteps: [.init(dayStart: day, steps: 50_000, source: .healthKit)],
            todaySteps: 50_000
        )
        var stored: Date? = day
        let svc = JourneyService(
            healthKit: stub,
            container: container,
            journeyStartedAtProvider: { stored ?? day },
            persistJourneyStartedAt: { stored = $0 }
        )
        await svc.bootstrap()

        svc.resetJourney(now: day.addingTimeInterval(86400))

        let achievements = try container.mainContext.fetch(FetchDescriptor<CheckpointAchievement>())
        XCTAssertEqual(achievements.count, 0)
        XCTAssertEqual(stored, day.addingTimeInterval(86400))
    }
}
```

- [ ] **Step 2: 失敗確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 3: 実装**

`WorkoutTracker/Services/JourneyService.swift`:

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class JourneyService {
    var todaySteps: Int = 0
    var progress: JourneyProgress = .empty
    var pendingCelebrations: [CheckpointAchievement] = []

    private let healthKit: HealthKitService
    private let container: ModelContainer
    private let route: [Checkpoint]
    private let journeyStartedAtProvider: () -> Date?
    private let persistJourneyStartedAt: (Date) -> Void

    init(
        healthKit: HealthKitService,
        container: ModelContainer,
        route: [Checkpoint] = JourneyRoute.tokyoToHakata,
        journeyStartedAtProvider: @escaping () -> Date? = { Self.defaultJourneyStartedAt },
        persistJourneyStartedAt: @escaping (Date) -> Void = Self.defaultPersistJourneyStartedAt
    ) {
        self.healthKit = healthKit
        self.container = container
        self.route = route
        self.journeyStartedAtProvider = journeyStartedAtProvider
        self.persistJourneyStartedAt = persistJourneyStartedAt
    }

    private static var defaultJourneyStartedAt: Date? {
        let d = UserDefaults.standard.object(forKey: "walk.journeyStartedAt") as? Date
        return d
    }

    private static func defaultPersistJourneyStartedAt(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "walk.journeyStartedAt")
    }

    // MARK: ライフサイクル

    func bootstrap() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 旅未開始なら今日から
        let started: Date
        if let existing = journeyStartedAtProvider() {
            started = cal.startOfDay(for: existing)
        } else {
            persistJourneyStartedAt(today)
            started = today
        }

        // 直近 7 日 + 旅開始日以降の歩数を同期（広い方を採用）
        let from = min(started, cal.date(byAdding: .day, value: -7, to: today) ?? today)
        let to = today
        let dtos = (try? await healthKit.fetchDailySteps(from: from, to: to)) ?? []
        upsert(dtos: dtos)

        let totalSteps = sumSteps(from: started, to: today)
        todaySteps = (try? await healthKit.fetchTodaySteps()) ?? 0
        progress = JourneyEngine.computeProgress(totalSteps: totalSteps, route: route)

        ensureAchievements(totalSteps: totalSteps)
        refreshPendingCelebrations()
    }

    func refreshOnAppear() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let started = cal.startOfDay(for: journeyStartedAtProvider() ?? today)
        let dtos = (try? await healthKit.fetchDailySteps(from: today, to: today)) ?? []
        upsert(dtos: dtos)

        todaySteps = (try? await healthKit.fetchTodaySteps()) ?? 0
        let totalSteps = sumSteps(from: started, to: today)
        progress = JourneyEngine.computeProgress(totalSteps: totalSteps, route: route)
        ensureAchievements(totalSteps: totalSteps)
        refreshPendingCelebrations()
    }

    func startObserving() {
        healthKit.startObservingTodaySteps { [weak self] n in
            Task { @MainActor in
                guard let self else { return }
                self.todaySteps = n
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                self.upsert(dtos: [.init(dayStart: today, steps: n, source: .healthKit)])
                let started = cal.startOfDay(for: self.journeyStartedAtProvider() ?? today)
                let total = self.sumSteps(from: started, to: today)
                self.progress = JourneyEngine.computeProgress(totalSteps: total, route: self.route)
                self.ensureAchievements(totalSteps: total)
                self.refreshPendingCelebrations()
            }
        }
    }

    func stopObserving() {
        healthKit.stopObservingTodaySteps()
    }

    // MARK: 演出

    func markCelebrated(_ achievement: CheckpointAchievement) {
        achievement.celebrated = true
        try? container.mainContext.save()
        refreshPendingCelebrations()
    }

    // MARK: 操作

    func resetJourney(now: Date = .now) {
        let ctx = container.mainContext
        if let existing = try? ctx.fetch(FetchDescriptor<CheckpointAchievement>()) {
            for a in existing { ctx.delete(a) }
        }
        try? ctx.save()
        let day = Calendar.current.startOfDay(for: now)
        persistJourneyStartedAt(day)
        progress = .empty
        pendingCelebrations = []
    }

    func setDailyGoal(_ steps: Int) {
        UserDefaults.standard.set(steps, forKey: "walk.dailyGoalSteps")
    }

    // MARK: 内部

    private func upsert(dtos: [StepDailyDTO]) {
        let ctx = container.mainContext
        let cal = Calendar.current
        for dto in dtos {
            let day = cal.startOfDay(for: dto.dayStart)
            var fd = FetchDescriptor<StepDailyRecord>(
                predicate: #Predicate { $0.dayStart == day }
            )
            fd.fetchLimit = 1
            if let existing = try? ctx.fetch(fd).first {
                existing.steps = dto.steps
                existing.lastSyncedAt = Date()
            } else {
                ctx.insert(StepDailyRecord(
                    dayStart: day,
                    steps: dto.steps,
                    source: dto.source,
                    lastSyncedAt: Date()
                ))
            }
        }
        try? ctx.save()
    }

    private func sumSteps(from: Date, to: Date) -> Int {
        let ctx = container.mainContext
        let fromDay = Calendar.current.startOfDay(for: from)
        let toDay = Calendar.current.startOfDay(for: to)
        let fd = FetchDescriptor<StepDailyRecord>(
            predicate: #Predicate { $0.dayStart >= fromDay && $0.dayStart <= toDay }
        )
        let rows = (try? ctx.fetch(fd)) ?? []
        return rows.reduce(0) { $0 + $1.steps }
    }

    private func ensureAchievements(totalSteps: Int) {
        let ctx = container.mainContext
        let passed = JourneyEngine.passedCheckpointIds(totalSteps: totalSteps, route: route)
        let existing = (try? ctx.fetch(FetchDescriptor<CheckpointAchievement>())) ?? []
        let existingIds = Set(existing.map(\.checkpointId))
        for id in passed where !existingIds.contains(id) {
            ctx.insert(CheckpointAchievement(
                checkpointId: id,
                achievedAt: Date(),
                totalStepsAtAchievement: totalSteps,
                celebrated: id == "tokyo"  // 起点は演出不要
            ))
        }
        try? ctx.save()
    }

    private func refreshPendingCelebrations() {
        let ctx = container.mainContext
        let fd = FetchDescriptor<CheckpointAchievement>(
            predicate: #Predicate { $0.celebrated == false },
            sortBy: [SortDescriptor(\.achievedAt)]
        )
        pendingCelebrations = (try? ctx.fetch(fd)) ?? []
    }
}
```

- [ ] **Step 4: テスト PASS 確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Services/JourneyService.swift WorkoutTrackerTests/ServicesTests/JourneyServiceTests.swift
git commit -m "✨ feat: JourneyService で歩数同期と進行・演出キューを管理"
```

---

## Task 10: WorkoutTrackerApp に JourneyService 注入 + RootView 5 タブ + Walk タブスケルトン

**Files:**
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`
- Modify: `WorkoutTracker/App/RootView.swift`
- Create: `WorkoutTracker/Features/Walk/WalkView.swift`

`@Environment` で `JourneyService` を全 View から触れるようにし、Walk タブの空のスケルトンを置く。

- [ ] **Step 1: `WorkoutTrackerApp.swift` を更新**

`WorkoutTracker/App/WorkoutTrackerApp.swift` を以下で置換:

```swift
import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @State private var journey: JourneyService

    init() {
        let c = ModelContainerFactory.makeShared()
        self.container = c
        let svc = JourneyService(
            healthKit: LiveHealthKitService(),
            container: c
        )
        self._journey = State(initialValue: svc)

        Task { @MainActor [container = c] in
            SeedService.seedIfNeeded(
                context: container.mainContext,
                flagStore: UserDefaultsSeedFlagStore()
            )
        }
        Task { @MainActor in
            await svc.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(journey)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: `RootView.swift` を 5 タブに**

`WorkoutTracker/App/RootView.swift` を以下で置換:

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
            WalkView()
                .tabItem { Label("旅", systemImage: "map") }
        }
    }
}

#Preview { RootView() }
```

- [ ] **Step 3: `WalkView.swift` のスケルトンを作成**

`WorkoutTracker/Features/Walk/WalkView.swift`:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey

    var body: some View {
        NavigationStack {
            VStack {
                Text("旅 ＆ 万歩計")
                    .font(.title2)
                Text("ここにマップと HUD を実装する")
                    .foregroundStyle(.secondary)
                Text("今日の歩数: \(journey.todaySteps)")
                Text("進行: \(String(format: "%.1f", journey.progress.totalKm)) km / 1,150 km")
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
            }
            .onDisappear {
                journey.stopObserving()
            }
        }
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 4: ビルド + テスト確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: BUILD SUCCEEDED + 全テスト PASS。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/App WorkoutTracker/Features/Walk
git commit -m "✨ feat: Walk タブを追加して JourneyService を注入"
```

---

## Task 11: WalkMapView（イラストマップ + 進行ピン）

**Files:**
- Create: `WorkoutTracker/Features/Walk/WalkMapView.swift`
- Create: `WorkoutTracker/Resources/Assets.xcassets/JapanMap.imageset/Contents.json`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

イラストマップに進行ピンを正規化座標で重ねる。マップアセットはプレースホルダ画像で進める（Step 1）。

- [ ] **Step 1: マップアセットのプレースホルダを作成**

`WorkoutTracker/Resources/Assets.xcassets/JapanMap.imageset/Contents.json`:

```json
{
  "images": [
    { "idiom": "universal", "scale": "1x" },
    { "idiom": "universal", "scale": "2x" },
    { "idiom": "universal", "scale": "3x" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

注: 実画像（PDF）は別途手動で `JapanMap.imageset/` に追加する。Step 1 時点では画像なしで `.imageset` の Contents.json のみ。`Image("JapanMap")` は実機で空白になるが、進行ピンの相対配置は GeometryReader で機能する。

- [ ] **Step 2: `WalkMapView.swift` を作成**

`WorkoutTracker/Features/Walk/WalkMapView.swift`:

```swift
import SwiftUI

struct WalkMapView: View {
    let route: [Checkpoint]
    let progress: JourneyProgress

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image("JapanMap")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.05))

                ForEach(route) { cp in
                    pin(for: cp)
                        .position(
                            x: cp.mapPosition.x * geo.size.width,
                            y: cp.mapPosition.y * geo.size.height
                        )
                }
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }

    @ViewBuilder
    private func pin(for cp: Checkpoint) -> some View {
        let isPassed = (progress.lastPassedCheckpoint?.cumulativeKm ?? -1) >= cp.cumulativeKm
        let isCurrent = progress.lastPassedCheckpoint?.id == cp.id && !progress.isCompleted
        ZStack {
            Circle()
                .fill(isPassed ? Color.orange : Color.secondary.opacity(0.4))
                .frame(width: isCurrent ? 18 : 12, height: isCurrent ? 18 : 12)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
                .shadow(radius: isPassed ? 2 : 0)
                .scaleEffect(isCurrent ? 1.2 : 1.0)
                .animation(
                    isCurrent
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isCurrent
                )
            Text(cp.name)
                .font(.caption2)
                .padding(.horizontal, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .offset(y: 14)
        }
    }
}

#Preview {
    WalkMapView(
        route: JourneyRoute.tokyoToHakata,
        progress: JourneyEngine.computeProgress(
            totalSteps: 200_000,
            route: JourneyRoute.tokyoToHakata
        )
    )
    .padding()
}
```

- [ ] **Step 3: `WalkView.swift` にマップを組み込む**

`WorkoutTracker/Features/Walk/WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日の歩数: \(journey.todaySteps)")
                        Text("進行: \(String(format: "%.1f", journey.progress.totalKm)) km / 1,150 km")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
            }
            .onDisappear {
                journey.stopObserving()
            }
        }
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 4: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Walk WorkoutTracker/Resources/Assets.xcassets/JapanMap.imageset
git commit -m "✨ feat: イラストマップ + 進行ピンを Walk タブに表示"
```

---

## Task 12: JourneyHUD（HUD: 今日の歩数 / 目標ゲージ / 次の地点）

**Files:**
- Create: `WorkoutTracker/Features/Walk/JourneyHUD.swift`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

歩数 / 目標 / 次の地点 / 旅進行を縦並び表示する HUD コンポーネント。

- [ ] **Step 1: `JourneyHUD.swift` を作成**

`WorkoutTracker/Features/Walk/JourneyHUD.swift`:

```swift
import SwiftUI

struct JourneyHUD: View {
    let todaySteps: Int
    let dailyGoal: Int
    let progress: JourneyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            todayCard
            journeyCard
            nextCard
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日の歩数").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("目標 \(dailyGoal) 歩").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(todaySteps)").font(.system(size: 36, weight: .bold))
                Text("歩").font(.title3).foregroundStyle(.secondary)
                Spacer()
                Text("\(achievementPercent) %").font(.title2).bold()
            }
            ProgressView(value: min(1.0, Double(todaySteps) / Double(max(1, dailyGoal))))
                .tint(achievementPercent >= 100 ? .green : .orange)
        }
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var journeyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("旅の進行").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", progress.totalKm))
                    .font(.system(size: 28, weight: .bold))
                Text("km / 1,150 km").font(.body).foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: progress.progressRatio)
                .tint(.blue)
        }
        .padding()
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var nextCard: some View {
        if progress.isCompleted {
            HStack {
                Image(systemName: "flag.checkered").font(.title2)
                Text("旅完走！").font(.headline)
                Spacer()
            }
            .padding()
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else if let next = progress.nextCheckpoint {
            HStack {
                VStack(alignment: .leading) {
                    Text("次の地点").font(.caption).foregroundStyle(.secondary)
                    Text(next.name).font(.title3).bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("あと").font(.caption).foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", progress.metersToNext / 1000.0)) km")
                        .font(.title3).bold()
                }
            }
            .padding()
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var achievementPercent: Int {
        guard dailyGoal > 0 else { return 0 }
        return Int(Double(todaySteps) / Double(dailyGoal) * 100)
    }
}

#Preview {
    JourneyHUD(
        todaySteps: 5400,
        dailyGoal: 8000,
        progress: JourneyEngine.computeProgress(
            totalSteps: 200_000, route: JourneyRoute.tokyoToHakata
        )
    )
    .padding()
}
```

- [ ] **Step 2: `WalkView.swift` を更新して HUD を組み込む**

`WorkoutTracker/Features/Walk/WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                        .padding(.horizontal)
                    JourneyHUD(
                        todaySteps: journey.todaySteps,
                        dailyGoal: dailyGoal,
                        progress: journey.progress
                    )
                    .padding(.horizontal)
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
            }
            .onDisappear {
                journey.stopObserving()
            }
        }
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 3: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/Features/Walk
git commit -m "✨ feat: Walk タブに HUD（歩数・目標・次の地点）を追加"
```

---

## Task 13: TimeOfDayBackground（時刻に応じた背景）

**Files:**
- Create: `WorkoutTracker/Features/Walk/TimeOfDayBackground.swift`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

朝・昼・夕・夜の 4 段階のグラデーション背景。

- [ ] **Step 1: `TimeOfDayBackground.swift` を作成**

`WorkoutTracker/Features/Walk/TimeOfDayBackground.swift`:

```swift
import SwiftUI

struct TimeOfDayBackground: View {
    let timeOfDay: TimeOfDay

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .top)
    }

    private var colors: [Color] {
        switch timeOfDay {
        case .morning: return [Color(red: 1.00, green: 0.85, blue: 0.65),
                               Color(red: 1.00, green: 0.95, blue: 0.85)]
        case .day:     return [Color(red: 0.65, green: 0.85, blue: 1.00),
                               Color(red: 0.90, green: 0.97, blue: 1.00)]
        case .evening: return [Color(red: 1.00, green: 0.55, blue: 0.40),
                               Color(red: 0.95, green: 0.75, blue: 0.55)]
        case .night:   return [Color(red: 0.10, green: 0.15, blue: 0.40),
                               Color(red: 0.20, green: 0.25, blue: 0.55)]
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(TimeOfDay.allCases, id: \.self) { tod in
            TimeOfDayBackground(timeOfDay: tod)
                .frame(height: 100)
                .overlay(Text(tod.rawValue).foregroundStyle(.white))
        }
    }
}
```

- [ ] **Step 2: `WalkView.swift` の背景に組み込む**

`WalkView.swift` の `ScrollView` を `ZStack` で囲って背景を敷く。`WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    private var timeOfDay: TimeOfDay { .from(Date()) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                TimeOfDayBackground(timeOfDay: timeOfDay)
                    .frame(height: 220)

                ScrollView {
                    VStack(spacing: 16) {
                        WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                            .padding(.horizontal)
                        JourneyHUD(
                            todaySteps: journey.todaySteps,
                            dailyGoal: dailyGoal,
                            progress: journey.progress
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
            }
            .onDisappear {
                journey.stopObserving()
            }
        }
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 3: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/Features/Walk
git commit -m "✨ feat: 時刻に応じた朝/昼/夕/夜の背景グラデーション"
```

---

## Task 14: CompanionBubble（キャラ + セリフ）

**Files:**
- Create: `WorkoutTracker/Features/Walk/CompanionBubble.swift`
- Create: `WorkoutTracker/Resources/Assets.xcassets/Companion/Contents.json`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

シンプルなキャラ表現としてシステム絵文字を使い、セリフバブルを表示する（画像アセットは将来差し替え）。

- [ ] **Step 1: Companion アセットフォルダのプレースホルダ**

`WorkoutTracker/Resources/Assets.xcassets/Companion/Contents.json`:

```json
{ "info": { "author": "xcode", "version": 1 } }
```

注: 実画像は将来追加。MVP は SF Symbol で代替。

- [ ] **Step 2: `CompanionBubble.swift` を作成**

`WorkoutTracker/Features/Walk/CompanionBubble.swift`:

```swift
import SwiftUI

struct CompanionBubble: View {
    let line: String
    let mood: Mood

    enum Mood { case neutral, cheer, celebrate }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())

            Text(line)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var symbolName: String {
        switch mood {
        case .neutral:   return "figure.walk"
        case .cheer:     return "figure.walk.motion"
        case .celebrate: return "party.popper"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CompanionBubble(line: "おはよう。あと 3,200 歩で目標。", mood: .neutral)
        CompanionBubble(line: "目標達成！えらい！", mood: .celebrate)
    }
    .padding()
}
```

- [ ] **Step 3: `WalkView.swift` にバブルを差し込む**

`WalkView.swift` の VStack に CompanionBubble を追加。`WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @State private var lastCompanionLine: String?

    private var timeOfDay: TimeOfDay { .from(Date()) }

    private var companionLine: String {
        CompanionDialog.line(
            progress: journey.progress,
            todaySteps: journey.todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
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
            ZStack(alignment: .top) {
                TimeOfDayBackground(timeOfDay: timeOfDay)
                    .frame(height: 220)

                ScrollView {
                    VStack(spacing: 16) {
                        CompanionBubble(line: companionLine, mood: companionMood)
                            .padding(.horizontal)
                            .onAppear { lastCompanionLine = companionLine }

                        WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                            .padding(.horizontal)
                        JourneyHUD(
                            todaySteps: journey.todaySteps,
                            dailyGoal: dailyGoal,
                            progress: journey.progress
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
            }
            .onDisappear {
                journey.stopObserving()
            }
        }
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 4: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Walk WorkoutTracker/Resources/Assets.xcassets/Companion
git commit -m "✨ feat: お供キャラのセリフバブルを Walk タブに表示"
```

---

## Task 15: CelebrationOverlay（紙吹雪・触覚・サウンド + 到達演出）

**Files:**
- Create: `WorkoutTracker/Features/Walk/CelebrationOverlay.swift`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

未演出の `CheckpointAchievement` をフルスクリーンモーダルで順次再生する。`@AppStorage` のトグルで紙吹雪・サウンド・触覚を個別に切替可能。

- [ ] **Step 1: `CelebrationOverlay.swift` を作成**

`WorkoutTracker/Features/Walk/CelebrationOverlay.swift`:

```swift
import SwiftUI
import AVFoundation
import UIKit

struct CelebrationOverlay: View {
    let achievement: CheckpointAchievement
    let checkpoint: Checkpoint
    let onDismiss: () -> Void

    @AppStorage("walk.celebrationConfettiEnabled") private var confettiEnabled: Bool = true
    @AppStorage("walk.celebrationSoundEnabled") private var soundEnabled: Bool = true
    @AppStorage("walk.celebrationHapticEnabled") private var hapticEnabled: Bool = true

    @State private var confettiTrigger: Int = 0
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🎉 \(checkpoint.name) に到着！")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(checkpoint.blurb)
                        .font(.body)
                    Divider()
                    HStack {
                        Label("\(achievement.totalStepsAtAchievement) 歩", systemImage: "figure.walk")
                        Spacer()
                        Text(achievement.achievedAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Label("バッジ獲得", systemImage: "rosette")
                    .font(.headline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.yellow.opacity(0.6), in: Capsule())

                Button("OK") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            .padding()

            if confettiEnabled {
                ConfettiView(trigger: confettiTrigger).allowsHitTesting(false)
            }
        }
        .onAppear {
            if hapticEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if soundEnabled { playSound() }
            confettiTrigger += 1
        }
        .onTapGesture { onDismiss() }
    }

    private func playSound() {
        // システムサウンド (短い達成音)。専用音源は将来差し替え。
        AudioServicesPlaySystemSound(1025)  // SMS-Received1（軽い達成感）
    }
}

/// 簡易紙吹雪（Canvas + SwiftUI animation）
struct ConfettiView: View {
    var trigger: Int
    @State private var particles: [Particle] = []

    var body: some View {
        Canvas { ctx, size in
            for p in particles {
                let rect = CGRect(x: p.x, y: p.y, width: 8, height: 4)
                ctx.fill(Path(rect), with: .color(p.color))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: trigger) { _, _ in spawn() }
        .onAppear { spawn() }
    }

    private func spawn() {
        let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .pink, .purple]
        particles = (0..<60).map { _ in
            Particle(x: .random(in: 0...400), y: -20,
                     color: palette.randomElement() ?? .yellow,
                     vy: .random(in: 200...600),
                     vx: .random(in: -80...80))
        }
        Task { @MainActor in
            let start = Date()
            while Date().timeIntervalSince(start) < 2.5 {
                try? await Task.sleep(nanoseconds: 16_000_000)
                let dt: Double = 0.016
                particles = particles.map { p in
                    var n = p
                    n.x += p.vx * dt
                    n.y += p.vy * dt
                    return n
                }
            }
            particles = []
        }
    }

    struct Particle {
        var x: Double
        var y: Double
        let color: Color
        let vy: Double
        let vx: Double
    }
}

#Preview {
    CelebrationOverlay(
        achievement: CheckpointAchievement(
            checkpointId: "yokohama",
            achievedAt: Date(),
            totalStepsAtAchievement: 30_000
        ),
        checkpoint: JourneyRoute.tokyoToHakata[1],
        onDismiss: {}
    )
}
```

- [ ] **Step 2: `WalkView.swift` で演出キューを再生**

`WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @State private var lastCompanionLine: String?
    @State private var activeCelebration: CheckpointAchievement?

    private var timeOfDay: TimeOfDay { .from(Date()) }

    private var companionLine: String {
        CompanionDialog.line(
            progress: journey.progress,
            todaySteps: journey.todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
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
            ZStack(alignment: .top) {
                TimeOfDayBackground(timeOfDay: timeOfDay)
                    .frame(height: 220)

                ScrollView {
                    VStack(spacing: 16) {
                        CompanionBubble(line: companionLine, mood: companionMood)
                            .padding(.horizontal)
                            .onAppear { lastCompanionLine = companionLine }

                        WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                            .padding(.horizontal)
                        JourneyHUD(
                            todaySteps: journey.todaySteps,
                            dailyGoal: dailyGoal,
                            progress: journey.progress
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("旅")
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
                presentNextCelebrationIfNeeded()
            }
            .onChange(of: journey.pendingCelebrations.count) { _, _ in
                presentNextCelebrationIfNeeded()
            }
            .onDisappear {
                journey.stopObserving()
            }
            .fullScreenCover(item: $activeCelebration) { ach in
                if let cp = JourneyRoute.tokyoToHakata.first(where: { $0.id == ach.checkpointId }) {
                    CelebrationOverlay(achievement: ach, checkpoint: cp) {
                        journey.markCelebrated(ach)
                        activeCelebration = nil
                    }
                }
            }
        }
    }

    private func presentNextCelebrationIfNeeded() {
        guard activeCelebration == nil else { return }
        activeCelebration = journey.pendingCelebrations.first
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

注: `CheckpointAchievement` を `Identifiable` として使うため、`@Model` クラスは `id: UUID` プロパティ持ちなのでそのまま使える。

- [ ] **Step 3: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/Features/Walk
git commit -m "✨ feat: チェックポイント到達時の祝福演出（紙吹雪・触覚・サウンド）"
```

---

## Task 16: StepHistoryView（歩数履歴グラフ + ストリーク）

**Files:**
- Create: `WorkoutTracker/Features/Walk/StepHistoryView.swift`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

Swift Charts で日別歩数の棒グラフを描画。連続達成日数（`StreakCalculator`）と平均歩数を表示。Walk タブのツールバーから sheet で開く。

- [ ] **Step 1: `StepHistoryView.swift` を作成**

`WorkoutTracker/Features/Walk/StepHistoryView.swift`:

```swift
import SwiftUI
import SwiftData
import Charts

struct StepHistoryView: View {
    @Query(sort: [SortDescriptor(\StepDailyRecord.dayStart, order: .reverse)])
    private var records: [StepDailyRecord]

    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    @State private var rangeDays: Int = 30

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("期間", selection: $rangeDays) {
                        Text("30 日").tag(30)
                        Text("90 日").tag(90)
                    }
                    .pickerStyle(.segmented)
                }

                Section("サマリ") {
                    HStack {
                        SummaryItem(title: "ストリーク", value: "\(streak) 日")
                        Spacer()
                        SummaryItem(title: "平均歩数", value: "\(averageSteps) 歩")
                    }
                }

                Section("日別歩数") {
                    Chart(filtered) { r in
                        BarMark(
                            x: .value("日付", r.dayStart, unit: .day),
                            y: .value("歩数", r.steps)
                        )
                        .foregroundStyle(r.steps >= dailyGoal ? Color.green : Color.orange)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 220)
                }

                Section("記録") {
                    ForEach(filtered) { r in
                        HStack {
                            Text(r.dayStart, style: .date)
                            Spacer()
                            Text("\(r.steps) 歩")
                                .foregroundStyle(r.steps >= dailyGoal ? .green : .primary)
                        }
                    }
                }
            }
            .navigationTitle("歩数履歴")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView(
                        "データなし",
                        systemImage: "figure.walk",
                        description: Text("HealthKit から歩数を取得すると表示されます")
                    )
                }
            }
        }
    }

    private var filtered: [StepDailyRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
        return records.filter { $0.dayStart >= cutoff }.sorted { $0.dayStart < $1.dayStart }
    }

    private var streak: Int {
        StreakCalculator.currentStreak(records: records, dailyGoal: dailyGoal)
    }

    private var averageSteps: Int {
        guard !filtered.isEmpty else { return 0 }
        return filtered.map(\.steps).reduce(0, +) / filtered.count
    }
}

private struct SummaryItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    StepHistoryView()
        .modelContainer(for: [StepDailyRecord.self, CheckpointAchievement.self], inMemory: true)
}
```

- [ ] **Step 2: `WalkView.swift` のツールバーから sheet で開く**

`WalkView.swift` の `.navigationTitle("旅")` の直後に以下を追加（既存の `.task`, `.onChange`, `.onDisappear`, `.fullScreenCover` の前）:

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button {
            showingHistory = true
        } label: {
            Image(systemName: "chart.bar")
        }
    }
}
.sheet(isPresented: $showingHistory) {
    StepHistoryView()
}
```

`@State` プロパティを追加:

```swift
@State private var showingHistory: Bool = false
```

注: 完成形は次の Task 17 で BadgesView ボタンも追加するので、最終形は Task 17 で示す。Task 16 では、`WalkView.swift` の修正は履歴ボタン追加のみに留める。

`WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @State private var lastCompanionLine: String?
    @State private var activeCelebration: CheckpointAchievement?
    @State private var showingHistory: Bool = false

    private var timeOfDay: TimeOfDay { .from(Date()) }

    private var companionLine: String {
        CompanionDialog.line(
            progress: journey.progress,
            todaySteps: journey.todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
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
            ZStack(alignment: .top) {
                TimeOfDayBackground(timeOfDay: timeOfDay)
                    .frame(height: 220)

                ScrollView {
                    VStack(spacing: 16) {
                        CompanionBubble(line: companionLine, mood: companionMood)
                            .padding(.horizontal)
                            .onAppear { lastCompanionLine = companionLine }

                        WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                            .padding(.horizontal)
                        JourneyHUD(
                            todaySteps: journey.todaySteps,
                            dailyGoal: dailyGoal,
                            progress: journey.progress
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("旅")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingHistory = true } label: {
                        Image(systemName: "chart.bar")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                StepHistoryView()
            }
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
                presentNextCelebrationIfNeeded()
            }
            .onChange(of: journey.pendingCelebrations.count) { _, _ in
                presentNextCelebrationIfNeeded()
            }
            .onDisappear {
                journey.stopObserving()
            }
            .fullScreenCover(item: $activeCelebration) { ach in
                if let cp = JourneyRoute.tokyoToHakata.first(where: { $0.id == ach.checkpointId }) {
                    CelebrationOverlay(achievement: ach, checkpoint: cp) {
                        journey.markCelebrated(ach)
                        activeCelebration = nil
                    }
                }
            }
        }
    }

    private func presentNextCelebrationIfNeeded() {
        guard activeCelebration == nil else { return }
        activeCelebration = journey.pendingCelebrations.first
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 3: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/Features/Walk
git commit -m "✨ feat: 歩数履歴グラフとストリーク表示"
```

---

## Task 17: BadgesView + WalkSettingsView

**Files:**
- Create: `WorkoutTracker/Features/Walk/BadgesView.swift`
- Create: `WorkoutTracker/Features/Walk/WalkSettingsView.swift`
- Create: `WorkoutTracker/Resources/Assets.xcassets/Badges/Contents.json`
- Modify: `WorkoutTracker/Features/Walk/WalkView.swift`

達成バッジ一覧（13 都市分）と、目標歩数 / 演出 ON-OFF / 旅リセットの設定。両方とも sheet で開く。

- [ ] **Step 1: Badges アセットフォルダのプレースホルダ**

`WorkoutTracker/Resources/Assets.xcassets/Badges/Contents.json`:

```json
{ "info": { "author": "xcode", "version": 1 } }
```

注: 実画像は将来追加。MVP は SF Symbol で代替。

- [ ] **Step 2: `BadgesView.swift` を作成**

`WorkoutTracker/Features/Walk/BadgesView.swift`:

```swift
import SwiftUI
import SwiftData

struct BadgesView: View {
    @Query private var achievements: [CheckpointAchievement]

    @State private var detail: Checkpoint?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(JourneyRoute.tokyoToHakata) { cp in
                        BadgeCell(
                            checkpoint: cp,
                            achievement: achievements.first { $0.checkpointId == cp.id }
                        )
                        .onTapGesture {
                            if achievements.contains(where: { $0.checkpointId == cp.id }) {
                                detail = cp
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("バッジ")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $detail) { cp in
                BadgeDetailSheet(checkpoint: cp,
                                 achievement: achievements.first { $0.checkpointId == cp.id })
            }
        }
    }
}

private struct BadgeCell: View {
    let checkpoint: Checkpoint
    let achievement: CheckpointAchievement?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement != nil ? "rosette" : "lock")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(achievement != nil ? .yellow : .gray.opacity(0.5))
            Text(checkpoint.name)
                .font(.caption)
                .foregroundStyle(achievement != nil ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BadgeDetailSheet: View {
    let checkpoint: Checkpoint
    let achievement: CheckpointAchievement?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "rosette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.yellow)
                Text(checkpoint.name).font(.title).bold()
                Text(checkpoint.blurb)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if let a = achievement {
                    VStack {
                        Text("到達日: \(a.achievedAt, style: .date)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(a.totalStepsAtAchievement) 歩で到達")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("バッジ")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    BadgesView()
        .modelContainer(for: [CheckpointAchievement.self, StepDailyRecord.self], inMemory: true)
}
```

- [ ] **Step 3: `WalkSettingsView.swift` を作成**

`WorkoutTracker/Features/Walk/WalkSettingsView.swift`:

```swift
import SwiftUI

struct WalkSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JourneyService.self) private var journey

    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @AppStorage("walk.celebrationConfettiEnabled") private var confettiEnabled: Bool = true
    @AppStorage("walk.celebrationSoundEnabled") private var soundEnabled: Bool = true
    @AppStorage("walk.celebrationHapticEnabled") private var hapticEnabled: Bool = true

    @State private var showResetConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("1 日の歩数目標") {
                    Stepper(value: $dailyGoal, in: 2000...30000, step: 500) {
                        Text("\(dailyGoal) 歩")
                    }
                }
                Section("演出") {
                    Toggle("紙吹雪", isOn: $confettiEnabled)
                    Toggle("達成音", isOn: $soundEnabled)
                    Toggle("触覚フィードバック", isOn: $hapticEnabled)
                }
                Section("旅") {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("旅の進行をリセット", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .confirmationDialog(
                "旅の進行をリセットしますか？歩数履歴は保持されます。",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    journey.resetJourney()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

#Preview {
    WalkSettingsView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 4: `WalkView.swift` のツールバーにバッジ + 設定ボタンを追加**

`WalkView.swift` を以下で置換:

```swift
import SwiftUI

struct WalkView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @State private var lastCompanionLine: String?
    @State private var activeCelebration: CheckpointAchievement?
    @State private var showingHistory: Bool = false
    @State private var showingBadges: Bool = false
    @State private var showingSettings: Bool = false

    private var timeOfDay: TimeOfDay { .from(Date()) }

    private var companionLine: String {
        CompanionDialog.line(
            progress: journey.progress,
            todaySteps: journey.todaySteps,
            dailyGoal: dailyGoal,
            timeOfDay: timeOfDay,
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
            ZStack(alignment: .top) {
                TimeOfDayBackground(timeOfDay: timeOfDay)
                    .frame(height: 220)

                ScrollView {
                    VStack(spacing: 16) {
                        CompanionBubble(line: companionLine, mood: companionMood)
                            .padding(.horizontal)
                            .onAppear { lastCompanionLine = companionLine }

                        WalkMapView(route: JourneyRoute.tokyoToHakata, progress: journey.progress)
                            .padding(.horizontal)
                        JourneyHUD(
                            todaySteps: journey.todaySteps,
                            dailyGoal: dailyGoal,
                            progress: journey.progress
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("旅")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingHistory = true } label: {
                        Image(systemName: "chart.bar")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingBadges = true } label: {
                        Image(systemName: "rosette")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) { StepHistoryView() }
            .sheet(isPresented: $showingBadges) { BadgesView() }
            .sheet(isPresented: $showingSettings) { WalkSettingsView() }
            .task {
                await journey.refreshOnAppear()
                journey.startObserving()
                presentNextCelebrationIfNeeded()
            }
            .onChange(of: journey.pendingCelebrations.count) { _, _ in
                presentNextCelebrationIfNeeded()
            }
            .onDisappear {
                journey.stopObserving()
            }
            .fullScreenCover(item: $activeCelebration) { ach in
                if let cp = JourneyRoute.tokyoToHakata.first(where: { $0.id == ach.checkpointId }) {
                    CelebrationOverlay(achievement: ach, checkpoint: cp) {
                        journey.markCelebrated(ach)
                        activeCelebration = nil
                    }
                }
            }
        }
    }

    private func presentNextCelebrationIfNeeded() {
        guard activeCelebration == nil else { return }
        activeCelebration = journey.pendingCelebrations.first
    }
}

#Preview {
    WalkView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 5: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Features/Walk WorkoutTracker/Resources/Assets.xcassets/Badges
git commit -m "✨ feat: バッジ一覧と Walk 設定ビューを追加"
```

---

## Task 18: HomeView 拡張（今日の歩数ミニカード）

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`

ホームに「今日の歩数」セクションを追加。

- [ ] **Step 1: `HomeView.swift` を更新**

`WorkoutTracker/Features/Home/HomeView.swift` を以下で置換:

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(JourneyService.self) private var journey
    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query(sort: [SortDescriptor(\BodyMetric.recordedAt, order: .reverse)])
    private var metrics: [BodyMetric]

    var body: some View {
        NavigationStack {
            List {
                Section("今日の歩数") {
                    todayWalkCard
                }

                Section("今週のサマリ") {
                    HStack {
                        SummaryTile(title: "セッション", value: "\(weekSessions.count)")
                        SummaryTile(title: "総ボリューム", value: "\(Int(weekVolume.rounded())) kg")
                        SummaryTile(title: "セット", value: "\(weekSets)")
                    }
                }

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

                if let latest = metrics.first {
                    Section("最新の体組成") {
                        HStack {
                            if let w = latest.weightKg {
                                Text("\(String(format: "%.1f", w)) kg").font(.title3)
                            }
                            Spacer()
                            if let f = latest.bodyFatPercent {
                                Text("\(String(format: "%.1f", f)) %").foregroundStyle(.secondary)
                            }
                            Text(latest.recordedAt, style: .date)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("ホーム")
        }
    }

    private var todayWalkCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1.0, Double(journey.todaySteps) / Double(max(1, dailyGoal))))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(achievementPercent) %")
                    .font(.caption).bold()
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(journey.todaySteps) 歩")
                    .font(.title3).bold()
                Text("目標 \(dailyGoal) 歩")
                    .font(.caption).foregroundStyle(.secondary)
                if !journey.progress.isCompleted, let next = journey.progress.nextCheckpoint {
                    Text("旅: \(next.name) まであと \(String(format: "%.1f", journey.progress.metersToNext / 1000.0)) km")
                        .font(.caption).foregroundStyle(.secondary)
                } else if journey.progress.isCompleted {
                    Text("旅: 博多到達！").font(.caption).foregroundStyle(.green)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var achievementPercent: Int {
        guard dailyGoal > 0 else { return 0 }
        return Int(Double(journey.todaySteps) / Double(dailyGoal) * 100)
    }

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

#Preview {
    HomeView()
        .modelContainer(for: [
            WorkoutSession.self, SetRecord.self, Exercise.self, BodyMetric.self,
            StepDailyRecord.self, CheckpointAchievement.self
        ], inMemory: true)
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 2: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 3: コミット**

```bash
git add WorkoutTracker/Features/Home/HomeView.swift
git commit -m "✨ feat: ホームに今日の歩数ミニカードを追加"
```

---

## Task 19: 完走時演出 + DEBUG モードのダミー歩数加算ボタン

**Files:**
- Modify: `WorkoutTracker/Services/JourneyService.swift`
- Modify: `WorkoutTracker/Features/Walk/WalkSettingsView.swift`

シミュレータ等で HealthKit が動かない環境でも演出を確認できるよう DEBUG ビルドのみダミー歩数を +1,000 加算するボタンを追加。完走時はキャラのモードが祝福に変わる（Task 14 で対応済）。

- [ ] **Step 1: `JourneyService` にダミー加算メソッドを追加**

`WorkoutTracker/Services/JourneyService.swift` の末尾に以下を追加:

```swift
#if DEBUG
extension JourneyService {
    /// DEBUG ビルドでのダミー歩数加算。当日の StepDailyRecord に +n する。
    func debugAddSteps(_ n: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var fd = FetchDescriptor<StepDailyRecord>(
            predicate: #Predicate { $0.dayStart == today }
        )
        fd.fetchLimit = 1
        let ctx = container.mainContext
        if let existing = try? ctx.fetch(fd).first {
            existing.steps += n
            existing.lastSyncedAt = Date()
        } else {
            ctx.insert(StepDailyRecord(
                dayStart: today, steps: n, source: .seed, lastSyncedAt: Date()
            ))
        }
        try? ctx.save()
        todaySteps += n
        let started = cal.startOfDay(for: journeyStartedAtProvider() ?? today)
        let total = sumSteps(from: started, to: today)
        progress = JourneyEngine.computeProgress(totalSteps: total, route: route)
        ensureAchievements(totalSteps: total)
        refreshPendingCelebrations()
    }
}
#endif
```

- [ ] **Step 2: `WalkSettingsView.swift` に DEBUG セクションを追加**

`WorkoutTracker/Features/Walk/WalkSettingsView.swift` の `Form` の末尾（旅セクションの後ろ）に以下を追加:

```swift
#if DEBUG
                Section("DEBUG") {
                    Button {
                        journey.debugAddSteps(1000)
                    } label: {
                        Label("歩数 +1,000", systemImage: "plus.circle")
                    }
                    Button {
                        journey.debugAddSteps(30_000)
                    } label: {
                        Label("歩数 +30,000（1 都市進む）", systemImage: "forward.fill")
                    }
                }
#endif
```

最終形の `WalkSettingsView.swift` 全体:

```swift
import SwiftUI

struct WalkSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JourneyService.self) private var journey

    @AppStorage("walk.dailyGoalSteps") private var dailyGoal: Int = 8000
    @AppStorage("walk.celebrationConfettiEnabled") private var confettiEnabled: Bool = true
    @AppStorage("walk.celebrationSoundEnabled") private var soundEnabled: Bool = true
    @AppStorage("walk.celebrationHapticEnabled") private var hapticEnabled: Bool = true

    @State private var showResetConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("1 日の歩数目標") {
                    Stepper(value: $dailyGoal, in: 2000...30000, step: 500) {
                        Text("\(dailyGoal) 歩")
                    }
                }
                Section("演出") {
                    Toggle("紙吹雪", isOn: $confettiEnabled)
                    Toggle("達成音", isOn: $soundEnabled)
                    Toggle("触覚フィードバック", isOn: $hapticEnabled)
                }
                Section("旅") {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("旅の進行をリセット", systemImage: "arrow.counterclockwise")
                    }
                }

#if DEBUG
                Section("DEBUG") {
                    Button {
                        journey.debugAddSteps(1000)
                    } label: {
                        Label("歩数 +1,000", systemImage: "plus.circle")
                    }
                    Button {
                        journey.debugAddSteps(30_000)
                    } label: {
                        Label("歩数 +30,000（1 都市進む）", systemImage: "forward.fill")
                    }
                }
#endif
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .confirmationDialog(
                "旅の進行をリセットしますか？歩数履歴は保持されます。",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    journey.resetJourney()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

#Preview {
    WalkSettingsView()
        .environment(JourneyService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

- [ ] **Step 3: ビルド確認**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/Services/JourneyService.swift WorkoutTracker/Features/Walk/WalkSettingsView.swift
git commit -m "✨ feat: DEBUG モードでダミー歩数を加算するボタン"
```

---

## Task 20: 動作確認（ビルド + テスト + シミュレータ起動チェック）

**Files:** なし（最終ビルドと SwiftUI Preview スナップ確認のみ）

最終的に全テスト PASS / ビルド成功を確認し、必要なら SwiftUI Preview で各画面を目視。

- [ ] **Step 1: クリーンビルド + テスト**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17' clean build test
```

Expected: BUILD SUCCEEDED + すべてのテスト PASS。

- [ ] **Step 2: 既存機能の動作確認チェックリスト**

シミュレータで起動して以下をクリックで確認:

- [ ] ホームタブが表示され、「今日の歩数」セクションが追加されている
- [ ] 旅タブを開くと CompanionBubble・マップ・HUD が表示される
- [ ] 旅タブの設定 → DEBUG セクション → 「歩数 +30,000」を 5 回タップで横浜・熱海・静岡・浜松・名古屋に到達。CelebrationOverlay が順次再生される
- [ ] バッジ一覧で到達済みのバッジが点灯する
- [ ] 設定 → 旅をリセット → 旅タブで進行が 0 km に戻る
- [ ] 既存の記録/メニュー/履歴タブは従来通り動作する

メモ: シミュレータでは HealthKit から歩数が取れないため、DEBUG ボタンで歩数を投入して動作確認する。

- [ ] **Step 3: コミット（特に変更がなければスキップ）**

ビルド・テストの状態確認のみで変更がなければコミット不要。確認結果を README に簡単に追記する場合のみコミット。

```bash
# 変更があった場合のみ
git status
```

---

## まとめ

実装後の追加ファイル数:

- 新規ソース: 13 ファイル（Models 2 / Domain 4 / Services 1 / Features/Walk 8 / App は既存変更）
- 新規テスト: 6 ファイル
- 既存変更: 6 ファイル（Enums.swift / ModelContainerFactory.swift / InMemoryContainer.swift / HealthKitService.swift / WorkoutTrackerApp.swift / RootView.swift / HomeView.swift / project.yml / Info.plist）

総コミット数: 19（Task 1〜19、Task 20 はビルド検証のみ）

すべて 1 コミット = 1 タスクの粒度で進め、各 commit は単独で動作するよう Task を組んでいる。
