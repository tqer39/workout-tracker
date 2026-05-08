# 万歩計 + バーチャル旅行機能 設計書

- 作成日: 2026-05-08
- ステータス: 実装計画待ち
- 対象ブランチ: worktree `worktree-ccw-tqer39-workout-tracker-260508-121644`
- 関連 spec: `docs/superpowers/specs/2026-04-20-workout-tracker-ios-design.md`

## 1. 目的とスコープ

既存の workout-tracker iOS アプリに「歩数管理 + バーチャル旅行（東京 → 博多）」機能を追加し、日々のモチベーション維持と楽しさを補強する。筋トレ記録の硬派さは保ちつつ、別タブとして柔らかい体験層を共存させる。

### スコープ内（MVP）

- HealthKit からの日別歩数同期と履歴表示（日次・週次グラフ）
- 当日の歩数のリアルタイム/準リアルタイム表示（HealthKit Observer + foreground 更新）
- 1 日の歩数目標の設定（既定 8,000 歩）と達成ゲージ
- 連続達成日数（ストリーク）の計算と表示
- バーチャル旅行: 東京 → 博多 1 ルート固定（13 チェックポイント）
- 専用タブ「旅」+ 日本列島の簡略イラストマップ + 進行ピン
- チェックポイント到達演出（紙吹雪・触覚・サウンド・名物紹介カード）
- 達成バッジ一覧
- 旅のお供キャラのセリフバブル（1 種類 + 表情差分）
- 時刻に応じた背景の昼夜変化（朝・昼・夕・夜の 4 段階）
- ホームタブに「今日の歩数 / 目標進捗 / 旅の進行」ミニカードを追加

### スコープ外（本バージョン）

- 複数ルート / 世界一周ループ（将来拡張）
- ホーム画面ウィジェット
- Apple Watch アプリ
- iCloud / CloudKit 同期
- 歩数の手入力（HealthKit 拒否時は空表示 + 設定アプリ導線のみ）
- ソーシャル機能（シェア・ランキング）
- App Store 配布
- 多言語対応（日本語のみ）
- 月単位の季節変化（背景の昼夜のみ実装）
- 歩幅のユーザー設定（ゲーム的に **1 歩 = 1 m** 固定）

## 2. 前提と制約

- 対応 OS: iOS 18 以降（既存 spec と同じ）
- 言語: Swift 5.10 以降、SwiftUI、SwiftData
- 永続化: SwiftData（ローカルのみ）。シングル値設定は `@AppStorage`（UserDefaults）
- HealthKit 権限が前提。拒否時は機能停止 + 再認証導線のみ
- マップは Apple MapKit を使わず、自前のイラスト画像（PDF または SVG ベクター 1 枚）+ 正規化座標で進行ピンを配置
- 歩数 → 距離変換: **1 歩 = 1 m**（ゲーム的単純化、約 144 日で完走想定 @ 8,000 歩/日）
- ルート総距離: 1,150 km = 1,150,000 歩（東京-博多の概算）
- iPhone のみ対応（既存 spec と同じ）
- ライト/ダーク両対応

## 3. アーキテクチャ

既存の SwiftUI + SwiftData + MV パターンに統合する。新規モジュールは `Features/Walk/`、`Domain/` 配下にロジック、`Services/` は既存の `HealthKitService` を歩数取得まで拡張する。

