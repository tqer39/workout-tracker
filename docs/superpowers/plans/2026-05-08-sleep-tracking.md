# 睡眠記録機能 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apple Watch が記録した睡眠データを HealthKit から取り込み、履歴タブで総ボリュームと並べて可視化する（30/90 日切替、目標達成判定、ホーム/記録タブにも軽い表示）。

**Architecture:** Walk タブと同型の 3 層構造（純粋関数の Domain → @Observable な Service → SwiftUI View）。HealthKit `sleepAnalysis` から取得した `HKCategorySample` を純粋値型 `SleepSample` に詰め直して `SleepAggregator` に渡し、終わった朝の `dayStart` ごとに合算した `SleepDailyDTO` を `SleepDailyRecord`（@Attribute(.unique) dayStart）に upsert する。

**Tech Stack:** Swift / SwiftUI / SwiftData / HealthKit / Swift Charts / XCTest / XcodeGen / iOS 18+。

**Spec:** `docs/superpowers/specs/2026-05-08-sleep-tracking-design.md`

---

## File Structure

### 新規ファイル

| パス | 役割 |
|------|------|
| `WorkoutTracker/Models/SleepDailyRecord.swift` | SwiftData モデル（夜単位の合計睡眠分） |
| `WorkoutTracker/Domain/SleepAggregator.swift` | `SleepSample` 値型 + 合算ロジック（純粋関数） |
| `WorkoutTracker/Domain/SleepStreak.swift` | 目標達成日の連続記録（純粋関数） |
| `WorkoutTracker/Services/SleepService.swift` | @Observable, bootstrap / refreshOnAppear / lastNightMinutes |
| `WorkoutTracker/Features/Sleep/SleepHistoryView.swift` | 30/90 日切替、棒グラフ + 折れ線、サマリ、リスト |
| `WorkoutTracker/Features/Sleep/SleepSettingsView.swift` | 目標睡眠時間 Stepper |
| `WorkoutTrackerTests/ModelsTests/SleepDailyRecordTests.swift` | unique dayStart, 基本属性 |
| `WorkoutTrackerTests/DomainTests/SleepAggregatorTests.swift` | 集約 5 ケース |
| `WorkoutTrackerTests/DomainTests/SleepStreakTests.swift` | ストリーク 3 ケース |
| `WorkoutTrackerTests/ServicesTests/SleepServiceTests.swift` | bootstrap → upsert / 再 bootstrap で重複なし |

### 修正ファイル

| パス | 変更内容 |
|------|---------|
| `WorkoutTracker/Models/Enums.swift` | `SleepSource` 追加 |
| `WorkoutTracker/Models/ModelContainerFactory.swift` | スキーマに `SleepDailyRecord.self` |
| `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift` | スキーマに `SleepDailyRecord.self` |
| `WorkoutTracker/Services/HealthKitService.swift` | `SleepDailyDTO` 追加、プロトコルに 2 メソッド、Live 実装 |
| `WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift` | `StubHealthKitService` に `sleepData` 追加 + テスト |
| `WorkoutTracker/Features/History/HistoryView.swift` | `Tab.sleep` 追加、4 セグメント |
| `WorkoutTracker/Features/Home/HomeView.swift` | 「昨夜の睡眠」セクション追加 |
| `WorkoutTracker/Features/Recording/RecordingView.swift` | ヘッダー上端に 1 行表示 |
| `WorkoutTracker/App/WorkoutTrackerApp.swift` | `SleepService` 生成・注入・bootstrap |
| `project.yml` | `NSHealthShareUsageDescription` 文言更新 |

---

## Task 1: SleepSource enum と Info.plist 文言の更新

**Files:**
- Modify: `WorkoutTracker/Models/Enums.swift`
- Modify: `project.yml`

- [ ] **Step 1: `SleepSource` を Enums.swift に追加する**

`WorkoutTracker/Models/Enums.swift` の `StepSource` 定義のすぐ下に追加:

```swift
enum SleepSource: String, Codable {
    case healthKit
    case seed
}
```

- [ ] **Step 2: `project.yml` の Info.plist 文言を更新する**

`NSHealthShareUsageDescription` の値を以下に置き換える:

```yaml
        NSHealthShareUsageDescription: 体重・体脂肪率・歩数・睡眠の推移をアプリに取り込みます。
```

- [ ] **Step 3: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

期待: 警告なしで終わる。`WorkoutTracker.xcodeproj` が再生成される。

