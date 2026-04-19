import Foundation
import SwiftData

protocol SeedFlagStore: AnyObject {
    var didSeed: Bool { get set }
}

final class UserDefaultsSeedFlagStore: SeedFlagStore {
    private let key = "didSeedInitialData"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var didSeed: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

enum SeedService {
    struct Preset {
        let name: String
        let category: ExerciseCategory
    }

    static let presets: [Preset] = [
        .init(name: "ベンチプレス", category: .chest),
        .init(name: "スクワット", category: .legs),
        .init(name: "デッドリフト", category: .back),
        .init(name: "オーバーヘッドプレス", category: .shoulders),
        .init(name: "懸垂", category: .back),
        .init(name: "ラットプルダウン", category: .back),
        .init(name: "ベントオーバーロウ", category: .back),
        .init(name: "ダンベルカール", category: .arms),
        .init(name: "レッグプレス", category: .legs),
        .init(name: "レッグカール", category: .legs),
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext, flagStore: SeedFlagStore) {
        guard !flagStore.didSeed else { return }
        for p in presets {
            context.insert(Exercise(name: p.name, category: p.category))
        }
        do {
            try context.save()
            flagStore.didSeed = true
        } catch {
            assertionFailure("seed 保存失敗: \(error)")
        }
    }
}
