import Foundation

enum ProgressBand: String, Codable, Hashable {
    case unmet
    case achieved
    case completed
}

enum DistanceBand: String, Codable, Hashable {
    case early
    case mid
    case late

    static func from(progress: Double) -> DistanceBand {
        switch progress {
        case ..<0.30: return .early
        case ..<0.70: return .mid
        default:      return .late
        }
    }
}

enum StreakBand: String, Codable, Hashable {
    case firstDay
    case threeDay
    case oneWeek
    case oneMonthPlus

    static func from(streakDays: Int) -> StreakBand {
        switch streakDays {
        case ..<3:   return .firstDay
        case ..<7:   return .threeDay
        case ..<30:  return .oneWeek
        default:     return .oneMonthPlus
        }
    }
}

extension TimeOfDay: Codable {}

struct CompanionLine: Codable, Hashable {
    let text: String
    let progress: [ProgressBand]?
    let timeOfDay: [TimeOfDay]?
    let streak: [StreakBand]?
    let distance: [DistanceBand]?
}

struct CompanionLineFilter {
    let progress: ProgressBand
    let timeOfDay: TimeOfDay
    let streak: StreakBand
    let distance: DistanceBand

    func matches(_ line: CompanionLine) -> Bool {
        if let p = line.progress,    !p.contains(progress) { return false }
        if let t = line.timeOfDay,   !t.contains(timeOfDay) { return false }
        if let s = line.streak,      !s.contains(streak) { return false }
        if let d = line.distance,    !d.contains(distance) { return false }
        return true
    }
}
