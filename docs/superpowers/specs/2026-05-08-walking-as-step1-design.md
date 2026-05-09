# 設計書 / ウォーキングを Step 1 として再ポジション + ほのぼの強化

- 作成日: 2026-05-08
- 対象: workout-tracker (iOS / SwiftUI + SwiftData)
- ベースコミット: `4ea123a` (万歩計 + 東京→博多バーチャル旅行機能を追加)

## 1. 目的・スコープ・成功基準

### 1.1 目的

肥満度が高い人が無理なく続けられる「ワークアウトの入り口（Step 1）」として、歩くことをアプリの主役に据え直す。「旅」（東京→博多バーチャル旅行）はあくまでウォーキングを面白くするための装置として位置づけ直し、水彩タッチのほのぼのイラストでアプリ全体の印象をやわらかくする。

### 1.2 スコープに入れるもの

- ホーム画面の再構成: 上半分を歩数主役（時間帯水彩背景 + 歩数 + コンパニオン + 旅ミニカード）、下半分を筋トレサマリ
- 「旅」タブを「歩く」タブにリネーム（UI 表記のみ。内部クラス名 `Journey*` は据え置き）
- アイコンを `map` から `figure.walk` へ
- 水彩風イラスト 17 枚（時間帯 4 + チェックポイント 13）の生成パイプライン（OpenAI gpt-image-1 + Python スクリプト）
- イラストをホームと歩くタブで使うための View 改修（`TimeOfDayBackground` → `TimeOfDayScenery`）
- `Assets.xcassets/Badges/` を `Scenery/` にリネーム、`Checkpoint.badgeAssetName` → `sceneryAssetName`
- `CompanionLines.json` を新設して文言テンプレートを大幅拡張（200件以上目標）、`(進捗 × 時間帯 × 連続日数 × 距離区分)` でフィルタ
- `StepDailyRecord` / `CheckpointAchievement` / `WorkoutSession` / `BodyMetric` 用のテスト fixture（代表値 1234 歩を含む）と `InMemoryContainer.seeded(_:)` 拡張

### 1.3 スコープに入れないもの（YAGNI）

- コンパニオンキャラ画像の作成（吹き出しの文言は維持、絵としてのキャラはなし）
- HealthKit 連携の仕様変更
- 筋トレ機能（記録・メニュー・履歴）の仕様変更
- 設定 / 目標歩数のチューニング以外のオンボーディング
- イラストの動的生成（ビルド時 / 実行時生成は不要、PNG をリポジトリ同梱）

### 1.4 Follow-up spec 候補（本 spec では扱わない）

- **旅のゴール選択**: プリセット切替（東京→大阪 / 東京→札幌等）+ フリーモード（距離だけ走らせて到達地点を逆算表示）
- **結果表現力強化**: 月次ハイライト / 「富士山 1 個ぶん登った」比喩表示 / 達成タイムライン演出 / 振り返って嬉しい歩くタブ履歴

これらは本 spec 完了後、別 brainstorm で扱う。

### 1.5 成功基準

- 起動直後（ホームタブ）で「今日の歩数 + 進捗 + 風景イラスト」が画面上半分を占めて即見える
- ホームから 1 タップで歩くタブの詳細（マップ・バッジ・履歴）に飛べる
- iPhone 17 シミュレータで XCTest 全パス、新規追加 fixture を使った歩数系テストが green
- イラスト生成スクリプトが `OPENAI_API_KEY` 設定下でワンコマンドで PNG 17 枚を `Assets.xcassets/Scenery/` 配下に配置できる
- 既存のセッション記録・グラフ機能はリグレッションなし
- イラスト未投入の状態でもアプリが gradient フォールバックで正常動作

## 2. 情報構造（タブ + 画面遷移）

### 2.1 タブ構成（順序は据え置き、ラベル/アイコン更新のみ）

