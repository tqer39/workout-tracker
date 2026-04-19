import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case chest = "胸"
    case back = "背"
    case legs = "脚"
    case shoulders = "肩"
    case arms = "腕"
    case core = "体幹"
    case other = "その他"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum BodyMetricSource: String, Codable {
    case healthKit
    case manual
}
