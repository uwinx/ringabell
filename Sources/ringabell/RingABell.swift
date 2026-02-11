import ArgumentParser
import AppKit
import Darwin

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

    @Option(help: "Notification icon (party, bell, sparkles, confetti, checkmark, star, rocket, fire)")
    var icon: AppIcon = .party

    @Option(help: "Visual effect (confetti, pulse, none)")
    var effect: Effect = .confetti

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

    // Re-exec with clean environment to work around SIGBUS caused by
    // terminal emulators (e.g. Alacritty + zsh) on Apple Silicon.
    static func main() {
        if getenv("_RINGABELL") == nil {
            let pass = ["HOME", "PATH", "TMPDIR", "USER", "LOGNAME", "SHELL",
                        "SSH_AUTH_SOCK", "LANG", "LC_ALL", "LC_CTYPE", "TERM"]
            var env = pass.compactMap { k -> String? in
                guard let v = getenv(k) else { return nil }
                return "\(k)=\(String(cString: v))"
            }
            env.append("_RINGABELL=1")

            var pathBuf = [CChar](repeating: 0, count: Int(PATH_MAX))
            var size = UInt32(PATH_MAX)
            _NSGetExecutablePath(&pathBuf, &size)

            var args: [UnsafeMutablePointer<CChar>?] =
                (0..<Int(CommandLine.argc)).map { CommandLine.unsafeArgv[$0] }
            args.append(nil)

            var envp: [UnsafeMutablePointer<CChar>?] = env.map { strdup($0) }
            envp.append(nil)

            execve(pathBuf, &args, &envp)
            _exit(1)
        }

        Self.main(nil)
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
            effect: effect,
            showNotification: !noNotification,
            url: url,
            icon: icon
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