| 位置 | 旧 | 新 | 役割 |
|------|------|------|------|
| 1 | ホーム 🏠 | ホーム 🏠 | **歩く主役** + 筋トレサマリ |
| 2 | 記録 💪 | 記録 💪 | 既存のまま |
| 3 | メニュー 📋 | メニュー 📋 | 既存のまま |
| 4 | 履歴 📊 | 履歴 📊 | 既存のまま |
| 5 | 旅 🗺️ (`map`) | **歩く 🚶 (`figure.walk`)** | 地図 / バッジ / 歩数履歴の詳細 |

**タブ並び替えをしない理由:** Step 1 化はホームの構成で達成済み。並び替えは既存ユーザー（自分）の筋肉記憶を破壊する。歩くは詳細ビューなので奥（5 番目）でよい。

### 2.2 画面遷移の主動線

```
起動 → [ホーム]
            ├ 歩数カードタップ ─→ [歩く] タブへジャンプ
            ├ 旅ミニカードタップ ─→ [歩く] タブへジャンプ
            ├ 直近セッション ─→ SessionDetailView (NavigationStack)
            └ 体組成 ─→ BodyCompositionView (任意、まずは値表示のみ)
[歩く] タブ
   ├ 上部 toolbar: 歩数履歴 / バッジ / 設定 (既存維持)
   ├ 中央: 大きなマップ + 進捗 HUD + 時間帯水彩背景
   └ 達成時: CelebrationOverlay (既存維持)
```

### 2.3 タブ切替の実装方針

- `App/AppTab.swift` を新規追加: `enum AppTab: Hashable { case home, recording, menu, history, walk }`
- `RootView` を `TabView(selection: $selectedTab)` 化
- ホームから歩くタブへ飛ぶには `@Binding` または小さな ObservableObject (`TabSelector`) を Environment に流す
- ホーム内の `JourneyMiniCard` 等は `tabSelection = .walk` を行うクロージャだけを props で受け取り、`HomeView` 側で配線

### 2.4 情報重複の回避

- ホームの `JourneyMiniCard` は「進捗 + 次のチェックポイント名 + km」のみ。地図そのものは出さない（旅ライン縮小サムネのみ）
- 歩くタブの `WalkMapView` は拡大スクロールあり、チェックポイント全表示、達成済みアイコン
- ホームのコンパニオン吹き出しは 1〜2 行の短文。歩くタブが「主」（達成オーバーレイで使う長文も含む）

## 3. ホームの新構成

### 3.1 全体構造

`NavigationStack { ScrollView { LazyVStack {…} } }` に置換。理由:

- 上半分に水彩背景を全幅で敷きたい
- 筋トレ側のセクションはカード風 UI で十分
- 既存 List スタイル維持より置換のほうが見た目が安定する

### 3.2 上半分（Walk Hero、おおよそ 360pt）

```swift
ZStack(alignment: .top) {
    TimeOfDayScenery(timeOfDay: .from(Date()))
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    VStack(spacing: 12) {
        CompanionBubble(line: line, mood: mood)        // 既存維持
        StepHeroCard(steps: 5432, goal: 8000)          // 新規
        JourneyMiniCard(progress: progress)            // 新規
            .onTapGesture { tabSelection = .walk }
    }
}
```

- `TimeOfDayScenery`: `Image("Scenery/morning|day|evening|night")` を表示。画像が無い場合は既存 gradient にフォールバック
- `StepHeroCard`: 大きい円 or 横バー + `\(steps) / \(goal) 歩` + 達成パーセント
- `JourneyMiniCard`: 静止サムネ（東京→博多ライン縮小版）+ 「次: 名古屋まで 14.2 km」+ chevron

### 3.3 下半分（筋トレサマリ、既存からスタイル変更）

`LazyVStack` でカード 3 つを順に積む（既存の List Section をカード風に置換）:

