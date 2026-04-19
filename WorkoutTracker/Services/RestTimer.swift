import Foundation
import Observation

@Observable
final class RestTimer {
    private(set) var endAt: Date?
    private let nowProvider: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.nowProvider = now
    }

    var isRunning: Bool { endAt != nil }

    func start(duration: Int) {
        endAt = nowProvider().addingTimeInterval(TimeInterval(duration))
    }

    func cancel() {
        endAt = nil
    }

    func remainingSeconds(at date: Date? = nil) -> Int {
        guard let endAt else { return 0 }
        let current = date ?? nowProvider()
        return max(0, Int(endAt.timeIntervalSince(current).rounded()))
    }

    func hasCompleted(at date: Date? = nil) -> Bool {
        guard let endAt else { return false }
        let current = date ?? nowProvider()
        return current >= endAt
    }
}
