# 0 セットセッションの自動破棄 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 終了時に 1 セットも記録されていない `WorkoutSession` を SwiftData から自動破棄し、履歴・グラフ・週次サマリにゴミデータが混入する問題を解消する。

**Architecture:** `RecordingViewModel.endSession()` を 1 メソッド単位で書き換える最小修正。`session.sets.isEmpty` のとき `ctx.delete(session)`、それ以外は従来通り `endedAt = Date()` を立てる。タイマー / 通知の後始末は両分岐で実行する。テストは新規 `WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift` に 3 ケース。UI 側は変更しない。

**Tech Stack:** Swift 5.10 / SwiftUI / SwiftData / iOS 18+ / XCTest / xcodegen 2.43

**Spec:** `docs/superpowers/specs/2026-05-08-discard-empty-session-design.md`

---

## File Structure

- **Modify:** `WorkoutTracker/Features/Recording/RecordingViewModel.swift` — `endSession()` の本体（既存 56-63 行付近）を 0 セット判定込みに書き換える
- **Create:** `WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift` — 新規 `XCTestCase`。空セッション破棄 / 非空維持 / テンプレ起動空セッション破棄 の 3 ケース

`WorkoutTrackerTests/FeaturesTests/` ディレクトリは新設する。`project.yml` の `WorkoutTrackerTests` ターゲットは `path: WorkoutTrackerTests` で配下を再帰的に拾うため、`xcodegen generate` を再実行すれば `.xcodeproj` に新ファイルが取り込まれる（`project.yml` 自体の編集は不要）。

---

### Task 1: 空セッション破棄ケース（赤テスト → 実装 → 緑）

**Files:**
- Create: `WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift`
- Modify: `WorkoutTracker/Features/Recording/RecordingViewModel.swift`

- [ ] **Step 1: 新規テストファイルを作成（最初の失敗テストのみ）**

`WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift` を新規作成し、以下を全文として書き込む:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class RecordingViewModelTests: XCTestCase {
    func test_endSession_withZeroSets_deletesSession() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let vm = RecordingViewModel()
        vm.bind(context: ctx)
        vm.startEmptySession()
        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 1,
            "前提: startEmptySession でセッションが 1 件 insert される"
        )

        vm.endSession()

        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 0,
            "0 セットで終了したセッションは破棄されているはず"
        )
        XCTAssertNil(vm.session)
    }
}
```

- [ ] **Step 2: xcodegen で新規ファイルを Xcode プロジェクトに取り込む**

Run:
```bash
xcodegen generate
```

Expected: 標準出力に `Created project at .../WorkoutTracker.xcodeproj` などのメッセージ。終了コード 0。

- [ ] **Step 3: テストを実行して赤を確認**

Run:
```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:WorkoutTrackerTests/RecordingViewModelTests/test_endSession_withZeroSets_deletesSession
```

Expected: `** TEST FAILED **`。失敗メッセージは `XCTAssertEqual failed: ("1") is not equal to ("0") - 0 セットで終了したセッションは破棄されているはず` の形。現状の `endSession` は `endedAt` を立てるだけで delete しないので fetch すると 1 件残る。

- [ ] **Step 4: `endSession()` を 0 セット判定込みに書き換える**

`WorkoutTracker/Features/Recording/RecordingViewModel.swift` の既存 `endSession()` 実装を以下に置き換える:

```swift
func endSession() {
    guard let ctx, let session else { return }

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

変更点:
- タイマー / 通知のキャンセルをメソッド冒頭（save 前）に移動し、両分岐で実行されるようにする
- `if session.sets.isEmpty` で分岐: 空なら `ctx.delete(session)`、非空なら従来通り `session.endedAt = Date()`
- 旧コードの `restTimer.cancel()` と `NotificationService.shared.cancel(...)` の重複は削除（冒頭に移したため）

- [ ] **Step 5: テストを実行して緑を確認**

Run:
```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:WorkoutTrackerTests/RecordingViewModelTests/test_endSession_withZeroSets_deletesSession
```

Expected: `** TEST SUCCEEDED **`。`Test Case '-[WorkoutTrackerTests.RecordingViewModelTests test_endSession_withZeroSets_deletesSession]' passed`。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Features/Recording/RecordingViewModel.swift \
        WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift \
        WorkoutTracker.xcodeproj
git commit -m "$(cat <<'EOF'
✨ feat: 0 セットセッションの自動破棄

WorkoutSession 終了時に sets が空なら ctx.delete(session) し、
履歴・グラフ・週次サマリにゴミデータが混入しないようにする。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 非空セッションが従来通り保存される回帰テスト

**Files:**
- Modify: `WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift`

- [ ] **Step 1: テストメソッドを `RecordingViewModelTests` クラス内に追加**

Task 1 の `test_endSession_withZeroSets_deletesSession` の直後に以下のメソッドを追加する:

```swift
    func test_endSession_withOneOrMoreSets_persistsSessionWithEndedAt() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let exercise = Exercise(name: "ベンチプレス", category: .chest)
        ctx.insert(exercise)
        try ctx.save()

        let vm = RecordingViewModel()
        vm.bind(context: ctx)
        vm.startEmptySession()
        vm.addSet(exercise: exercise, weightKg: 60.0, reps: 10, rpe: 8.0)

        vm.endSession()

        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1, "セットがあれば破棄されない")
        XCTAssertNotNil(sessions[0].endedAt, "endedAt が立っている")
        XCTAssertEqual(sessions[0].sets.count, 1)
        XCTAssertNil(vm.session)
    }
```

- [ ] **Step 2: テストを実行して緑を確認**

Run:
```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:WorkoutTrackerTests/RecordingViewModelTests/test_endSession_withOneOrMoreSets_persistsSessionWithEndedAt
```

Expected: `** TEST SUCCEEDED **`。Task 1 で導入した else 分岐（`session.endedAt = Date()`）が回帰せず動作することを確認する。

- [ ] **Step 3: コミット**

```bash
git add WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift
git commit -m "$(cat <<'EOF'
✅ test: 非空セッションが endedAt 付きで保存される回帰テストを追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: テンプレ起動 + 0 セット時のセッション破棄・テンプレ存続を保証

**Files:**
- Modify: `WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift`

- [ ] **Step 1: テストメソッドを追加**

Task 2 で追加した `test_endSession_withOneOrMoreSets_persistsSessionWithEndedAt` の直後に以下を追加する:

```swift
    func test_endSession_withZeroSetsFromTemplate_deletesSessionButKeepsTemplate() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext

        let template = WorkoutTemplate(name: "胸の日")
        ctx.insert(template)
        try ctx.save()

        let vm = RecordingViewModel()
        vm.bind(context: ctx)
        vm.startSession(from: template)
        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 1,
            "前提: テンプレ起動でセッションが 1 件 insert される"
        )

        vm.endSession()

        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 0,
            "テンプレ起動でも 0 セットなら破棄される"
        )
        XCTAssertEqual(
            try ctx.fetch(FetchDescriptor<WorkoutTemplate>()).count, 1,
            "テンプレート自体は残る（templateRef は cascade 関係でない）"
        )
        XCTAssertNil(vm.session)
    }
