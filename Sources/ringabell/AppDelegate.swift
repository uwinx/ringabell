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
        NSApplication.shared.applicationIconImage = config.icon.image()
        UNUserNotificationCenter.current().delegate = self

        let quiet = config.respectFocus && FocusStatus.isActive
        let effect = quiet ? .none : config.effect

        switch effect {
        case .confetti:
            showConfetti()
        case .pulse:
            showPulse()
        case .none:
            break
        }

        if !quiet && config.playSound {
            SoundPlayer.play(named: config.soundName)
        }

        // Still sent under Focus: macOS holds it in Notification Center.
        if config.showNotification {
            NotificationSender.send(title: config.title, subtitle: config.subtitle, body: config.message,
                                    url: config.url, icon: config.icon, buttons: config.buttons)
        }

        scheduleShutdown(effect: effect)
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

    private func scheduleShutdown(effect: Effect) {
        let visualDuration: Double
        switch effect {
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

        let hasInteraction = config.url != nil || !config.buttons.isEmpty
        let deadline = hasInteraction ? max(visualDuration, 120) : visualDuration
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
        let actionId = response.actionIdentifier

        if actionId == UNNotificationDefaultActionIdentifier,
           let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApplication.shared.terminate(nil)
                }
            }
        } else if actionId.hasPrefix("button-"),
                  let button = config.buttons.first(where: { $0.id == actionId }) {
            DispatchQueue.global(qos: .userInitiated).async { [config] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", button.action]

                let stdin = Pipe()
                process.standardInput = config.context == nil ? FileHandle.nullDevice : stdin

                guard (try? process.run()) != nil else {
                    fputs("ringabell: failed to run button action\n", stderr)
                    DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
                    return
                }

                // Write after launch and off this thread: a context larger than the pipe
                // buffer blocks until the script reads it, and a script that never reads
                // stdin must not stall waitUntilExit or kill us with SIGPIPE.
                if let data = config.context?.data(using: .utf8) {
                    signal(SIGPIPE, SIG_IGN)
                    DispatchQueue.global(qos: .userInitiated).async {
                        try? stdin.fileHandleForWriting.write(contentsOf: data)
                        try? stdin.fileHandleForWriting.close()
                    }
                }

                process.waitUntilExit()

                DispatchQueue.main.async {
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
