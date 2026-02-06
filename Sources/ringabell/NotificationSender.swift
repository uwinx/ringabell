import AppKit
import UserNotifications

enum NotificationSender {
    static func send(title: String, body: String, url: String? = nil, icon: AppIcon = .party) {
        // Render icon on the calling (main) thread — lockFocus requires it.
        let attachment = iconAttachment(icon)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        Self.post(center: center, title: title, body: body, url: url, attachment: attachment)
                    } else {
                        fputs("ringabell: notification permission denied\n", stderr)
                    }
                }
            case .authorized, .provisional:
                Self.post(center: center, title: title, body: body, url: url, attachment: attachment)
            default:
                fputs("ringabell: notification permission denied\n", stderr)
            }
        }
    }

    private static func post(center: UNUserNotificationCenter,
                             title: String, body: String, url: String?,
                             attachment: UNNotificationAttachment?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let url {
            content.userInfo["url"] = url
        }
        if let attachment {
            content.attachments = [attachment]
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

    private static func iconAttachment(_ icon: AppIcon) -> UNNotificationAttachment? {
        let image = icon.render(size: 128)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ringabell-icon-\(ProcessInfo.processInfo.processIdentifier).png")

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try png.write(to: tmp)
            let attachment = try UNNotificationAttachment(
                identifier: "icon",
                url: tmp,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
            )
            return attachment
        } catch {
            return nil
        }
    }
}
