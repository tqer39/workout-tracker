import Foundation
import SwiftData

@Model
final class BodyMetric {
    var id: UUID
    var recordedAt: Date
    var weightKg: Double?
    var bodyFatPercent: Double?
    var source: BodyMetricSource

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        weightKg: Double? = nil,
        bodyFatPercent: Double? = nil,
        source: BodyMetricSource
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.source = source
    }
}