- [ ] **Step 4: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Models/Enums.swift project.yml
git commit -m "$(cat <<'EOF'
✨ feat: SleepSource enum と Info.plist の睡眠用途文言を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `SleepDailyRecord` モデル

**Files:**
- Create: `WorkoutTracker/Models/SleepDailyRecord.swift`
- Modify: `WorkoutTracker/Models/ModelContainerFactory.swift`
- Modify: `WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift`
- Create: `WorkoutTrackerTests/ModelsTests/SleepDailyRecordTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

新規ファイル `WorkoutTrackerTests/ModelsTests/SleepDailyRecordTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class SleepDailyRecordTests: XCTestCase {
    func test_basic_attributes_persist() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        let record = SleepDailyRecord(
            dayStart: day,
            totalMinutes: 432,
            source: .healthKit,
            lastSyncedAt: Date()
        )
        ctx.insert(record)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.totalMinutes, 432)
        XCTAssertEqual(fetched.first?.source, .healthKit)
    }

    func test_unique_dayStart_overwrites_via_explicit_replace() throws {
        let container = try InMemoryContainer.make()
        let ctx = container.mainContext
        let day = Calendar.current.startOfDay(for: Date())

        let first = SleepDailyRecord(
            dayStart: day, totalMinutes: 360, source: .healthKit, lastSyncedAt: Date()
        )
        ctx.insert(first)
        try ctx.save()

        // 同じ dayStart の既存を削除してから新規挿入する upsert パターン
        var fd = FetchDescriptor<SleepDailyRecord>(
            predicate: #Predicate { $0.dayStart == day }
        )
        fd.fetchLimit = 1
        if let existing = try ctx.fetch(fd).first {
            existing.totalMinutes = 480
            existing.lastSyncedAt = Date()
        }
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.totalMinutes, 480)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepDailyRecordTests
```

期待: コンパイルエラー（`SleepDailyRecord` が未定義）。

- [ ] **Step 3: 実装を書く**

新規ファイル `WorkoutTracker/Models/SleepDailyRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SleepDailyRecord {
    var id: UUID
    @Attribute(.unique) var dayStart: Date
    var totalMinutes: Int
    var source: SleepSource
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        dayStart: Date,
        totalMinutes: Int,
        source: SleepSource,
        lastSyncedAt: Date
    ) {
        self.id = id
        self.dayStart = dayStart
        self.totalMinutes = totalMinutes
        self.source = source
        self.lastSyncedAt = lastSyncedAt
    }
}
```

- [ ] **Step 4: ModelContainerFactory のスキーマに追加する**

`WorkoutTracker/Models/ModelContainerFactory.swift` の `Schema([...])` に 1 行追加:

```swift
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
            StepDailyRecord.self,
            CheckpointAchievement.self,
            SleepDailyRecord.self,
        ])
```

- [ ] **Step 5: InMemoryContainer のスキーマに追加する**

`WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift` の `Schema([...])` に同様に追加:

```swift
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SetRecord.self,
            BodyMetric.self,
            StepDailyRecord.self,
            CheckpointAchievement.self,
            SleepDailyRecord.self,
        ])
```

- [ ] **Step 6: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 7: テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepDailyRecordTests
```

期待: 2 テストが PASS。

- [ ] **Step 8: 既存テスト全体が通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS（スキーマ変更で既存テストが壊れないことを確認）。

- [ ] **Step 9: コミット**

```bash
git add WorkoutTracker/Models/SleepDailyRecord.swift \
        WorkoutTracker/Models/ModelContainerFactory.swift \
        WorkoutTrackerTests/TestHelpers/InMemoryContainer.swift \
        WorkoutTrackerTests/ModelsTests/SleepDailyRecordTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: SleepDailyRecord モデルとスキーマ登録を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `SleepAggregator` と `SleepSample`

**Files:**
- Create: `WorkoutTracker/Domain/SleepAggregator.swift`
- Create: `WorkoutTrackerTests/DomainTests/SleepAggregatorTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

