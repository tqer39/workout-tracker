# 睡眠記録機能 設計書

**作成日:** 2026-05-08
**対象:** iOS（Apple Watch を併用するユーザー向け）

## 目的

Apple Watch が記録した睡眠データを HealthKit から取り込み、トレーニング履歴と並べて可視化する。睡眠時間とその日の総ボリュームを 1 つのグラフに重ねて表示することで「よく寝た日 / 寝てない日」とトレーニング負荷の傾向が一目で見えることを目指す。

ゲーム化要素・お供キャラの台詞・睡眠スコアなどは出さず、「数字とグラフ」によるシンプルな可視化に絞る。

## スコープ

### やること

- HealthKit `sleepAnalysis` から睡眠サンプルを取得し、夜単位（終わった朝の日付）に集約して SwiftData にキャッシュする
- 履歴タブに 4 つ目のセグメント「睡眠」を追加し、30 日 / 90 日切替の棒グラフ（睡眠時間）に総ボリュームを重ねて表示する
- ホームタブに「昨夜の睡眠」ミニカードを追加（円形プログレス + 数字）
- 記録タブヘッダーに「昨夜 ◯.◯h」を 1 行で軽く表示
- 1 日の睡眠目標時間を `@AppStorage` で設定可能にする（既定 7.0h、5.0h–10.0h 0.5 刻み）
- 達成日は緑、未達日はオレンジでバーを色分けする

### やらないこと

- 手動入力（HealthKit にデータがない夜はグラフ上で空欄）
- 睡眠ステージ（REM/コア/深い）の表示
- 就寝時刻 / 起床時刻の表示
- 推奨ロジック（「今日は休んだ方がいい」などの介入）
- 睡眠用のお供キャラ・台詞・演出
- バッジ / 連続記録の祝福ポップアップ
- 通知・アラーム

## アーキテクチャ

Walk タブと同型の構成を採用する。`JourneyService` が果たした役割を `SleepService` が担い、`StepDailyRecord` と並列に `SleepDailyRecord` を SwiftData に置く。HealthKit アクセスは既存 `HealthKitService` プロトコルを拡張して同居させる。

## データモデル

### `SleepDailyRecord`（新規 SwiftData モデル）

```swift
@Model
final class SleepDailyRecord {
    var id: UUID
    @Attribute(.unique) var dayStart: Date  // その睡眠が「終わった朝」の Calendar.startOfDay
    var totalMinutes: Int                   // 1 晩の合計睡眠時間（asleep 状態の合計、分単位）
    var source: SleepSource                 // .healthKit / .seed
    var lastSyncedAt: Date
}

enum SleepSource: String, Codable {
    case healthKit
    case seed   // テスト / シード投入用
}
```

`dayStart` の規則:

- HealthKit から取った各 `HKCategorySample` の `endDate` を基に、その日の `Calendar.current.startOfDay(for: endDate)` を集約キーとする
- 複数サンプル（断片化された睡眠）は同じ `dayStart` に属するものを合算

### DTO

```swift
struct SleepDailyDTO: Sendable, Equatable {
    let dayStart: Date
    let totalMinutes: Int
    let source: SleepSource
}
```

サービス層は `@Model` を直接返さず DTO を返す（既存 `BodyMetricDTO` / `StepDailyDTO` と同じ規約）。

### `ModelContainerFactory`

スキーマに `SleepDailyRecord.self` を追加。

## 集約ロジック（純粋関数）

### `Domain/SleepAggregator.swift`（新規）

```swift
enum SleepAggregator {
    /// HealthKit から取得した複数の睡眠区間を、終わった朝の日付ごとに合算する。
    /// `inBed` は除外し、`asleep*`（asleepUnspecified / asleepCore / asleepREM / asleepDeep）の合計のみを使う。
    static func aggregate(
        samples: [SleepSample],
        calendar: Calendar = .current
    ) -> [SleepDailyDTO]
}

struct SleepSample: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let isAsleep: Bool   // asleep* なら true、inBed なら false
}
```