```
┌──────────────────────────────────────────────┐
│              SwiftUI Views                   │
│   TabView: Home / Recording / Menu /         │
│            History / Walk (新規)             │
└───────────────┬──────────────────────────────┘
                │ @Query / @Observable
                ▼
┌──────────────────────────────────────────────┐
│            Domain（純粋ロジック）             │
│   - JourneyEngine (累積歩数 → 進行 km        │
│     → 通過チェックポイント判定)              │
│   - JourneyRoute (東京-博多の静的データ)     │
│   - StreakCalculator (連続達成日数)          │
│   - CompanionDialog (セリフ辞書)             │
└───────────────┬──────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────────────┐
│           Services 層                        │
│   - HealthKitService                         │
│       既存: 体組成                           │
│       追加: 日別歩数取得 + Observer Query    │
│   - JourneyService（新規・@Observable）      │
│   - NotificationService（既存・変更なし）    │
│   - RestTimer（既存・変更なし）              │
└───────────────┬──────────────────────────────┘
                ▼
┌──────────────────────────────────────────────┐
│      SwiftData ModelContainer                │
│  既存: Exercise / Template / Session /       │
│       SetRecord / BodyMetric                 │
│  追加: StepDailyRecord /                     │
│       CheckpointAchievement                  │
└──────────────────────────────────────────────┘
```

設計上のポイント:

- `JourneyEngine` は純粋関数の集合（入力: 累積歩数 + ルート定義、出力: 進行 km・最後に通過したチェックポイント・次の地点・進行率）。テストしやすさを最優先
- `HealthKitService` は protocol を維持し、`fetchDailySteps(from:to:)` と `observeTodaySteps(_:)` を追加。既存の体組成メソッドはそのまま
- 演出（紙吹雪・触覚・サウンド）は `CelebrationOverlay` ビュー側に閉じる。Engine は「未演出のチェックポイント到達」を返すだけ
- お供キャラのセリフは静的辞書（時間帯・進行率・歩数達成度に応じたフレーズ集）。サーバ通信なし

## 4. 画面構成

タブを 4 → 5 に増やす。順序は左から **Home / Recording / Menu / History / Walk**。

### 4.1 Walk タブ（新規・メイン）

縦に 3 ゾーン構成:

- **上部（時間帯背景 + キャラバブル）**: 時刻に応じた朝/昼/夕/夜のグラデーション背景。お供キャラ（中央 or 右下に立ち絵）+ 吹き出しで「今日もお疲れさま！あと 1,200 歩で次の地点だよ」など
- **中央（イラストマップ + 進行ピン）**: 日本列島の簡略イラスト。東京から博多までのルートライン上に、通過済みの 13 チェックポイントを点灯、未到達は薄く表示。現在地は脈動アニメするピン
- **下部（HUD）**: 「今日の歩数 / 目標 8,000 歩 / 達成率」「旅の進行 ◯◯ km / 1,150 km / 残り ◯ km」「次のチェックポイント: ◯◯ まで ◯ km」を縦並び。右上に設定アイコン（目標歩数変更）、左上にバッジ一覧へのアイコン

下にスクロール、もしくはセクション切替で「歩数履歴グラフ」へ遷移可能（sheet または NavigationStack）。

### 4.2 チェックポイント到達演出（モーダル）

Walk タブを開いて未演出の到達があれば、自動でフルスクリーンモーダル発火:

- 紙吹雪パーティクル（数秒）
- 触覚（`UINotificationFeedbackGenerator.success`）
- サウンド（短い達成音 1 種、サイレント時は無音）
- 中央に「**◯◯ に到着！**」の大見出し + 名物紹介カード（地点名・累積歩数・到達日時・1〜3 行の紹介文）+ 「バッジを獲得しました」ラベル
- 「OK」または画面タップで閉じる

複数の未演出地点があれば順次再生（早送り可）。

### 4.3 歩数履歴ビュー（Walk タブ内 Sheet）

- Swift Charts で日別棒グラフ（直近 30 日 / 90 日切替）
- 平均歩数・連続達成日数（ストリーク）の数値表示
- 履歴の単一日タップで「その日の歩数 / 旅の進行貢献 km」を表示

### 4.4 バッジ一覧ビュー（Walk タブ内 Sheet）

- 13 チェックポイント分のバッジをグリッドで表示
- 未取得は灰色シルエット、取得済みはカラー + 取得日
- バッジタップで該当チェックポイントの紹介カードを再表示

### 4.5 Walk 設定ビュー（Walk タブ内 Sheet）