新規ファイル `WorkoutTrackerTests/DomainTests/SleepAggregatorTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

final class SleepAggregatorTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func test_single_night_simple_sum() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 23, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            )
        ]
        let result = SleepAggregator.aggregate(samples: samples)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalMinutes, 7 * 60)
        XCTAssertEqual(
            result[0].dayStart,
            Calendar.current.startOfDay(for: date(2026, 5, 8, 6, 0))
        )
    }

    func test_multiple_samples_same_morning_are_summed() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 22, 30),
                endDate:   date(2026, 5, 8, 1, 0),
                isAsleep:  true
            ),
            SleepSample(
                startDate: date(2026, 5, 8, 1, 30),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            ),
        ]
        let result = SleepAggregator.aggregate(samples: samples)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalMinutes, 150 + 270)
    }

    func test_inBed_samples_are_skipped() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 22, 0),
                endDate:   date(2026, 5, 7, 23, 0),
                isAsleep:  false
            ),
            SleepSample(
                startDate: date(2026, 5, 7, 23, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            ),
        ]
        let result = SleepAggregator.aggregate(samples: samples)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalMinutes, 7 * 60)
    }

    func test_overnight_attributes_to_morning() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 7, 22, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            )
        ]
        let result = SleepAggregator.aggregate(samples: samples)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(
            result[0].dayStart,
            Calendar.current.startOfDay(for: date(2026, 5, 8, 6, 0))
        )
    }

    func test_two_separate_nights_yield_two_dtos() {
        let samples = [
            SleepSample(
                startDate: date(2026, 5, 6, 23, 0),
                endDate:   date(2026, 5, 7, 6, 0),
                isAsleep:  true
            ),
            SleepSample(
                startDate: date(2026, 5, 7, 23, 0),
                endDate:   date(2026, 5, 8, 6, 0),
                isAsleep:  true
            ),
        ]
        let result = SleepAggregator.aggregate(samples: samples)
            .sorted(by: { $0.dayStart < $1.dayStart })
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].totalMinutes, 7 * 60)
        XCTAssertEqual(result[1].totalMinutes, 7 * 60)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepAggregatorTests
```

期待: コンパイルエラー（`SleepSample` / `SleepAggregator` 未定義）。

- [ ] **Step 3: 実装を書く**

新規ファイル `WorkoutTracker/Domain/SleepAggregator.swift`:

```swift
import Foundation

struct SleepSample: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let isAsleep: Bool
}

struct SleepDailyDTO: Equatable, Sendable {
    let dayStart: Date
    let totalMinutes: Int
    let source: SleepSource
}

enum SleepAggregator {
    static func aggregate(
        samples: [SleepSample],
        calendar: Calendar = .current
    ) -> [SleepDailyDTO] {
        var byDay: [Date: TimeInterval] = [:]
        for s in samples where s.isAsleep {
            let key = calendar.startOfDay(for: s.endDate)
            byDay[key, default: 0] += s.endDate.timeIntervalSince(s.startDate)
        }
        return byDay
            .map { (day, seconds) in
                SleepDailyDTO(
                    dayStart: day,
                    totalMinutes: max(0, Int((seconds / 60.0).rounded())),
                    source: .healthKit
                )
            }
            .sorted { $0.dayStart < $1.dayStart }
    }
}
```

> 備考: `SleepDailyDTO` はここで定義する。`HealthKitService.swift` 側に重複定義しないこと（Task 5 で利用するだけ）。

- [ ] **Step 4: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepAggregatorTests
```

期待: 5 テストが PASS。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Domain/SleepAggregator.swift \
        WorkoutTrackerTests/DomainTests/SleepAggregatorTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: SleepAggregator と SleepSample / SleepDailyDTO を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `SleepStreak`

**Files:**
- Create: `WorkoutTracker/Domain/SleepStreak.swift`
- Create: `WorkoutTrackerTests/DomainTests/SleepStreakTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

新規ファイル `WorkoutTrackerTests/DomainTests/SleepStreakTests.swift`:

```swift
import XCTest
@testable import WorkoutTracker

@MainActor
final class SleepStreakTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return cal.date(from: c)!
    }

    private func record(_ d: Date, _ minutes: Int) -> SleepDailyRecord {
        SleepDailyRecord(
            dayStart: d, totalMinutes: minutes, source: .seed, lastSyncedAt: Date()
        )
    }

    func test_three_consecutive_met_days() {
        let today = day(2026, 5, 8)
        let records = [
            record(day(2026, 5, 6), 480),
            record(day(2026, 5, 7), 460),
            record(today, 470),
        ]
        let streak = SleepStreak.currentStreak(
            records: records, targetMinutes: 420, today: today, calendar: cal
        )
        XCTAssertEqual(streak, 3)
    }

    func test_today_unmet_falls_back_to_yesterday() {
        let today = day(2026, 5, 8)
        let records = [
            record(day(2026, 5, 6), 480),
            record(day(2026, 5, 7), 460),
            record(today, 300),  // 未達
        ]
        let streak = SleepStreak.currentStreak(
            records: records, targetMinutes: 420, today: today, calendar: cal
        )
        XCTAssertEqual(streak, 2)
    }

    func test_gap_breaks_streak() {
        let today = day(2026, 5, 8)
        let records = [
            record(day(2026, 5, 5), 480),
            // 5/6 抜け
            record(day(2026, 5, 7), 460),
            record(today, 470),
        ]
        let streak = SleepStreak.currentStreak(
            records: records, targetMinutes: 420, today: today, calendar: cal
        )
        XCTAssertEqual(streak, 2)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepStreakTests
```