1. 今週のサマリ（セッション数 / 総ボリューム / セット数 — 既存の `SummaryTile` を `HStack` で）
2. 直近のセッション（NavigationLink → `SessionDetailView`）
3. 最新の体組成（NavigationLink → `BodyCompositionView` 任意、まずは値表示のみ）

カード共通スタイル: `.background(.regularMaterial)` + `cornerRadius(16)` + `padding(.horizontal)`

### 3.4 新規・改修ファイル

| ファイル | 種別 | 内容 |
|---------|------|------|
| `Features/Home/HomeView.swift` | 改修 | List → ScrollView + LazyVStack に置換 |
| `Features/Home/StepHeroCard.swift` | 新規 | 歩数 + 進捗の大カード |
| `Features/Home/JourneyMiniCard.swift` | 新規 | 旅進捗ミニサムネ、タップでタブ切替 |
| `Features/Walk/TimeOfDayBackground.swift` | リネーム | → `TimeOfDayScenery`、Image + gradient フォールバック |
| `App/AppTab.swift` | 新規 | enum、`RootView` の selection 用 |
| `App/RootView.swift` | 改修 | `TabView(selection:)` + Environment で TabSelector 提供 |

### 3.5 境界・テスト容易性

- `StepHeroCard` / `JourneyMiniCard` は値型 props のみ受け取る（`JourneyService` に依存しない）。Preview で固定値を流せる
- `HomeView` だけが `JourneyService` と `@Query` を読む（依存集約）
- `TimeOfDayScenery` も `TimeOfDay` enum 受け取りのみ

## 4. 「歩く」タブの新構成

### 4.1 画面構成（既存ベースに整理）

```swift
NavigationStack {
    ZStack(alignment: .top) {
        TimeOfDayScenery(timeOfDay: .from(Date()))    // ホームと共通の水彩背景
            .frame(height: 220)
        ScrollView {
            VStack(spacing: 16) {
                CompanionBubble(line: line, mood: mood)
                WalkMapView(route: .tokyoToHakata, progress: progress)
                JourneyHUD(todaySteps: …, dailyGoal: …, progress: progress)
            }
        }
    }
    .navigationTitle("歩く")
    .toolbar { /* 歩数履歴 / バッジ / 設定 — 既存3つ維持 */ }
    .sheet(isPresented: $showingHistory)  { StepHistoryView() }
    .sheet(isPresented: $showingBadges)   { BadgesView() }
    .sheet(isPresented: $showingSettings) { WalkSettingsView() }
}
```

### 4.2 既存からの差分

| 項目 | 旧 | 新 | 備考 |
|------|-----|-----|------|
| navigationTitle | "旅" | "歩く" | UI 文言のみ |
| TabItem | `Label("旅", systemImage: "map")` | `Label("歩く", systemImage: "figure.walk")` | |
| 背景 | `TimeOfDayBackground` (gradient) | `TimeOfDayScenery` (画像 + gradient フォールバック) | |
| 中央コンテンツ | `WalkMapView` + `JourneyHUD` | （同左） | 維持 |
| 各種シート | 歩数履歴 / バッジ / 設定 | （同左） | 維持 |

### 4.3 内部命名の据え置き

`JourneyService`、`JourneyEngine`、`JourneyRoute`、`JourneyHUD`、`JourneyProgress` 等の Swift クラス・型名は変更しない。理由:

- リネーム差分が広範囲に及ぶ
- 「旅」というメタファーはコード内に残してよい（ユーザー向け表記とは独立）
- `Walk*` への一括置換はリスクが見合わない

## 5. 水彩イラスト生成パイプライン

### 5.1 生成対象（合計 17 枚）

| カテゴリ | 枚数 | 内容 |
|---------|------|------|
| 時間帯背景 | 4 | morning / day / evening / night（人物なし、空・地平線中心） |
| チェックポイント挿絵 | 13 | tokyo / yokohama / atami / shizuoka / hamamatsu / nagoya / kyoto / osaka / kobe / okayama / hiroshima / shimonoseki / hakata |

