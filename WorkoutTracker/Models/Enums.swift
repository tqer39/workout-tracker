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

enum StepSource: String, Codable {
    case healthKit
    case seed
}

enum TimeOfDay: String, CaseIterable {
    case morning, day, evening, night

    static func from(_ date: Date, calendar: Calendar = .current) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .morning
        case 11..<16: return .day
        case 16..<19: return .evening
        default:      return .night
        }
    }
}
