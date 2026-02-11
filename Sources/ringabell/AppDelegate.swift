import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let config: ConfettiConfig
    private var windows: [OverlayWindow] = []

    nonisolated init(config: ConfettiConfig) {
        self.config = config
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.applicationIconImage = config.icon.render()
        UNUserNotificationCenter.current().delegate = self

        switch config.effect {
        case .confetti:
            showConfetti()
        case .pulse:
            showPulse()
        case .none:
            break
        }

        SoundPlayer.play(named: config.soundName)

        if config.showNotification {
            NotificationSender.send(title: "ringabell", body: config.message, url: config.url, icon: config.icon)
        }

        scheduleShutdown()
    }

    private func showConfetti() {
        for screen in NSScreen.screens {
            let bounds = CGRect(origin: .zero, size: screen.frame.size)
            let window = OverlayWindow(screen: screen)
            let view = ConfettiView(frame: bounds)
            window.contentView = view

            let emitter = ConfettiEmitter.makeLayer(
                screenSize: bounds.size,
                colors: config.colors,
                density: config.density
            )
            emitter.frame = bounds
            view.addEmitter(emitter)
            window.orderFrontRegardless()
            windows.append(window)

            ConfettiEmitter.stopEmission(layer: emitter, after: config.duration)
        }
    }

    private func showPulse() {
        let color = config.colors.first ?? .white
        for screen in NSScreen.screens {
            let bounds = CGRect(origin: .zero, size: screen.frame.size)
            let window = OverlayWindow(screen: screen)
            let view = PulseView(frame: bounds, color: color)
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
            view.animate(duration: config.duration) { [weak self] in
                self?.tearDownOverlay()
            }
        }
    }

    private func scheduleShutdown() {
        let visualDuration: Double
        switch config.effect {
        case .confetti:
            visualDuration = config.duration
        case .pulse:
            visualDuration = config.duration
        case .none:
            visualDuration = 0.5
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + visualDuration) { [weak self] in
            self?.tearDownOverlay()
        }

        let deadline = config.url != nil ? visualDuration + 30 : visualDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + deadline) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func tearDownOverlay() {
        for window in windows {
            window.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