ファイル名は `JourneyRoute.tokyoToHakata` の `id` に揃える。

### 5.2 モデル・ツール選定

- API: **OpenAI gpt-image-1**（透明背景出力対応、プロンプト追従、商用利用可）
- 言語: **Python 3.12 + uv**（`.tool-versions` に追加）
- パッケージ: `openai`、必要に応じて `Pillow`（後処理）

### 5.3 ディレクトリ構成

```
scripts/
  illustrations/
    generate.py              # 生成本体
    prompts.toml             # プロンプト定義（バージョン管理対象）
    style_guide.md           # 共通スタイル仕様（プロンプト末尾に毎回付加）
    pyproject.toml           # uv 管理
    .cache/                  # 生成済みハッシュ → 既存ファイルなら skip（gitignore）
```

### 5.4 prompts.toml フォーマット

```toml
[style]
suffix = "soft watercolor illustration, gentle pastel palette, hand-painted texture, warm and gentle atmosphere, no text, no people, slight paper grain"
size    = "1024x1024"
quality = "high"

[scenery.morning]
prompt = "A peaceful early morning sky over distant blue mountains, faint pink sunrise glow"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/morning.imageset/morning.png"

[scenery.tokyo]
prompt = "Tokyo cityscape with Nihonbashi bridge silhouette and Tokyo Tower in distance, calm street view"
output = "WorkoutTracker/Resources/Assets.xcassets/Scenery/tokyo.imageset/tokyo.png"
# ... 残り 15 件
```

### 5.5 実行モード

| コマンド | 動作 |
|---------|------|
| `uv run python generate.py` | 全件生成（キャッシュヒットは skip） |
| `uv run python generate.py --filter tokyo,kyoto` | 部分生成 |
| `uv run python generate.py --force` | キャッシュ無視で再生成 |
| `uv run python generate.py --dry-run` | プロンプトを print のみ、API 呼ばず |

### 5.6 出力後の処理

1. PNG を `Assets.xcassets/Scenery/<id>.imageset/<id>.png` に保存
2. `Contents.json` を自動生成（`scale: 1x` のみ。Retina 対応は OS スケーリング任せ）
3. `git diff --stat WorkoutTracker/Resources/Assets.xcassets` を最後に出力して確認を促す

### 5.7 Asset path 戦略

- 既存の `Checkpoint.badgeAssetName: "Badges/<id>"` は実体が風景挿絵になる
- リネーム: `badgeAssetName` → `sceneryAssetName`、`Assets.xcassets/Badges/` → `Scenery/`
- 影響範囲: `JourneyRoute.swift`, `BadgesView.swift`, `CelebrationOverlay.swift` の参照を `Scenery/` に追従

### 5.8 シークレット管理

- `OPENAI_API_KEY` は環境変数のみ（コミットしない）
- `.envrc.example` をリポジトリに追加（参考。direnv 必須ではない）
- README に手動設定手順を追記

### 5.9 コスト見積（参考）

- gpt-image-1, 1024x1024, quality=high で約 $0.19/枚
- 17 枚 × 1〜2 回試行 = 推定 **$3〜7 程度**

### 5.10 位置づけ

- このスクリプトはアプリのビルドには不要。一度生成して PNG をコミットすれば、以降の開発・テスト・配布では使わない
- `scripts/illustrations/` は CI からは呼ばない（人間が手動実行）

## 6. テスト fixture 設計

### 6.1 狙い

- ユーザー指定の代表値（**1234 歩**）等で `StepDailyRecord` / `CheckpointAchievement` / `WorkoutSession` / `BodyMetric` をテスト・プレビューから即生成できるようにする
- 日付の相対計算（昨日 / 1 週間前 / 先月）をヘルパーで提供
- シナリオプリセット（連続達成中 / 旅の途中 / 初日）を共通化

### 6.2 配置

