import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let current = await center.notificationSettings()
        guard current.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleRestEnd(after seconds: Int, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = "休憩終了"
        content.body = "次のセットへ！"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds), repeats: false
        )
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(req)
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