期待: コンパイルエラー（`SleepStreak` 未定義）。

- [ ] **Step 3: 実装を書く**

新規ファイル `WorkoutTracker/Domain/SleepStreak.swift`:

```swift
import Foundation

enum SleepStreak {
    static func currentStreak(
        records: [SleepDailyRecord],
        targetMinutes: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(uniqueKeysWithValues:
            records.map { (calendar.startOfDay(for: $0.dayStart), $0.totalMinutes) }
        )

        var cursor = todayStart
        if (byDay[cursor] ?? 0) < targetMinutes {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        var streak = 0
        while let minutes = byDay[cursor], minutes >= targetMinutes {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
```

- [ ] **Step 4: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepStreakTests
```

期待: 3 テストが PASS。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Domain/SleepStreak.swift \
        WorkoutTrackerTests/DomainTests/SleepStreakTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: SleepStreak（睡眠目標達成の連続日数計算）を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `HealthKitService` の睡眠 API 拡張

**Files:**
- Modify: `WorkoutTracker/Services/HealthKitService.swift`
- Modify: `WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift` の `final class HealthKitServiceTests` 内（最後のテストの後）に追加:

```swift
    func test_stub_fetchSleep_returns_injected_values() async throws {
        let day = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            sleepData: [.init(dayStart: day, totalMinutes: 432, source: .healthKit)]
        )
        let result = try await stub.fetchSleep(from: day, to: day)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.totalMinutes, 432)
    }

    func test_stub_requestSleepAuthorization_throws_on_denied() async throws {
        let stub = StubHealthKitService(
            latest: nil, range: [], authorizationError: HealthKitError.denied
        )
        do {
            try await stub.requestSleepAuthorization()
            XCTFail("denied を投げるべき")
        } catch HealthKitError.denied {
            // OK
        }
    }
```

同じファイルの `final class StubHealthKitService` を以下のように拡張する:

1. `dailySteps` プロパティの後に追加:
   ```swift
       var sleepData: [SleepDailyDTO]
   ```
2. イニシャライザの引数末尾に追加:
   ```swift
           sleepData: [SleepDailyDTO] = []
   ```
   そして本体に `self.sleepData = sleepData` を追加。
3. `stopObservingTodaySteps()` の後に追加:
   ```swift
       func requestSleepAuthorization() async throws {
           if let authorizationError { throw authorizationError }
       }
       func fetchSleep(from: Date, to: Date) async throws -> [SleepDailyDTO] { sleepData }
   ```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/HealthKitServiceTests
```

期待: コンパイルエラー（プロトコルに `requestSleepAuthorization` / `fetchSleep` がなく、`StubHealthKitService` がプロトコル準拠を欠く）。

- [ ] **Step 3: プロトコルと Live 実装を拡張する**

`WorkoutTracker/Services/HealthKitService.swift` を編集する。

(a) ファイル冒頭の DTO 定義（`StepDailyDTO` の後）には **何も追加しない**。`SleepDailyDTO` は Task 3 で `Domain/SleepAggregator.swift` に定義済み。

(b) `protocol HealthKitService` に 2 メソッドを追加:

```swift
    func requestSleepAuthorization() async throws
    func fetchSleep(from: Date, to: Date) async throws -> [SleepDailyDTO]
```

(c) `LiveHealthKitService` のプロパティ宣言部（`stepType` の下）に追加:

```swift
    private let sleepType = HKCategoryType(.sleepAnalysis)
```

(d) `LiveHealthKitService` の `stopObservingTodaySteps()` の後にメソッドを追加:

```swift
    func requestSleepAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.unavailable }
        try await store.requestAuthorization(toShare: [], read: [sleepType])
    }

    func fetchSleep(from: Date, to: Date) async throws -> [SleepDailyDTO] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
        let raw: [SleepSample] = try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let q = HKSampleQuery(
                sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let mapped = (samples ?? []).compactMap { $0 as? HKCategorySample }.map { s -> SleepSample in
                    let asleep: Bool
                    switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                    case .asleepUnspecified, .asleepCore, .asleepREM, .asleepDeep:
                        asleep = true
                    default:
                        asleep = false
                    }
                    return SleepSample(startDate: s.startDate, endDate: s.endDate, isAsleep: asleep)
                }
                cont.resume(returning: mapped)
            }
            store.execute(q)
        }
        return SleepAggregator.aggregate(samples: raw)
    }
```

- [ ] **Step 4: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/HealthKitServiceTests
```

期待: 全テストが PASS（既存 6 + 新規 2）。

- [ ] **Step 6: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。

- [ ] **Step 7: コミット**

```bash
git add WorkoutTracker/Services/HealthKitService.swift \
        WorkoutTrackerTests/ServicesTests/HealthKitServiceTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: HealthKitService に睡眠データ取得 API を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `SleepService`

**Files:**
- Create: `WorkoutTracker/Services/SleepService.swift`
- Create: `WorkoutTrackerTests/ServicesTests/SleepServiceTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

新規ファイル `WorkoutTrackerTests/ServicesTests/SleepServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import WorkoutTracker

@MainActor
final class SleepServiceTests: XCTestCase {
    func test_bootstrap_upserts_records_and_sets_lastNightMinutes() async throws {
        let container = try InMemoryContainer.make()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let stub = StubHealthKitService(
            latest: nil, range: [],
            sleepData: [
                .init(dayStart: yesterday, totalMinutes: 360, source: .healthKit),
                .init(dayStart: today,     totalMinutes: 432, source: .healthKit),
            ]
        )
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()

        let stored = try container.mainContext.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(svc.lastNightMinutes, 432)
    }

    func test_double_bootstrap_does_not_duplicate_records() async throws {
        let container = try InMemoryContainer.make()
        let today = Calendar.current.startOfDay(for: Date())
        let stub = StubHealthKitService(
            latest: nil, range: [],
            sleepData: [.init(dayStart: today, totalMinutes: 420, source: .healthKit)]
        )
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()
        await svc.bootstrap()

        let stored = try container.mainContext.fetch(FetchDescriptor<SleepDailyRecord>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.totalMinutes, 420)
    }