```
WorkoutTracker/
  TestSupport/
    Fixtures.swift           // #if DEBUG, 全 fixture をここに集約
    DateHelpers.swift        // #if DEBUG, 相対日付ユーティリティ
WorkoutTrackerTests/
  TestHelpers/
    InMemoryContainer.swift  // 既存 + seeded(_:) を追加
```

`#if DEBUG` で main ターゲットに置く理由:

- テストから `@testable import WorkoutTracker` で使える
- SwiftUI Preview でも同じ fixture を直接使える（重複なし）
- リリースビルドからは除外される

### 6.3 Fixtures の構造

```swift
#if DEBUG
@MainActor
enum Fixtures {
    enum Steps {
        static let representative = 1234
        static let goalAchieved   = 8500
        static let lazy           = 320
        static let highEffort     = 12_345
    }

    static func stepRecord(_ count: Int, daysAgo: Int = 0) -> StepDailyRecord
    static func achievement(_ checkpointId: String, daysAgo: Int = 0) -> CheckpointAchievement
    static func bodyMetric(weightKg: Double = 72.4, daysAgo: Int = 0) -> BodyMetric
    static func session(startedDaysAgo: Int = 0,
                        sets: [(weightKg: Double, reps: Int)] = []) -> WorkoutSession

    static let varietyWeek: [Int] = [1234, 5432, 8500, 320, 9100, 6700, 4200]
    static let streak4Days: [Int] = [8500, 8600, 8400, 8700]
    static func midJourneyAchievements() -> [CheckpointAchievement]   // tokyo/yokohama/atami/shizuoka 達成済み
    static func firstDayUser() -> [StepDailyRecord]                    // 初日ユーザー、1 日分のみ
}
#endif
```

### 6.4 InMemoryContainer の seeded オーバーロード

```swift
extension InMemoryContainer {
    @MainActor
    static func seeded(_ build: (ModelContext) -> Void) throws -> ModelContainer {
        let container = try make()
        build(container.mainContext)
        try container.mainContext.save()
        return container
    }
}
```

使用例:

```swift
let container = try InMemoryContainer.seeded { ctx in
    Fixtures.varietyWeek.enumerated().forEach { i, count in
        ctx.insert(Fixtures.stepRecord(count, daysAgo: i))
    }
}
```

### 6.5 既存テストへの影響

| 既存テストファイル | 改修方針 |
|------------------|----------|
| `JourneyEngineTests.swift` | 一部を Fixtures に置換、新シナリオ（midJourney）を追加 |
| `StepDailyRecordTests.swift` | 1234 歩 fixture でモデル境界値を確認 |
| `CompanionDialogTests.swift` | varietyWeek 等で文言 pool フィルタの妥当性を確認 |
| `CheckpointAchievementTests.swift` | midJourneyAchievements で順序保持を確認 |
| 他 | 既存テストは無理に Fixtures 置換しない（YAGNI） |

### 6.6 新規テスト

| 対象 | テストする内容 |
|------|---------------|
| `Domain/CompanionLineFilter`（新規） | (進捗 × 時間帯 × 連続日数 × 距離区分) の組み合わせで適切な pool が選ばれる |
| `Domain/CompanionDialog`（改修） | JSON ロードが失敗しても fallback 文言が返る |
| `Features/Home/StepHeroCard` | 進捗値の境界（0%, 50%, 100%, 120%）でレンダリング崩れない |
| `Features/Home/JourneyMiniCard` | 完走時 / 序盤 / 中盤の表示分岐 |

### 6.7 Preview 連携の例

```swift
#if DEBUG
#Preview("中盤") {
    HomeView()
        .modelContainer(try! InMemoryContainer.seeded { ctx in
            Fixtures.varietyWeek.enumerated().forEach { i, n in
                ctx.insert(Fixtures.stepRecord(n, daysAgo: i))
            }
            Fixtures.midJourneyAchievements().forEach { ctx.insert($0) }
        })
        .environment(JourneyService.preview)   // 下記 6.7.1 の helper
}
#endif
```

