# workout-tracker

iPhone 向けワークアウト記録アプリ。SwiftUI + SwiftData 製、iOS 18 以降。個人利用のみ、クラウド同期なし。

## 機能

- 種目の登録・編集・非表示
- テンプレート（ワークアウトメニュー）作成
- セッション記録: セット重量・回数・RPE、休憩タイマー（ローカル通知連動）
- 履歴: セッション一覧/詳細、種目別グラフ（推定1RM / ボリューム / トップセット）
- 体組成: HealthKit 同期 + 手動入力、推移グラフ
- ホーム: 今週のボリューム/セット数サマリ

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

## ディレクトリ構成

```
WorkoutTracker/
  App/         アプリエントリ + RootView (TabView)
  Models/      SwiftData @Model 定義
  Domain/      純粋ロジック（ボリューム・1RM 計算）
  Services/    SeedService / RestTimer / NotificationService / HealthKitService
  Features/
    Home/        今週のサマリ
    Recording/   セッション中のセット入力
    Menu/        種目 / テンプレート管理
    History/     セッション履歴 + グラフ + 体組成
WorkoutTrackerTests/   XCTest テスト
docs/superpowers/      設計書・実装計画
```