- 1 日の歩数目標（数値入力、500 刻み、2,000〜30,000）
- 演出 ON/OFF（紙吹雪・サウンド・触覚を個別トグル）
- 旅の進行リセット（確認ダイアログ）

### 4.6 ホームタブ拡張

既存の Home に「今日の歩数」ミニカードを追加:

- 今日の歩数 / 目標 / 達成リング（小）
- 「旅: 横浜まであと ◯ km」のサブテキスト
- タップで Walk タブへ遷移

## 5. データモデル

### 5.1 SwiftData エンティティ（追加分）

```swift
@Model class StepDailyRecord {
  var id: UUID
  var dayStart: Date          // 暦日の開始（ローカルタイム 00:00）。一意
  var steps: Int              // その日の歩数
  var source: StepSource      // .healthKit / .seed（テスト用）
  var lastSyncedAt: Date      // HealthKit から最後に取得した時刻
}

@Model class CheckpointAchievement {
  var id: UUID
  var checkpointId: String    // ルート定義の Checkpoint.id と一致
  var achievedAt: Date        // 到達検知された日時
  var totalStepsAtAchievement: Int  // 到達時点の累積歩数
  var celebrated: Bool        // 演出再生済みフラグ
}
```

### 5.2 重複排除と整合性

- `StepDailyRecord` は `dayStart` で UPSERT（同日のレコードは値を最新で上書き）
- HealthKit 側の遅延更新を考慮し、直近 7 日分は毎回再同期する（過去日は値が訂正されうるため）
- `CheckpointAchievement` は `checkpointId` 一意制約（重複到達は無視）

### 5.3 設定値（@AppStorage / UserDefaults）

| キー | 型 | 既定値 | 用途 |
|---|---|---|---|
| `walk.dailyGoalSteps` | Int | 8000 | 1 日の歩数目標 |
| `walk.journeyStartedAt` | Date? | nil（初回起動時に設定） | 旅の開始日（累積歩数の起点） |
| `walk.celebrationConfettiEnabled` | Bool | true | 紙吹雪演出 |
| `walk.celebrationSoundEnabled` | Bool | true | 達成音 |
| `walk.celebrationHapticEnabled` | Bool | true | 触覚 |
| `walk.healthKitAuthorizationRequested` | Bool | false | 初回権限ダイアログ表示済みフラグ |

### 5.4 静的データ（コード内定数 / リソース）

`Domain/JourneyRoute.swift` に Swift コードで定義:

```swift
struct Checkpoint {
  let id: String           // "tokyo", "yokohama", ..., "hakata"
  let name: String         // 表示名
  let cumulativeKm: Double // 起点からの距離（km）
  let mapPosition: CGPoint // イラストマップ上の正規化座標 (0...1, 0...1)
  let blurb: String        // 名物紹介 1〜3 行
  let badgeAssetName: String // バッジ画像名（Assets.xcassets）
}
```

13 地点（暫定、距離は東海道+山陽道の概算）:

| ID | 名前 | 累積 km |
|---|---|---|
| tokyo | 東京 | 0 |
| yokohama | 横浜 | 30 |
| atami | 熱海 | 105 |
| shizuoka | 静岡 | 180 |
| hamamatsu | 浜松 | 260 |
| nagoya | 名古屋 | 365 |
| kyoto | 京都 | 515 |
| osaka | 大阪 | 555 |
| kobe | 神戸 | 590 |
| okayama | 岡山 | 730 |
| hiroshima | 広島 | 890 |
| shimonoseki | 下関 | 1075 |
| hakata | 博多 | 1150 |

紹介文（blurb）はコード内に直書きで、後から差し替え容易にする。

## 6. サービス層

### 6.1 HealthKitService 拡張

既存 protocol に歩数メソッドを追加:

