# 0 セットセッションの自動破棄 設計書

**作成日:** 2026-05-08
**対象:** iOS（記録タブ / セッション終了フロー）

## 目的

「セッションを開始したが 1 セットも記録せずに終了した」場合に、空の `WorkoutSession` を SwiftData に残さない。履歴・グラフ・週次サマリにゴミデータが混入する問題を解消する。

## 背景

現在 `RecordingViewModel` は以下のように動作している:

- `startEmptySession()` / `startSession(from:)` で `WorkoutSession` を即座に `ctx.insert` + `save`
- `endSession()` は `endedAt` を立てて `save` するのみ

この結果、ユーザーが「開始 → 即終了」または「種目を選んだだけでセット未入力 → 終了」したとき、`sets.isEmpty` のセッションが履歴に残り続ける。

## スコープ

### やること

- `RecordingViewModel.endSession()` で `session.sets.isEmpty` のとき `ctx.delete(session)` する
- セット数 1 以上のときは従来通り `endedAt = Date()` を立てて保存する
- 上記の挙動をテストで担保する

### やらないこと

- 中断（バックグラウンド遷移 / アプリ終了）時の自動破棄。`endedAt == nil` のまま残るセッションのクリーンアップは別件。
- 「最初のセット入力までセッションを永続化しない」方式（ViewModel の状態遷移を再設計する本格対応）への切り替え。
- 終了時のトースト・確認ダイアログ追加。ユーザー意図（「記録しないで」）に従い静かに破棄する。
- 履歴クエリ側の `sets.isEmpty` フィルタ追加（実体を消すので不要）。

## 判定タイミング

「終了」ボタン押下時のみ。ActiveSessionView の `confirmationDialog "セッションを終了しますか?"` で「終了する」を押した瞬間に `endSession()` 内で判定する。

## 変更内容

### `WorkoutTracker/Features/Recording/RecordingViewModel.swift`

```swift
func endSession() {
    guard let ctx, let session else { return }

    // タイマー / 通知の後始末は両分岐で必須
    restTimer.cancel()
    NotificationService.shared.cancel(identifier: "rest-\(session.id.uuidString)")

    if session.sets.isEmpty {
        ctx.delete(session)
    } else {
        session.endedAt = Date()
    }
    try? ctx.save()
    self.session = nil
}
```

ポイント:

- `restTimer.cancel()` と通知キャンセルは破棄時にも実行する。0 セット終了時は通常 `addSet` が呼ばれていないため実行中タイマーは無いはずだが、安全のため両分岐で呼ぶ。
- `ctx.delete(session)` は SwiftData の cascade ルール（`@Relationship(deleteRule: .cascade, inverse: \SetRecord.session)`）により付随する `SetRecord` も同時に消す。本ケースは 0 件なので実害はないが、整合性として記述しておく。
- `templateRef` は cascade 関係でないため、テンプレ起動セッションを破棄してもテンプレート自体は影響を受けない。

### UI 側の変更

なし。`ActiveSessionView` の終了確認ダイアログ・トースト類は変更しない。

## テスト

`WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift` を新規作成する。既存テストに ViewModel 系の置き場が無いため `FeaturesTests/` ディレクトリを新設する（`project.yml` の `WorkoutTrackerTests` ターゲットは `path: WorkoutTrackerTests` で配下を再帰的に拾うため設定変更は不要）。

各テストは `@MainActor` 上で `TestHelpers/InMemoryContainer.make()` から `ModelContainer` を作り、`mainContext` を `RecordingViewModel.bind(context:)` に渡す（既存 `SeedServiceTests` と同じパターン）。

ケース 1: `test_endSession_withZeroSets_deletesSession`

- `startEmptySession()` 後ただちに `endSession()` を呼ぶ
- `ctx.fetch(FetchDescriptor<WorkoutSession>())` が 0 件であること

ケース 2: `test_endSession_withOneOrMoreSets_persistsSessionWithEndedAt`

- 任意の `Exercise` を 1 件 insert → `startEmptySession()` → `addSet(...)` を 1 回 → `endSession()`
- `WorkoutSession` が 1 件残り、`endedAt != nil`、`sets.count == 1` であること

ケース 3: `test_endSession_withZeroSetsFromTemplate_deletesSession`

- `WorkoutTemplate` を 1 件 insert → `startSession(from: template)` → 即 `endSession()`
- セッションは削除され、テンプレート自体は残ること

## 受け入れ基準

- 開始 → 即終了したセッションが履歴に現れない
- 種目を 1 つ選んだだけで（`SetInputRow` から 1 セットも追加せずに）終了したセッションも履歴に現れない
- セット 1 件以上を記録して終了したセッションは従来通り履歴に残り、`endedAt` が記録されている
- 上記 3 ケースのテストがパスする
