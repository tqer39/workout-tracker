# workout-tracker

iPhone 向けワークアウト記録アプリ。SwiftUI + SwiftData 製、iOS 18 以降。個人利用のみ、クラウド同期なし。

設計コンセプトは「**歩くこと（Step 1）が主役**」。体重が重く本格的な筋トレが厳しい時期でも続けられるよう、ホーム画面で今日の歩数を最大に表示し、東京 → 博多のバーチャル旅をほのぼのコンパニオンで動機づける。

## 機能

- **歩く（Step 1）**: 今日の歩数 + 連続達成日数 + バーチャル旅の進捗。HealthKit から歩数取得、東京 → 博多 1,150 km の 13 チェックポイントを 1 歩 ≈ 1 m 換算で進む
- **ホーム**: StepHeroCard（大きい歩数 + 進捗リング）+ JourneyMiniCard（旅の進捗、タップで歩くタブへ）+ 今週のサマリ + 直近セッション + 最新体組成
- **筋トレ**: 種目登録、テンプレート、セット記録（重量・回数・RPE・休憩タイマー）、セッション履歴・推定1RM/ボリューム/トップセットのグラフ
- **体組成**: HealthKit 同期 + 手動入力、推移グラフ
- **ほのぼのコンパニオン**: 進捗 / 時間帯 / 連続達成 / 旅の距離に応じてセリフを切り替え（`CompanionLines.json` 駆動）

## セットアップ

```bash
mise install                 # xcodegen のインストール
xcodegen generate            # WorkoutTracker.xcodeproj を生成
open WorkoutTracker.xcodeproj
```

## ビルド / テスト

```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## ほのぼのイラストの生成

各時間帯背景・チェックポイント挿絵は OpenAI gpt-image-1 で生成。プロンプトは `scripts/illustrations/prompts.toml` に定義。

```bash
cp .envrc.example .envrc        # OPENAI_API_KEY を記入
direnv allow
cd scripts/illustrations
uv sync
uv run python generate.py --dry-run                  # 生成計画確認
uv run python generate.py --filter tokyo,kyoto       # 一部だけ生成
uv run python generate.py                            # 全 17 枚生成（API 課金あり）
```

生成 PNG は `WorkoutTracker/Resources/Assets.xcassets/Scenery/<id>.imageset/<id>.png` に保存される。SHA256 キャッシュで再生成をスキップ。

## ディレクトリ構成

```
WorkoutTracker/
  App/         アプリエントリ + RootView (TabView, AppTab enum)
  Models/      SwiftData @Model 定義
  Domain/      純粋ロジック（JourneyEngine, CompanionDialog, StreakCalculator, WorkoutMetrics）
  Services/    SeedService / RestTimer / NotificationService / HealthKitService / JourneyService
  TestSupport/ DateHelpers / Fixtures / StubHealthKitService / PreviewModelContainer (#if DEBUG)
  Features/
    Home/        StepHeroCard + JourneyMiniCard + 今週のサマリ
    Walk/        歩く（Step 1）— 旅マップ・コンパニオン・歩数 HUD
    Recording/   セッション中のセット入力
    Menu/        種目 / テンプレート管理
    History/     セッション履歴 + グラフ + 体組成
  Resources/   Assets.xcassets / CompanionLines.json / Info.plist
WorkoutTrackerTests/         XCTest テスト
scripts/illustrations/       Python 画像生成パイプライン（uv + gpt-image-1）
docs/superpowers/            設計書・実装計画
```
