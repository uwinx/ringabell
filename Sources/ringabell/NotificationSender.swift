import AppKit
import UserNotifications

enum NotificationSender {
    static func send(title: String, subtitle: String, body: String, url: String?,
                     icon: NotificationIcon, buttons: [NotificationButton]) {
        // Render icon on the calling (main) thread — lockFocus requires it.
        // macOS draws the action button over the attachment thumbnail, so skip it when buttons exist.
        let attachment = buttons.isEmpty ? iconAttachment(icon) : nil
        let center = UNUserNotificationCenter.current()

        if !buttons.isEmpty {
            let actions = buttons.map {
                UNNotificationAction(identifier: $0.id, title: $0.title, options: [])
            }
            let category = UNNotificationCategory(
                identifier: "ringabell-actions",
                actions: actions,
                intentIdentifiers: [],
                options: []
            )
            center.setNotificationCategories([category])
        }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        Self.post(center: center, title: title, subtitle: subtitle, body: body, url: url,
                                  attachment: attachment, hasButtons: !buttons.isEmpty)
                    } else {
                        fputs("ringabell: notification permission denied\n", stderr)
                        Self.discard(attachment)
                    }
                }
            case .authorized, .provisional:
                Self.post(center: center, title: title, subtitle: subtitle, body: body, url: url,
                          attachment: attachment, hasButtons: !buttons.isEmpty)
            default:
                fputs("ringabell: notification permission denied\n", stderr)
                Self.discard(attachment)
            }
        }
    }

    private static func post(center: UNUserNotificationCenter,
                             title: String, subtitle: String, body: String, url: String?,
                             attachment: UNNotificationAttachment?,
                             hasButtons: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        if let url {
            content.userInfo["url"] = url
        }
        if hasButtons {
            content.categoryIdentifier = "ringabell-actions"
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
                Self.discard(attachment)
            }
        }
    }

    // A posted attachment's file is moved into the notification store; one that never gets posted stays in TMPDIR.
    private static func discard(_ attachment: UNNotificationAttachment?) {
        guard let attachment else { return }
        try? FileManager.default.removeItem(at: attachment.url)
    }

    private static func iconAttachment(_ icon: NotificationIcon) -> UNNotificationAttachment? {
        let tmpBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("ringabell-icon-\(ProcessInfo.processInfo.processIdentifier)")

        let tmp: URL
        switch icon {
        case .emoji(let emoji):
            guard let tiff = emoji.render(size: 128).tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }
            tmp = tmpBase.appendingPathExtension("png")
            guard (try? png.write(to: tmp)) != nil else { return nil }
        case .file(let source):
            // The attachment store moves the file it is given; hand it a copy, not the user's file.
            tmp = tmpBase.appendingPathExtension(source.pathExtension.lowercased())
            try? FileManager.default.removeItem(at: tmp)
            do {
                try FileManager.default.copyItem(at: source, to: tmp)
            } catch {
                fputs("ringabell: failed to read --icon-file: \(error.localizedDescription)\n", stderr)
                return nil
            }
        }

        do {
            return try UNNotificationAttachment(identifier: "icon", url: tmp, options: nil)
        } catch {
            fputs("ringabell: failed to attach icon: \(error.localizedDescription)\n", stderr)
            try? FileManager.default.removeItem(at: tmp)
            return nil
        }
    }
}