```

- [ ] **Step 2: 単体テストを実行して緑を確認**

Run:
```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:WorkoutTrackerTests/RecordingViewModelTests/test_endSession_withZeroSetsFromTemplate_deletesSessionButKeepsTemplate
```

Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 3: クラス全体のテストを実行（3 ケースまとめて）**

Run:
```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:WorkoutTrackerTests/RecordingViewModelTests
```

Expected: `Test Suite 'RecordingViewModelTests' passed at ...` に続いて `Executed 3 tests, with 0 failures`。

- [ ] **Step 4: 全テストスイートを実行して既存テストへの回帰がないことを確認**

Run:
```bash
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 末尾に `** TEST SUCCEEDED **`。`SeedServiceTests` `WorkoutSessionTests` 等の既存テストを含めすべて緑。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTrackerTests/FeaturesTests/RecordingViewModelTests.swift
git commit -m "$(cat <<'EOF'
✅ test: テンプレ起動 + 0 セットでもセッション破棄・テンプレ存続を確認

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## 実装上の注意

- **`@MainActor`**: `RecordingViewModelTests` クラス全体に `@MainActor` を付与している。`RecordingViewModel` は `@Observable` で SwiftData の `ModelContext` を扱うため、メインアクターでアクセスする。`@MainActor` を付け忘れると SwiftData 周りで実行時警告/エラーが出る可能性がある。
- **`InMemoryContainer.make()`**: テストヘルパは `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift` にある。各テストで毎回新しいコンテナを作って独立性を保つ（既存 `SeedServiceTests` と同パターン）。
- **`NotificationService.shared.cancel(...)`**: テスト中も呼ばれるが、内部は `UNUserNotificationCenter.current().removePendingNotificationRequests(...)` で identifier が無ければ no-op。シミュレータでテストを走らせる前提なので失敗しない。
- **xcodegen の再生成タイミング**: 新規 `.swift` ファイルを追加した直後（Task 1 Step 2）のみ必要。既存ファイルへのメソッド追加（Task 2/3）では再生成不要。
- **`-destination` の iPhone 17**: README に従う。利用可能な Simulator が異なる場合は `xcrun simctl list devices` で適宜変更可能。