#### 6.7.1 JourneyService.preview helper

`JourneyService.preview` は `#if DEBUG` で定義する static helper。fixture を seed したインスタンスを返し、SwiftUI Preview 専用に使う:

```swift
#if DEBUG
extension JourneyService {
    @MainActor
    static var preview: JourneyService {
        JourneyService(
            healthKit: StubHealthKitService(),  // 既存 or 新規スタブ
            container: ModelContainerFactory.makeShared()
        )
    }
}
#endif
```

`StubHealthKitService` は HealthKit を呼ばずに `Fixtures.Steps.representative` 等を返す DEBUG 専用スタブ。実装は Phase 1 内で完了させる。

### 6.8 意図的に避けるもの

- データジェネレータライブラリ（Faker 系）は使わない
- ファクトリーマクロ・property wrapper も使わない
- ランダム値は混ぜない（テスト不安定化を避ける）
- fixture をネスト深くしない（フラットな enum + static func で十分）

## 7. CompanionLines 拡張

### 7.1 狙い

既存 `CompanionDialog` は 1 状態あたり 3〜4 文しかなく、同条件で繰り返し見ると冷める。設計時に LLM で量産→人間がほのぼの度フィルタ→ハードコード（JSON 化）して、状態軸を増やすことでバリエーションを 200 件以上に拡張する。

### 7.2 状態軸

```
進捗状態:    達成 / 未達 / 完走
時間帯:      朝 / 昼 / 夕 / 夜
連続日数:    初日 / 3日 / 1週 / 1ヶ月以上
距離区分:    序盤 (0-30%) / 中盤 (30-70%) / 終盤 (70-100%)
```

### 7.3 JSON フォーマット案

各キー値は安定性のため英字 enum case と一致させる（`null` はワイルドカード = 任意）:

```json
{
  "lines": [
    {
      "text": "おはよう。今日もぼちぼちいこう。",
      "progress": ["unmet"],
      "timeOfDay": ["morning"],
      "streak": null,
      "distance": null
    }
  ]
}
```

| キー | 取りうる値 |
|------|-----------|
| `progress` | `unmet` / `achieved` / `completed` |
| `timeOfDay` | `morning` / `day` / `evening` / `night` |
| `streak` | `firstDay` / `threeDay` / `oneWeek` / `oneMonthPlus` |
| `distance` | `early` / `mid` / `late` |

### 7.4 ロード戦略

- `Resources/CompanionLines.json` から起動時にロード
- ロード失敗時は既存の hardcoded fallback pool（`CompanionDialog.swift` 内）を使用
- `CompanionLineFilter` 構造体で条件絞り込み、ランダム選択

### 7.5 改修ファイル

| ファイル | 種別 | 内容 |
|---------|------|------|
| `Resources/CompanionLines.json` | 新規 | 200 件以上の文言テンプレ |
| `Domain/CompanionDialog.swift` | 改修 | JSON ロード + filter ロジック |
| `Domain/CompanionLineFilter.swift` | 新規 | フィルタ条件 struct |

## 8. 移行戦略・段取り

各フェーズが完了した時点でビルド + 既存テスト green を保つ。フェーズ単位でコミット粒度を意識。

