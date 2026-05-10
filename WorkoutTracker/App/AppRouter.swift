import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    enum PendingStart: Equatable {
        case empty
        case template(UUID)
    }

    var selectedTab: AppTab = .home
    var pendingStart: PendingStart?

    init(selectedTab: AppTab = .home, pendingStart: PendingStart? = nil) {
        self.selectedTab = selectedTab
        self.pendingStart = pendingStart
    }

    func requestStart(template id: UUID) {
        pendingStart = .template(id)
        selectedTab = .recording
    }

    func requestStartEmpty() {
        pendingStart = .empty
        selectedTab = .recording
    }

    func consumePendingStart() -> PendingStart? {
        defer { pendingStart = nil }
        return pendingStart
    }
}
