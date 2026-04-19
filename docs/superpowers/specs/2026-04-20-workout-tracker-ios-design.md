# 筋トレ記録 iOS アプリ 設計書

- 作成日: 2026-04-20
- ステータス: 実装計画待ち
- 対象ブランチ: worktree `smooth-floating-metcalfe`

## 1. 目的とスコープ

個人用の iOS ネイティブアプリ。筋トレのメニュー（種目・テンプレート）を登録し、セッション中の実施内容（重量・回数・セット）を記録する。App Store 公開・他ユーザーとの共有・認証は対象外。

### スコープ内（MVP）

- 種目およびワークアウトテンプレートの登録・編集・削除
- ワークアウトセッションの記録（種目ごとのセット・重量・回数）
- セット間休憩タイマー（ローカル通知でバックグラウンド通知）
- 履歴表示と種目別のグラフ（Swift Charts）
- 体重・体脂肪率の記録（HealthKit 自動取得 + 手入力フォールバック）

### スコープ外（本バージョンでは実装しない）

- App Store 配布・TestFlight・認証
- クラウド同期（iCloud / CloudKit を含む）
- Apple Watch アプリ
- 前回実績のインライン表示
- ソーシャル機能・データ共有
- 多言語対応（日本語のみ）

## 2. 前提と制約

- 対応 OS: iOS 18 以降、iPhone のみ
- 言語: Swift 5.10 以降、SwiftUI
- 永続化: SwiftData（ローカルのみ）
- UI 言語: 日本語
- ライト/ダーク両対応
- 配布: ローカル開発ビルド（Xcode から実機インストール）

## 3. アーキテクチャ

SwiftUI + SwiftData + MV（Model–View）パターン。単純な一覧は `@Query` を View で直接使用し、複数モデルにまたがるロジックは `@Observable` な ViewModel に集約する。

```
┌──────────────────────────────────────────────┐
│              SwiftUI Views                   │
│   (TabView: Home / Recording / Menu /        │
│    History)                                  │
└───────────────┬──────────────────────────────┘
                │ @Query / @Observable ViewModel
                ▼
┌──────────────────────────────────────────────┐
│           Services 層                        │
│  - HealthKitService (protocol)               │
│  - NotificationService                       │
│  - RestTimer                                 │
└───────────────┬──────────────────────────────┘
                ▼
┌──────────────────────────────────────────────┐
│      SwiftData ModelContainer                │
│  Exercise / WorkoutTemplate /                │
│  TemplateExercise / WorkoutSession /         │
│  SetRecord / BodyMetric                      │
└──────────────────────────────────────────────┘
```

## 4. 画面構成

`TabView` で以下 4 タブを切り替える。

### 4.1 ホーム (Home)

- 今日のワークアウト開始ボタン（テンプレート選択 or 空セッション）
- 直近 3 セッションのサマリ（日付・種目数・総ボリューム）
- 直近 30 日の体重トレンド（小さなスパークライン）

### 4.2 記録 (Recording)

- アクティブワークアウト画面
- 種目単位でセットを追加・編集・削除
- 各セットは「重量 kg / 回数 / RPE（任意）」を入力
- 休憩タイマー（デフォルト 90 秒、種目ごとに設定可能）
- ワークアウト終了ボタンで `WorkoutSession.endedAt` を確定
- 進行中セッションが無い場合はホームからの開始を促す

### 4.3 メニュー (Menu)

2 つのサブ画面をセグメント切替:

- **種目**: プリセット + ユーザー追加種目の一覧。追加・編集・非表示化
- **テンプレート**: 「胸の日」「脚の日」などの組み合わせを作成・編集

### 4.4 履歴 (History)

- セッション一覧（日付降順）
- セッション詳細（セット明細）
- 種目別グラフ: 重量の推移 / 1RM 推定値 / 総ボリュームを Swift Charts で描画
- 体組成タブ: 体重・体脂肪率の推移

## 5. データモデル（SwiftData）

すべて `@Model` マクロで定義。主なエンティティと関係。

### 5.1 エンティティ

```swift
@Model class Exercise {
  var id: UUID
  var name: String
  var category: ExerciseCategory   // 胸/脚/背/肩/腕/体幹/その他
  var defaultWeightKg: Double?
  var notes: String?
  var isHidden: Bool               // プリセット非表示化フラグ
  // 関連
  var setRecords: [SetRecord]
  var templateExercises: [TemplateExercise]
}

@Model class WorkoutTemplate {
  var id: UUID
  var name: String
  var order: Int
  @Relationship(deleteRule: .cascade) var exercises: [TemplateExercise]
}

@Model class TemplateExercise {
  var id: UUID
  var order: Int
  var exercise: Exercise
  var targetSets: Int
  var targetReps: Int
  var targetWeightKg: Double?
}

@Model class WorkoutSession {
  var id: UUID
  var startedAt: Date
  var endedAt: Date?
  var templateRef: WorkoutTemplate?
  @Relationship(deleteRule: .cascade) var sets: [SetRecord]
  var notes: String?
}

@Model class SetRecord {
  var id: UUID
  var exercise: Exercise
  var weightKg: Double
  var reps: Int
  var rpe: Double?                  // 任意、0.5 刻み 1.0〜10.0
  var performedAt: Date
  var restSeconds: Int?             // セット後の休憩実測
}

@Model class BodyMetric {
  var id: UUID
  var recordedAt: Date
  var weightKg: Double?
  var bodyFatPercent: Double?
  var source: BodyMetricSource      // .healthKit / .manual
}
```

### 5.2 削除ルール