| Phase | 内容 | 完了条件 |
|-------|------|---------|
| **1. 基盤（テスト/データ）** | `Fixtures.swift` / `DateHelpers.swift`（main の `#if DEBUG`）、`InMemoryContainer.seeded` 追加 | 既存テスト全 green、新 fixture を 1〜2 既存テストで実利用 |
| **2. Asset path リネーム** | `Assets.xcassets/Badges/` → `Scenery/`、`Checkpoint.badgeAssetName` → `sceneryAssetName`、参照箇所更新 | Build green、UI 動作不変（画像未投入でもクラッシュしない） |
| **3. RootView タブ機構** | `AppTab` enum、`RootView` を `TabView(selection:)` 化、tabItem ラベル/アイコン更新（旅 → 歩く 🚶） | タブ切替できる、見た目は文字のみ変更 |
| **4. 画像生成パイプライン** | `scripts/illustrations/` Python セットアップ（uv）、`prompts.toml` 全 17 件、`generate.py`（dry-run まで含む）、README 手順追記 | `--dry-run` で全件のプロンプトが正しく出る |
| **5. イラスト生成・投入** | `OPENAI_API_KEY` 設定して `generate.py` 実行、17 枚 PNG を `Scenery/` 配下に配置、`Contents.json` 自動生成 | 17 枚すべて目視で水彩感統一、必要に応じて部分再生成 |
| **6. TimeOfDayScenery 化** | `TimeOfDayBackground` → `TimeOfDayScenery`（画像 + gradient フォールバック）、`WalkView` の参照更新 | 歩くタブで時間帯イラスト表示、画像欠落でも gradient で動く |
| **7. CompanionLines 拡張** | LLM で文言量産（設計時）→ 人間がほのぼの度フィルタ → `CompanionLines.json`、`CompanionDialog` を JSON ロード + filter 化、`CompanionLineFilter` 追加、テスト | 文言 pool が状態軸でフィルタされる、JSON 不在でも fallback 文言 |
| **8. Home 主役化** | `StepHeroCard` / `JourneyMiniCard` 新規、`HomeView` を `ScrollView + LazyVStack` に置換、タップでタブ切替、Preview を Fixtures で整備 | ホーム上半分が歩く主役、ミニカードタップで歩くタブへ |
| **9. 仕上げ** | iPhone 17 シミュレータで golden path 動作確認、既存（記録/メニュー/履歴）リグレッション確認、README/CLAUDE.md 更新 | 全機能動作、ドキュメント整合 |

### 8.1 ロールバック単位

各 Phase ＝ 1 コミット（または小さな PR）。Phase 間で独立してロールバック可能。

### 8.2 並列化できる箇所

Phase 4（パイプライン構築）と Phase 6 / 7 / 8 のコード骨格は並列実装可能（Phase 5 のアセットがなくても fallback で動くため）。

### 8.3 主なリスクと緩和策

| リスク | 緩和策 |
|--------|--------|
| Asset path リネームで参照漏れ | `git grep "Badges/"` を Phase 2 完了前に必ず実行 |
| 生成イラストのスタイル統一性が低い | `style.suffix` を必ず付加、Phase 5 で 1 枚ずつ目視、必要なら再生成 |
| CompanionLines.json のロード失敗 | コード側に hardcoded fallback pool を残す、起動時にロード失敗を log |
| Python 環境のばらつき | `.tool-versions` に `python` 追加、README で `uv sync` 手順明記 |
| 画像生成 API のレート/コスト超過 | キャッシュ（hash 一致なら skip）、`--dry-run` 必須、`--filter` で部分実行 |
| ScrollView 化でレイアウト崩れ | Phase 8 で iPhone SE / 17 / 17 Pro Max の 3 端末で目視 |

## 9. Out of scope（Follow-up spec 候補）

本 spec では実装しない。後続の brainstorm で扱う。

### 9.1 旅のゴール選択

- プリセット切替: 東京→大阪 / 東京→札幌 / ハワイ一周 等
- フリーモード: 距離だけ走らせて、後から到達地点を逆算表示（「結果的に静岡まで歩いた」）
- データモデル拡張: `JourneyRoute` を複数定義可能にする、ユーザー設定で選択

### 9.2 結果表現力強化

- 月次ハイライト: 最長距離日 / 連続日数記録 / 達成チェックポイント一覧
- 比喩表示: 「今月歩いた距離 = 富士山 1 個ぶん登った」「東京タワー◯回ぶん登った」
- 達成タイムライン演出: アニメーション付き履歴ビュー
- 9.1 と組み合わせて「結果的に◯◯まで歩いた」の表示も含む
