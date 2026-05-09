import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case home, recording, menu, history, walk
    }
    enum PendingStart: Equatable {
        case empty
        case template(UUID)
    }

    var selectedTab: Tab = .home
    var pendingStart: PendingStart?

    init(selectedTab: Tab = .home, pendingStart: PendingStart? = nil) {
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
