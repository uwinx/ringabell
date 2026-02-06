import Foundation
import UserNotifications

enum NotificationSender {
    static func send(title: String, body: String, url: String? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        Self.post(center: center, title: title, body: body, url: url)
                    } else {
                        fputs("ringabell: notification permission denied\n", stderr)
                    }
                }
            case .authorized, .provisional:
                Self.post(center: center, title: title, body: body, url: url)
            default:
                fputs("ringabell: notification permission denied\n", stderr)
            }
        }
    }

    private static func post(center: UNUserNotificationCenter,
                             title: String, body: String, url: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let url {
            content.userInfo["url"] = url
        }

        let request = UNNotificationRequest(
            identifier: "ringabell-\(ProcessInfo.processInfo.processIdentifier)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                fputs("ringabell: failed to send notification: \(error)\n", stderr)
            }
        }
    }
}