```swift
protocol HealthKitService {
  // 既存（体組成）
  func requestAuthorization() async throws
  func fetchLatestBodyMetric() async throws -> BodyMetric?
  func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetric]

  // 追加（歩数）
  func requestStepAuthorization() async throws
  func fetchDailySteps(from: Date, to: Date) async throws -> [StepDailyRecord]
  func fetchTodaySteps() async throws -> Int
  func startObservingTodaySteps(_ handler: @escaping (Int) -> Void)
  func stopObservingTodaySteps()
}
```

実装ポイント:

- 歩数集計は `HKStatisticsCollectionQuery`（日次バケット）
- 当日のリアルタイム更新は `HKObserverQuery` + `HKAnchoredObjectQuery` の組み合わせ。Walk タブ表示中のみ登録、画面離脱時に解除
- 権限状態は `HKHealthStore.authorizationStatus(for:)` でチェック。未確定なら初回ダイアログ
- 体組成と歩数は別の `HKQuantityType` だが、同じ `HKHealthStore` インスタンスを共有
- テスト用にモック実装を提供（既存の `MockHealthKitService` に歩数メソッドを追加）

### 6.2 JourneyEngine（純粋ロジック・新規）

```swift
struct JourneyProgress {
  let totalSteps: Int
  let totalKm: Double
  let progressRatio: Double          // 0.0...1.0
  let lastPassedCheckpoint: Checkpoint?
  let nextCheckpoint: Checkpoint?
  let metersToNext: Double
  let isCompleted: Bool
}

enum JourneyEngine {
  static func computeProgress(
    totalSteps: Int,
    route: [Checkpoint],
    metersPerStep: Double = 1.0
  ) -> JourneyProgress

  /// 既到達のチェックポイント ID 集合を返す。
  static func passedCheckpointIds(
    totalSteps: Int,
    route: [Checkpoint],
    metersPerStep: Double = 1.0
  ) -> Set<String>
}
```

すべて static、副作用なし。XCTest でカバレッジ高めに。

### 6.3 JourneyService（新規・@Observable）

UI から触る薄いオーケストレーション層。`HealthKitService` + `JourneyEngine` + SwiftData をまとめる:

```swift
@Observable final class JourneyService {
  var todaySteps: Int = 0
  var progress: JourneyProgress = .empty
  var pendingCelebrations: [CheckpointAchievement] = []  // 未演出キュー

  init(healthKit: HealthKitService, container: ModelContainer)

  func bootstrap() async                   // アプリ起動時: 直近 7 日同期 + 進行計算
  func refreshOnAppear() async             // Walk タブ表示時に呼ぶ
  func startObserving()                    // Observer Query 登録
  func stopObserving()
  func markCelebrated(_ achievement: CheckpointAchievement)
  func resetJourney()                      // 設定からのリセット
  func setDailyGoal(_ steps: Int)
}
```

### 6.4 StreakCalculator（純粋ロジック・新規）

```swift
enum StreakCalculator {
  /// 今日から逆向きに「dailyGoal を達成した連続日数」を計算する。
  /// 当日が未達でも、前日まで達成していればストリークは前日までの連続として返す。
  static func currentStreak(
    records: [StepDailyRecord],
    dailyGoal: Int,
    today: Date = .now,
    calendar: Calendar = .current
  ) -> Int
}
```

副作用なし、テストしやすい純粋関数。`StepHistoryView` および `JourneyHUD` から呼び出す。

### 6.5 旅のお供キャラ・セリフ

```swift
enum CompanionDialog {
  static func line(
    progress: JourneyProgress,
    todaySteps: Int,
    dailyGoal: Int,
    timeOfDay: TimeOfDay        // .morning/.day/.evening/.night
  ) -> String
}
```

時間帯・達成度・進行率の組み合わせから 30〜50 件のフレーズ辞書を引く。同じ条件でも複数候補からランダム選択（直前と同じものは避ける）。

### 6.6 既存サービスは変更なし

`NotificationService` / `RestTimer` は本機能では触らない（歩数到達通知は MVP 外）。