    func test_bootstrap_with_empty_sleep_keeps_lastNightMinutes_nil() async throws {
        let container = try InMemoryContainer.make()
        let stub = StubHealthKitService(latest: nil, range: [], sleepData: [])
        let svc = SleepService(healthKit: stub, container: container)

        await svc.bootstrap()

        XCTAssertNil(svc.lastNightMinutes)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepServiceTests
```

期待: コンパイルエラー（`SleepService` 未定義）。

- [ ] **Step 3: 実装を書く**

新規ファイル `WorkoutTracker/Services/SleepService.swift`:

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SleepService {
    var lastNightMinutes: Int?

    private let healthKit: HealthKitService
    private let container: ModelContainer

    init(healthKit: HealthKitService, container: ModelContainer) {
        self.healthKit = healthKit
        self.container = container
    }

    func bootstrap() async {
        try? await healthKit.requestSleepAuthorization()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -90, to: today) ?? today
        let dtos = (try? await healthKit.fetchSleep(from: from, to: today)) ?? []
        upsert(dtos: dtos)
        lastNightMinutes = latestStoredMinutes()
    }

    func refreshOnAppear() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dtos = (try? await healthKit.fetchSleep(from: today, to: today)) ?? []
        upsert(dtos: dtos)
        lastNightMinutes = latestStoredMinutes()
    }

    private func upsert(dtos: [SleepDailyDTO]) {
        let ctx = container.mainContext
        let cal = Calendar.current
        for dto in dtos {
            let day = cal.startOfDay(for: dto.dayStart)
            var fd = FetchDescriptor<SleepDailyRecord>(
                predicate: #Predicate { $0.dayStart == day }
            )
            fd.fetchLimit = 1
            if let existing = try? ctx.fetch(fd).first {
                existing.totalMinutes = dto.totalMinutes
                existing.lastSyncedAt = Date()
            } else {
                ctx.insert(SleepDailyRecord(
                    dayStart: day,
                    totalMinutes: dto.totalMinutes,
                    source: dto.source,
                    lastSyncedAt: Date()
                ))
            }
        }
        try? ctx.save()
    }

    private func latestStoredMinutes() -> Int? {
        let ctx = container.mainContext
        var fd = FetchDescriptor<SleepDailyRecord>(
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        fd.fetchLimit = 1
        return (try? ctx.fetch(fd))?.first?.totalMinutes
    }
}
```

- [ ] **Step 4: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests/SleepServiceTests
```

期待: 3 テストが PASS。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Services/SleepService.swift \
        WorkoutTrackerTests/ServicesTests/SleepServiceTests.swift
git commit -m "$(cat <<'EOF'
✨ feat: SleepService（睡眠データのブートストラップと永続化）を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: アプリ起動時の `SleepService` 注入

**Files:**
- Modify: `WorkoutTracker/App/WorkoutTrackerApp.swift`

- [ ] **Step 1: 注入コードを追加する**

`WorkoutTracker/App/WorkoutTrackerApp.swift` を以下のとおり書き換える。

`@State private var journey` の下に追加:

```swift
    @State private var sleep: SleepService
```

`init()` の中、`self._journey = ...` の直後に追加:

```swift
        let sleepSvc = SleepService(
            healthKit: LiveHealthKitService(),
            container: c
        )
        self._sleep = State(initialValue: sleepSvc)
```

`Task { @MainActor in await svc.bootstrap() }` の直後に追加:

```swift
        Task { @MainActor in
            await sleepSvc.bootstrap()
        }
```

`body` の `RootView()` チェーンを修正:

```swift
            RootView()
                .environment(journey)
                .environment(sleep)
```

- [ ] **Step 2: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 3: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。

- [ ] **Step 4: コミット**

```bash
git add WorkoutTracker/App/WorkoutTrackerApp.swift
git commit -m "$(cat <<'EOF'
✨ feat: アプリ起動時に SleepService を注入してブートストラップする

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `SleepHistoryView` と `HistoryView` 4 セグメント化

**Files:**
- Create: `WorkoutTracker/Features/Sleep/SleepHistoryView.swift`
- Modify: `WorkoutTracker/Features/History/HistoryView.swift`

- [ ] **Step 1: `SleepHistoryView` を作成する**

新規ファイル `WorkoutTracker/Features/Sleep/SleepHistoryView.swift`:

```swift
import SwiftUI
import SwiftData
import Charts

struct SleepHistoryView: View {
    @Environment(SleepService.self) private var sleep
    @AppStorage("sleep.targetHours") private var targetHours: Double = 7.0

    @Query(sort: [SortDescriptor(\SleepDailyRecord.dayStart, order: .reverse)])
    private var records: [SleepDailyRecord]

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @State private var rangeDays: Int = 30
    @State private var settingsPresented: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("", selection: $rangeDays) {
                    Text("30 日").tag(30)
                    Text("90 日").tag(90)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                summary
                chart
                list
            }
            .padding(.vertical, 8)
        }
        .task { await sleep.refreshOnAppear() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    settingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $settingsPresented) { SleepSettingsView() }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView(
                    "睡眠データなし",
                    systemImage: "moon.zzz",
                    description: Text("HealthKit から睡眠を取得すると表示されます")
                )
            }
        }
    }

    private var targetMinutes: Int { Int(targetHours * 60) }

    private var rangeRecords: [SleepDailyRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let from = cal.date(byAdding: .day, value: -(rangeDays - 1), to: today) ?? today
        return records
            .filter { $0.dayStart >= from && $0.dayStart <= today }
            .sorted(by: { $0.dayStart < $1.dayStart })
    }

    private var averageHours: Double {
        let r = rangeRecords
        guard !r.isEmpty else { return 0 }
        let total = r.reduce(0) { $0 + $1.totalMinutes }
        return Double(total) / Double(r.count) / 60.0
    }

    private var streakDays: Int {
        SleepStreak.currentStreak(records: records, targetMinutes: targetMinutes)
    }

    private func dailyVolume(for day: Date) -> Double {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let sets = sessions
            .filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
            .flatMap(\.sets)
            .map { WorkoutMetrics.SetInput(weightKg: $0.weightKg, reps: $0.reps) }
        return WorkoutMetrics.totalVolume(sets: sets)
    }

    private var summary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("平均睡眠").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f h", averageHours)).font(.title3).bold()
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("ストリーク").font(.caption).foregroundStyle(.secondary)
                Text("\(streakDays) 日").font(.title3).bold()
            }
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text("目標").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f h", targetHours)).font(.title3).bold()
            }
        }
        .padding(.horizontal)
    }

    private var chart: some View {
        Chart {
            ForEach(rangeRecords, id: \.dayStart) { r in
                BarMark(
                    x: .value("日付", r.dayStart, unit: .day),
                    y: .value("睡眠 (h)", Double(r.totalMinutes) / 60.0)
                )
                .foregroundStyle(
                    Double(r.totalMinutes) >= Double(targetMinutes)
                    ? Color.green : Color.orange
                )
            }
            ForEach(rangeRecords, id: \.dayStart) { r in
                LineMark(
                    x: .value("日付", r.dayStart, unit: .day),
                    y: .value("ボリューム", dailyVolume(for: r.dayStart))
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("目標", targetHours))
                .foregroundStyle(Color.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .padding(.horizontal)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rangeRecords.reversed(), id: \.dayStart) { r in
                HStack {
                    Text(r.dayStart, format: .dateTime.month().day())
                        .frame(width: 80, alignment: .leading)
                    Text(String(format: "%.1f h", Double(r.totalMinutes) / 60.0))
                        .foregroundStyle(
                            Double(r.totalMinutes) >= Double(targetMinutes)
                            ? .green : .orange
                        )
                    Spacer()
                    let vol = dailyVolume(for: r.dayStart)
                    Text(vol > 0 ? "vol \(Int(vol.rounded())) kg" : "vol --")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()
            }
        }
    }
}

#Preview {
    SleepHistoryView()
        .modelContainer(for: [
            SleepDailyRecord.self, WorkoutSession.self, SetRecord.self, Exercise.self
        ], inMemory: true)
        .environment(SleepService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
}
```

> 備考: `WorkoutMetrics.SetInput` と `WorkoutMetrics.totalVolume(sets:)` は既存の `WorkoutTracker/Domain/WorkoutMetrics.swift` で定義済みのため、そのまま利用する（既存 `HomeView` の `weekVolume` と同パターン）。

- [ ] **Step 2: `HistoryView` に `.sleep` セグメントを追加する**

`WorkoutTracker/Features/History/HistoryView.swift` を編集する。

`enum Tab` を以下のとおり変更:

```swift
    enum Tab: String, CaseIterable, Identifiable {
        case sessions = "セッション"
        case charts = "グラフ"
        case body = "体組成"
        case sleep = "睡眠"
        var id: String { rawValue }
    }
```

`switch tab` を以下のとおり変更:

```swift
                switch tab {
                case .sessions: SessionsListView()
                case .charts: ExerciseChartsView()
                case .body: BodyCompositionView()
                case .sleep: SleepHistoryView()
                }
```

- [ ] **Step 3: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 4: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。`SleepSettingsView` の参照が未解決でエラーになる場合は次の Task で解消するので、このステップでは Task 9 を先に進めるか、暫定的に `SleepSettingsView` 部分（`@State private var settingsPresented` と `.toolbar` と `.sheet`）をコメントアウトしてビルド確認後に戻す。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Sleep/SleepHistoryView.swift \
        WorkoutTracker/Features/History/HistoryView.swift
git commit -m "$(cat <<'EOF'
✨ feat: 履歴タブに睡眠セグメントと SleepHistoryView を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `SleepSettingsView`

**Files:**
- Create: `WorkoutTracker/Features/Sleep/SleepSettingsView.swift`

- [ ] **Step 1: 実装を書く**

新規ファイル `WorkoutTracker/Features/Sleep/SleepSettingsView.swift`:

```swift
import SwiftUI

struct SleepSettingsView: View {
    @AppStorage("sleep.targetHours") private var targetHours: Double = 7.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("睡眠目標時間") {
                    Stepper(value: $targetHours, in: 5.0...10.0, step: 0.5) {
                        Text(String(format: "%.1f h", targetHours))
                    }
                }
            }
            .navigationTitle("睡眠設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

#Preview { SleepSettingsView() }
```

- [ ] **Step 2: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 3: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`（Task 8 でコメントアウトしていた場合は元に戻す）。

- [ ] **Step 4: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。

- [ ] **Step 5: コミット**

```bash
git add WorkoutTracker/Features/Sleep/SleepSettingsView.swift
git commit -m "$(cat <<'EOF'
✨ feat: SleepSettingsView（睡眠目標時間 Stepper）を追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: ホームミニカード + 記録タブヘッダー + 最終確認

**Files:**
- Modify: `WorkoutTracker/Features/Home/HomeView.swift`
- Modify: `WorkoutTracker/Features/Recording/RecordingView.swift`

- [ ] **Step 1: `HomeView` に「昨夜の睡眠」セクションを追加する**

`WorkoutTracker/Features/Home/HomeView.swift` を編集する。

(a) `@Environment(JourneyService.self)` の下に追加:

```swift
    @Environment(SleepService.self) private var sleep
    @AppStorage("sleep.targetHours") private var sleepTargetHours: Double = 7.0
```

(b) `Section("今日の歩数") { todayWalkCard }` の直後に追加:

```swift
                Section("昨夜の睡眠") {
                    lastNightSleepCard
                }
```

(c) `private var todayWalkCard` の後に追加:

```swift
    private var lastNightSleepCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: sleepProgress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(sleepAchievementPercent) %")
                    .font(.caption).bold()
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                if let m = sleep.lastNightMinutes {
                    Text(String(format: "%.1f h", Double(m) / 60.0))
                        .font(.title3).bold()
                    Text(String(format: "目標 %.1f h", sleepTargetHours))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("昨夜の記録なし").font(.title3)
                    Text("HealthKit から取得後に表示")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var sleepProgress: Double {
        guard let m = sleep.lastNightMinutes, sleepTargetHours > 0 else { return 0 }
        let target = sleepTargetHours * 60.0
        return min(1.0, Double(m) / target)
    }

    private var sleepAchievementPercent: Int {
        guard let m = sleep.lastNightMinutes, sleepTargetHours > 0 else { return 0 }
        let target = sleepTargetHours * 60.0
        return Int((Double(m) / target * 100).rounded())
    }
```

(d) Preview の `.environment(JourneyService(...))` の後に追加:

```swift
        .environment(SleepService(
            healthKit: LiveHealthKitService(),
            container: ModelContainerFactory.makeShared()
        ))
```

(e) Preview の `modelContainer` 配列に追加:

```swift
            SleepDailyRecord.self,
```

- [ ] **Step 2: `RecordingView` ヘッダーに 1 行追加する**

`WorkoutTracker/Features/Recording/RecordingView.swift` を編集する。

(a) `@State private var vm = RecordingViewModel()` の上に追加:

```swift
    @Environment(SleepService.self) private var sleep
```

(b) `body` の `Group { ... }` を `VStack(spacing: 0) { sleepHeader; Group { ... } }` で囲み、`.navigationTitle("記録")` は `VStack` に付ける:

```swift
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sleepHeader
                Group {
                    if let session = vm.session {
                        ActiveSessionView(session: session, vm: vm)
                    } else {
                        startView
                    }
                }
            }
            .navigationTitle("記録")
        }
        .onAppear {
            vm.bind(context: ctx)
            Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    @ViewBuilder
    private var sleepHeader: some View {
        if let m = sleep.lastNightMinutes {
            Text(String(format: "昨夜 %.1f h", Double(m) / 60.0))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 4)
        } else {
            EmptyView()
        }
    }
```

- [ ] **Step 3: `xcodegen generate` を実行する**

```bash
xcodegen generate
```

- [ ] **Step 4: ビルドが通ることを確認する**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。

- [ ] **Step 5: 全テストが通ることを確認する**

```bash
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

期待: 全テスト PASS。新規追加分（SleepDailyRecordTests 2 + SleepAggregatorTests 5 + SleepStreakTests 3 + HealthKitServiceTests 2 + SleepServiceTests 3 = 15 件）が含まれる。

- [ ] **Step 6: コミット**

```bash
git add WorkoutTracker/Features/Home/HomeView.swift \
        WorkoutTracker/Features/Recording/RecordingView.swift
git commit -m "$(cat <<'EOF'
✨ feat: ホームに「昨夜の睡眠」ミニカードと記録タブヘッダーを追加

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: 最終ビルド + シミュレータ起動確認（任意）**

```bash
xcodebuild -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

期待: `BUILD SUCCEEDED`。シミュレータでアプリを起動し、履歴タブに「睡眠」セグメントが表示され、ホームに「昨夜の睡眠」セクションが表示されることを目視確認する。