`SleepSample` は HealthKit 型から切り離した純粋値型にすることで、`SleepAggregator` を HealthKit に依存させずユニットテスト可能にする。

集約ルール:

- `isAsleep == false` のサンプルはスキップ
- 残ったサンプルの `endDate.startOfDay` をキーに、各サンプル区間の長さ（秒）を合計
- 60 秒で割って分単位の `Int` に変換
- 同じ朝に属するすべてのサンプルが合算された 1 件の DTO を返す

## サービス層

### `HealthKitService` プロトコル拡張

```swift
protocol HealthKitService {
    // ...既存メソッド...
    func requestSleepAuthorization() async throws
    func fetchSleep(from: Date, to: Date) async throws -> [SleepDailyDTO]
}
```

#### `LiveHealthKitService`

- `requestSleepAuthorization()`: `HKCategoryType(.sleepAnalysis)` を read 集合に追加して `requestAuthorization` を呼ぶ
- `fetchSleep(from:to:)`: `HKSampleQuery` で `categoryType(.sleepAnalysis)` を取得し、各 `HKCategorySample` を `SleepSample` に詰めて `SleepAggregator.aggregate(...)` に渡す
  - `value` が `HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue` などのいずれかを `isAsleep = true` とする
  - `inBed` および `awake` は `isAsleep = false`
- 取得期間は呼び出し側が指定（`SleepService.bootstrap()` は過去 90 日、`refreshOnAppear()` は当日のみ）

#### `StubHealthKitService`（テスト用）

- 既存の `HealthKitServiceTests` に同居しているスタブ実装を拡張
- `var sleepData: [SleepDailyDTO]` を追加し、`fetchSleep` がそれを返すだけ
- `requestSleepAuthorization` は何もしない

### `SleepService`（新規）

```swift
@MainActor
@Observable
final class SleepService {
    var lastNightMinutes: Int?
    var targetMinutes: Int { ... }  // @AppStorage 読み出しのラッパ

    private let healthKit: HealthKitService
    private let container: ModelContainer

    init(healthKit: HealthKitService, container: ModelContainer)

    func bootstrap() async        // 起動時、過去 90 日 fetch → upsert、認可要求も内側で
    func refreshOnAppear() async  // タブ表示時、当日のみ再取得
}
```

`JourneyService` と同じく:

- `@MainActor` で SwiftData の `mainContext` を扱う
- 内部で `upsert(dtos:)` を持ち、`@Attribute(.unique) dayStart` のおかげで重複は自動的に上書きされる
- `lastNightMinutes` は最新の `SleepDailyRecord` の `totalMinutes` を反映

`bootstrap()` の流れ:

1. `requestSleepAuthorization()` を呼ぶ（既に認可済みなら no-op）
2. `fetchSleep(from: 90 日前, to: 今日)` で取得
3. `upsert(dtos:)` で SwiftData に書き込む
4. `lastNightMinutes` を最新レコードから設定

## UI 層

### `Features/History/HistoryView.swift`（修正）

`Tab` enum に `.sleep = "睡眠"` を追加し、segmented picker を 4 セグメント化:

```swift
enum Tab: String, CaseIterable, Identifiable {
    case sessions = "セッション"
    case charts = "グラフ"
    case body = "体組成"
    case sleep = "睡眠"
    var id: String { rawValue }
}
```

`switch tab` に `.sleep: SleepHistoryView()` を追加。

### `Features/Sleep/SleepHistoryView.swift`（新規）

レイアウト:

