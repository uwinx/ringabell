import ArgumentParser
import AppKit

@main
struct RingABell: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ringabell",
        abstract: "Splash confetti on screen with sound and notification",
        version: "1.0.0"
    )

    @Option(help: "Notification body text")
    var message: String = "Ring a bell!"

    @Option(help: "System sound name (Glass, Hero, Ping, etc.)")
    var sound: String = "Glass"

    @Option(help: "Comma-separated color names or #hex values")
    var colors: String = ConfettiConfig.defaultColors

    @Option(help: "Seconds before auto-dismiss (0.5–30)")
    var duration: Double = 3.5

    @Option(help: "Particle birthRate multiplier (0.1–5.0)")
    var density: Double = 1.0

    @Option(help: "URL/deeplink to open when notification is clicked")
    var url: String? = nil

    @Flag(help: "Skip macOS notification")
    var noNotification: Bool = false

    func validate() throws {
        guard (0.5...30).contains(duration) else {
            throw ValidationError("--duration must be between 0.5 and 30 seconds")
        }
        guard (0.1...5.0).contains(density) else {
            throw ValidationError("--density must be between 0.1 and 5.0")
        }
    }

    func run() throws {
        var parsedColors = ConfettiConfig.parseColors(colors)
        if parsedColors.isEmpty {
            fputs("ringabell: no valid colors in '\(colors)', using defaults\n", stderr)
            parsedColors = ConfettiConfig.parseColors(ConfettiConfig.defaultColors)
        }

        let config = ConfettiConfig(
            message: message,
            soundName: sound,
            colors: parsedColors,
            duration: duration,
            density: density,
            showNotification: !noNotification,
            url: url
        )

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate(config: config)
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
