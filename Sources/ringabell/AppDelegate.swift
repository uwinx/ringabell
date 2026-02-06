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
        showConfetti()
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

    private func scheduleShutdown() {
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) { [weak self] in
            self?.tearDownOverlay()
        }

        let deadline = config.url != nil ? config.duration + 30 : config.duration
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