```
+--------------------------------------+
| Picker: 30 日 / 90 日                |
+--------------------------------------+
| サマリ                                |
|   平均睡眠: 6.8h   ストリーク: 3 日   |
+--------------------------------------+
| Chart (高さ 220)                      |
|   BarMark: 睡眠時間 (緑/オレンジ)     |
|   LineMark: 総ボリューム (右軸)       |
+--------------------------------------+
| 日別リスト                            |
|   2026-05-07  7.2h  vol 4500 kg      |
|   2026-05-06  5.8h  vol --           |
|   ...                                 |
+--------------------------------------+
```

データ:

- `@Query(sort: [SortDescriptor(\SleepDailyRecord.dayStart, order: .reverse)]) private var records: [SleepDailyRecord]`
- `@Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]) private var sessions: [WorkoutSession]`
- `@AppStorage("sleep.targetHours") private var targetHours: Double = 7.0`
- `@State private var rangeDays: Int = 30`
- 期間内の各日について `(SleepDailyRecord?, dailyVolume: Double)` を計算。`dailyVolume` は当日に `startedAt` を持つ `WorkoutSession` の `sets` を `WorkoutMetrics.totalVolume(sets:)` で合算した値
- 達成判定: `Double(record.totalMinutes) / 60.0 >= targetHours` なら緑、未満ならオレンジ
- ストリーク: 終端日（今日 or 昨日）から遡って連続して目標達成している日数。`Domain/SleepStreak.swift` に純粋関数 `SleepStreak.currentStreak(records:targetMinutes:today:calendar:)` として新規導入する（既存 `StreakCalculator` は歩数固有の閾値ロジックなので、無理に共通化せず並列に置く）。今日が未達なら昨日から遡って数える挙動は `StreakCalculator` と同じ
- 空欄日はバーを描かず、リストでは「--」表示
- `ContentUnavailableView`: `records.isEmpty` のときに「データなし／HealthKit から睡眠を取得すると表示されます」

ツールバー右上に歯車アイコン → `SleepSettingsView` を sheet で開く。

### `Features/Sleep/SleepSettingsView.swift`（新規）

```
Form
  Section("睡眠目標時間")
    Stepper(value: $targetHours, in: 5.0...10.0, step: 0.5) { Text("\(targetHours, specifier: "%.1f") h") }
```

`@AppStorage("sleep.targetHours")` のみを書き換える。リセット系は不要。

### `Features/Home/HomeView.swift`（修正）

既存の「今日の歩数」セクションのすぐ下に「昨夜の睡眠」セクションを追加:

```
HStack {
    ZStack {
        Circle().stroke(...)  // ベースリング
        Circle().trim(from: 0, to: progress).stroke(...)  // 達成リング
        Text("◯%")            // 達成率（目標に対する割合、上限 100%）
    }
    .frame(width: 56, height: 56)

    VStack(alignment: .leading) {
        Text("\(formattedHours) h")  // 例: "7.2 h"
        Text("目標 \(targetHours) h")
        // データなしの夜は「昨夜の記録なし」
    }
    Spacer()
}
```

`SleepService` を `@Environment(SleepService.self)` で取り出し、`lastNightMinutes` を表示する。

### `Features/Recording/RecordingView.swift`（修正）

既存ヘッダーの上端、テンプレ選択の前に Caption 1 行:

```swift
if let m = sleep.lastNightMinutes {
    Text("昨夜 \(formattedHours(m)) h")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
}
```

データがない夜は何も表示しない（高さ変化が起きるが、レイアウト上問題ない位置）。

### App 統合

`WorkoutTrackerApp.swift`:

- `let sleep = SleepService(healthKit: hk, container: container)` を追加
- `.environment(sleep)` を Root に注入
- 起動時 `Task { await sleep.bootstrap() }` を `journey.bootstrap()` と並列で呼ぶ

## 設定 / 権限

### `@AppStorage` キー

| キー | 型 | 既定値 | 用途 |
|------|------|--------|------|
| `sleep.targetHours` | Double | `7.0` | 目標睡眠時間（5.0〜10.0、0.5 刻み） |

### `Info.plist`

`NSHealthShareUsageDescription` の文言を更新:

