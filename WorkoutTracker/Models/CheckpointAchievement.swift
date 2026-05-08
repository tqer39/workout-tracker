import Foundation
import SwiftData

@Model
final class CheckpointAchievement {
    var id: UUID
    @Attribute(.unique) var checkpointId: String
    var achievedAt: Date
    var totalStepsAtAchievement: Int
    var celebrated: Bool

    init(
        id: UUID = UUID(),
        checkpointId: String,
        achievedAt: Date,
        totalStepsAtAchievement: Int,
        celebrated: Bool = false
    ) {
        self.id = id
        self.checkpointId = checkpointId
        self.achievedAt = achievedAt
        self.totalStepsAtAchievement = totalStepsAtAchievement
        self.celebrated = celebrated
    }
}