## 7. データフロー

### 7.1 アプリ起動時

1. `WorkoutTrackerApp.init` で `JourneyService` をアプリ全体の `@Observable` として注入
2. `bootstrap()` 呼び出し:
   - 旅未開始なら `journeyStartedAt = today` を `@AppStorage` に保存
   - HealthKit 権限が未確定なら何もしない（Walk タブ初表示時に要求）
   - 権限あれば直近 7 日の `StepDailyRecord` を upsert
   - 累積歩数 = `journeyStartedAt` 以降の `StepDailyRecord.steps` の合計
   - `JourneyEngine.passedCheckpointIds(...)` から未記録の通過地点を `CheckpointAchievement` として挿入（`celebrated = false`）

### 7.2 Walk タブ表示時

1. 初表示時に HealthKit 権限が未確定なら `requestStepAuthorization()` を呼びダイアログ表示
2. `refreshOnAppear()` で当日歩数を取得 + `StepDailyRecord` を upsert + 進行計算
3. `startObserving()` で `HKObserverQuery` を登録、当日歩数の変化で `todaySteps` を更新
4. `pendingCelebrations` が空でなければ `CelebrationOverlay` を表示。1 件ずつ再生し、再生終了時に `markCelebrated()` で `celebrated = true` に
5. タブ離脱時に `stopObserving()`

### 7.3 セット記録（既存機能との関係）

筋トレ記録機能は本機能と独立。既存の挙動は変更なし。

### 7.4 旅の進行リセット

1. Walk 設定で「旅をリセット」を実行
2. 確認ダイアログ（破壊的アクションのため）
3. `CheckpointAchievement` 全削除 + `journeyStartedAt = today` に更新
4. 進行 0 km から再開。歩数履歴（`StepDailyRecord`）は保持

## 8. エラーハンドリング

| ケース | 扱い |
|---|---|
| HealthKit 権限拒否 | エラーにせず空表示。Walk タブに「歩数取得には HealthKit 許可が必要です」+ 設定アプリへの導線ボタン |
| HealthKit が利用不可（シミュレータ等） | ダミーモードに切替: ボタンで歩数 +1,000 を加算（DEBUG ビルドのみ表示）。動作確認用 |
| Observer Query 失敗 | サイレントに無視 + 次回 `refreshOnAppear` で復帰 |
| SwiftData 保存失敗 | アラート表示 + ログ。メモリ上の状態は保持 |
| HealthKit から負の値や異常値 | フィルタしてゼロ扱い |
| 旅完走後（博多到達後） | 「旅完走おめでとう」固定演出 + 次バージョン予告メッセージ。歩数記録は継続するが進行ピンは博多固定 |

## 9. テスト戦略

- **JourneyEngine**（XCTest・必須カバレッジ）:
  - 歩数 0 / 中間 / 完走超過の各境界
  - チェックポイント直前・到達瞬間・通過直後
  - 複数地点を一気に通過したケース（オフラインから戻った時など）
  - `metersPerStep` 変動時の整合性
- **StreakCalculator**（XCTest）: 連続達成日数 0 / 当日未達 + 前日まで連続 / 途中で 1 日抜け / 同日複数レコード（重複取り扱い）
- **CompanionDialog**（XCTest）: 全時間帯・達成度の組み合わせで非空文字列を返すこと、直前と異なるフレーズを返すロジック
- **HealthKitService 拡張**（XCTest + モック）: 権限拒否・空配列・正常系・部分日のバケット集計
- **JourneyService**（XCTest + in-memory `ModelContainer`）: bootstrap で StepDailyRecord 上書き / 未演出 CheckpointAchievement 挿入 / リセット動作
- **UI**: SwiftUI Preview で各状態を確認（権限なし / 旅未開始 / 進行中 / チェックポイント目前 / 完走後）。XCUITest は MVP 外
- 実行: 既存の `xcodebuild test` コマンドで一括