> 体重・体脂肪率・歩数・睡眠の推移をアプリに取り込みます。

`project.yml` の `NSHealthShareUsageDescription` を更新し、`xcodegen generate` で反映。

### HealthKit 認可セット

`LiveHealthKitService.requestSleepAuthorization()` 内で読み込み権限に `HKCategoryType(.sleepAnalysis)` を追加。既存の歩数・体組成の認可と統合する形でも、独立して呼ぶ形でも、いずれでも実装可能（実装時に既存パターンに合わせる）。

## エラーハンドリング

- HealthKit 認可拒否: `requestSleepAuthorization()` が throw した場合は `bootstrap()` 内で握りつぶし、`lastNightMinutes` は nil のまま。UI は「データなし」状態になる
- HealthKit fetch エラー: `try?` で nil 化（既存の歩数取得と同様）
- SwiftData save エラー: `try?` で握りつぶす（致命的にしない、既存パターン踏襲）

## テスト

### 新規テスト

| ファイル | 内容 |
|---------|------|
| `Models/SleepDailyRecordTests.swift` | `@Attribute(.unique) dayStart` で重複夜が自動上書きされること、基本属性の保存/取得 |
| `Domain/SleepAggregatorTests.swift` | (a) 単一夜の単純合計、(b) 同夜内の複数サンプル合算、(c) `inBed` がスキップされること、(d) 夜またぎ（22:00→翌 06:00）が「終わった朝」に集約されること、(e) 別日の 2 夜が 2 件の DTO になること |
| `Domain/SleepStreakTests.swift` | (a) 連続達成、(b) 今日が未達でも昨日から遡って数えること、(c) 途切れたら 0 |
| `Services/HealthKitServiceTests.swift`（拡張） | `StubHealthKitService.sleepData` がそのまま `fetchSleep` から返ること |
| `Services/SleepServiceTests.swift` | bootstrap 後に SwiftData に upsert され `lastNightMinutes` が反映されること、再 bootstrap で重複が増えないこと |

合計 **約 10 テスト追加**。

### 既存テスト

`InMemoryContainer.make()` が読むスキーマに `SleepDailyRecord.self` を追加するため、既存テストはスキーマ追加だけで通り続けることを確認する。

## 実装規模 / 想定タスク数

新規ファイル:
- `Models/SleepDailyRecord.swift`
- `Domain/SleepAggregator.swift`
- `Domain/SleepStreak.swift`
- `Services/SleepService.swift`
- `Features/Sleep/SleepHistoryView.swift`
- `Features/Sleep/SleepSettingsView.swift`
- 上記に対応するテストファイル群

修正ファイル:
- `Models/Enums.swift`（`SleepSource` 追加）
- `Models/ModelContainerFactory.swift` / `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`
- `Services/HealthKitService.swift`（プロトコル拡張 + Live 実装）
- `WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift`（Stub 拡張）
- `Features/History/HistoryView.swift`（4 セグメント化）
- `Features/Home/HomeView.swift`（ミニカード追加）
- `Features/Recording/RecordingView.swift`（ヘッダー 1 行追加）
- `App/WorkoutTrackerApp.swift`（SleepService 注入）
- `project.yml`（`NSHealthShareUsageDescription` 文言更新）

実装計画は **約 10 タスク**（TDD 単位）に分解する見込み。Walk 機能（20 タスク）の半分程度。

## 補足: 「終わった朝」採用理由

夜またぎ睡眠（22:00 月曜 → 06:00 火曜）を「月曜のレコード」にすると、火曜の朝にアプリを開いたときに前夜の睡眠が「昨日のもの」として隠れる UX になりがちになる。「火曜の起床睡眠」として火曜にひも付けると、「昨夜の睡眠」と「今日のトレーニング」が同じ日付軸に乗り、ホームのミニカード・記録タブヘッダー・履歴グラフのいずれでも自然な並びになる。