- `WorkoutTemplate` 削除 → `TemplateExercise` をカスケード削除
- `WorkoutSession` 削除 → `SetRecord` をカスケード削除
- `Exercise` の参照が残っている場合は削除不可（代わりに `isHidden = true`）

### 5.3 シードデータ

初回起動時に以下のプリセット `Exercise` を作成:

- ベンチプレス / スクワット / デッドリフト / オーバーヘッドプレス / 懸垂 / ラットプルダウン / ベントオーバーロウ / ダンベルカール / レッグプレス / レッグカール

`UserDefaults` に `didSeedInitialData` フラグを持ち、重複シードを避ける。

## 6. サービス層

### 6.1 HealthKitService

```swift
protocol HealthKitService {
  func requestAuthorization() async throws
  func fetchLatestBodyMetric() async throws -> BodyMetric?
  func fetchBodyMetrics(from: Date, to: Date) async throws -> [BodyMetric]
}
```

- 起動時に権限リクエスト
- ホーム表示時と履歴体組成タブ表示時に同期
- 権限拒否時はエラーを投げず、空配列を返す。UI は手入力にフォールバック
- 実装: `HKHealthStore` を内包、テスト用にモックを差し込めるようにプロトコル化

### 6.2 NotificationService

- `UNUserNotificationCenter` のラッパー
- 初回タイマー開始時に権限リクエスト
- 休憩タイマー終了時のローカル通知をスケジュール/キャンセル

### 6.3 RestTimer

- `@Observable` クラス
- 開始時に `endAt = now + duration` を保存
- 残り時間はタイマーで UI 更新（`Timer.TimerPublisher`）
- バックグラウンド→復帰時は `endAt - now` で再計算
- 完了時に `NotificationService` で通知発火

## 7. データフロー

### 7.1 ワークアウト開始

1. ホームで「空セッション開始」または「テンプレート選択」
2. `WorkoutSession(startedAt: now, templateRef: ...)` を作成
3. テンプレートがあれば `TemplateExercise` を元に空の `SetRecord` ひな型を UI 上に展開（永続化は入力後）
4. 記録タブへ遷移

### 7.2 セット記録

1. 種目を選び「セット追加」
2. 重量・回数を入力 → `SetRecord` を挿入
3. 休憩タイマーが自動起動（種目設定の秒数）
4. タイマー完了で通知 + 次のセット入力へ

### 7.3 ワークアウト終了

1. 終了ボタンで `session.endedAt = now`
2. 履歴タブに反映

### 7.4 体組成同期

1. 起動時: `HealthKitService.fetchLatestBodyMetric()` を呼び、値があれば `BodyMetric(source: .healthKit)` として保存（同日重複は上書き）
2. 手入力時: `BodyMetric(source: .manual)` を保存

## 8. エラーハンドリング

| ケース | 扱い |
|---|---|
| SwiftData 保存失敗 | アラート表示 + ログ出力。メモリ上のモデルは保持し再試行を促す |
| HealthKit 権限拒否 | エラーにしない。空結果を返し、UI に「手入力してください」を表示 |
| 通知権限拒否 | タイマーは動作する。完了時はアプリ内で音＋触覚のみ（バックグラウンドでは通知不可） |
| バックグラウンド復帰 | タイマーは `endAt` から経過再計算。既に完了していれば即「休憩終了」状態に |
| `Exercise` 削除不可 | 参照がある場合は `isHidden = true` に誘導する UI |

## 9. テスト戦略

- **ドメインロジック**（XCTest）: 1RM 推定、総ボリューム、休憩タイマーの経過計算
- **SwiftData リポジトリ**（XCTest + in-memory `ModelContainer`）: CRUD、削除ルール、シード処理
- **HealthKitService**（XCTest + モック）: 権限拒否・空データ・正常系
- **UI**: SwiftUI Preview による目視確認。UI テストは MVP では省略
- テスト実行: `xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 16'`

## 10. ディレクトリ構成

```
WorkoutTracker.xcodeproj
WorkoutTracker/
  App/
    WorkoutTrackerApp.swift
    RootView.swift
  Features/
    Home/
    Recording/
    Menu/
      Exercises/
      Templates/
    History/
  Models/
    Exercise.swift
    WorkoutTemplate.swift
    TemplateExercise.swift
    WorkoutSession.swift
    SetRecord.swift
    BodyMetric.swift
    Enums.swift
  Services/
    HealthKitService.swift
    NotificationService.swift
    RestTimer.swift
  Resources/
    SeedData.swift
    Assets.xcassets
    Localizable.xcstrings
WorkoutTrackerTests/
  DomainTests/
  RepositoryTests/
  ServicesTests/
```

## 11. 実装マイルストーン（概要）

実装計画書（次ステップ）で詳細化する粒度。

1. プロジェクトスキャフォールド（Xcode プロジェクト、ディレクトリ、SwiftData セットアップ、ルート `TabView`）
2. データモデル + シード + リポジトリ + テスト
3. メニュー画面（種目・テンプレート CRUD）
4. 記録画面（セッション開始・セット入力）
5. 休憩タイマー + ローカル通知
6. 履歴画面 + Swift Charts
7. HealthKit 連携 + 体重・体脂肪率 UI
8. ホーム画面のサマリ・スパークライン
9. ダークモード調整・アクセシビリティ最終確認

## 12. 用語

- **セッション**: 1 回のワークアウト（開始〜終了）
- **セット**: 1 種目の 1 連続の反復（例: ベンチプレス 80kg × 10）
- **テンプレート**: 事前登録したワークアウト計画（種目と目標セット／回数）
- **RPE**: Rate of Perceived Exertion（主観的運動強度、1.0〜10.0）
- **総ボリューム**: Σ(重量 × 回数)