## 10. ディレクトリ構成（追加分）

```
WorkoutTracker/
  App/
    WorkoutTrackerApp.swift     // JourneyService の注入を追加
    RootView.swift              // タブを 5 個に拡張
  Domain/
    JourneyEngine.swift         // 純粋ロジック
    JourneyRoute.swift          // Checkpoint struct + 東京-博多の定数配列
    StreakCalculator.swift      // 連続達成日数の計算
    CompanionDialog.swift       // セリフ辞書
  Models/
    StepDailyRecord.swift
    CheckpointAchievement.swift
    Enums.swift                 // StepSource / TimeOfDay を追記
  Services/
    HealthKitService.swift      // 歩数メソッドを追記
    JourneyService.swift        // 新規
  Features/
    Walk/
      WalkView.swift
      WalkMapView.swift
      JourneyHUD.swift
      CompanionBubble.swift
      CelebrationOverlay.swift
      StepHistoryView.swift
      BadgesView.swift
      WalkSettingsView.swift
    Home/
      HomeView.swift            // 「今日の歩数」ミニカードを追加
  Resources/
    Assets.xcassets/
      JapanMap.imageset/        // 列島イラスト（PDF ベクター 1 枚）
      Companion/                // キャラ立ち絵 + 表情差分（基本/喜び/応援）
      Badges/                   // チェックポイントごとのバッジアイコン
      Confetti/                 // 紙吹雪パーティクル素材（必要なら）
WorkoutTrackerTests/
  DomainTests/
    JourneyEngineTests.swift
    StreakCalculatorTests.swift
    CompanionDialogTests.swift
  ServicesTests/
    HealthKitServiceStepsTests.swift
    JourneyServiceTests.swift
  ModelsTests/
    StepDailyRecordTests.swift
    CheckpointAchievementTests.swift
```

既存の `Models/Enums.swift` に `StepSource` と `TimeOfDay` を追加する点だけ既存ファイル変更あり、それ以外は新規追加。

## 11. 実装マイルストーン（概要）

実装計画書（次ステップ）で詳細化する粒度:

1. データモデル追加（`StepDailyRecord` / `CheckpointAchievement` / 列挙）+ `ModelContainerFactory` 更新 + Models テスト
2. `JourneyRoute` 静的データ + `JourneyEngine` + テスト
3. `HealthKitService` 歩数メソッド拡張 + モック更新 + テスト
4. `JourneyService` + bootstrap 動線 + テスト
5. `RootView` を 5 タブに変更 + Walk タブのスケルトン
6. `WalkMapView` + イラストマップアセット + 進行ピン
7. `JourneyHUD` + 目標ゲージ + リアルタイム歩数表示（Observer Query 連携）
8. `CelebrationOverlay`（紙吹雪 + 触覚 + サウンド）+ チェックポイント到達演出
9. `CompanionDialog` + `CompanionBubble`（キャラ表示 + セリフ）
10. 時刻に応じた背景の昼夜変化
11. `StepHistoryView`（Swift Charts）+ ストリーク計算
12. `BadgesView` + `WalkSettingsView`（目標・演出 ON/OFF・リセット）
13. `HomeView` 拡張（「今日の歩数」ミニカード）
14. 完走時の演出 + DEBUG モードのダミー歩数加算ボタン
15. 全体動作確認（権限フロー・初回起動・タブ間遷移・SwiftUI Preview のスナップ）

## 12. 用語

- **旅 (Journey)**: 東京 → 博多 1 ルートの累積歩数による進行ゲーム
- **チェックポイント**: ルート上の到達地点（13 箇所）
- **進行 km**: 累積歩数 × 1 m を km 換算した値
- **ストリーク**: 1 日歩数目標を達成した連続日数
- **演出 (Celebration)**: チェックポイント到達時の紙吹雪・触覚・サウンド・紹介カード
- **お供キャラ (Companion)**: 旅タブで状況に応じたセリフを話すキャラクター
