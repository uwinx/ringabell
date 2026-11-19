import ArgumentParser
import AppKit
import Darwin

@main
struct RingABell: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ringabell",
        abstract: "Splash confetti on screen with sound and notification",
        version: "1.8.0"
    )

    @Option(help: "Notification title")
    var title: String = "ringabell"

    @Option(help: "Notification subtitle")
    var subtitle: String = ""

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

    @Option(help: ArgumentHelp("Custom notification image (png, jpg, gif; max 10 MB). Overrides --icon", valueName: "path"))
    var iconFile: String? = nil

    @Option(help: "Visual effect (confetti, pulse, none)")
    var effect: Effect = .confetti

    @Option(help: ArgumentHelp("Screen for the visual effect: all, main, or a 0-based index", valueName: "all|main|index"))
    var screen: ScreenTarget = .all

    @Option(help: "JSON context for template interpolation and button script stdin")
    var context: String? = nil

    @Option(help: ArgumentHelp("Notification button as \"Title:shell command\" (max 4). One button shows inline; several collapse into an Options menu and hide --icon", valueName: "title:action"))
    var button: [String] = []

    @Option(help: ArgumentHelp("Also push to your phone, end-to-end encrypted. Reads PUSHOVER_TOKEN, PUSHOVER_USER, PUSHOVER_E2E_KEY from the environment or --pushover-config. With --ignore-dnd, sends emergency priority that repeats until acknowledged", valueName: "pushover"))
    var push: PushTarget? = nil

    @Option(help: ArgumentHelp("Private (chmod 600) file with PUSHOVER_TOKEN=, PUSHOVER_USER=, PUSHOVER_E2E_KEY= lines, used instead of the environment", valueName: "path"))
    var pushoverConfig: String? = nil

    @Option(help: ArgumentHelp("Pushover sound, built-in or uploaded (default: persistent with --ignore-dnd, else your Pushover default)", valueName: "name"))
    var pushSound: String? = nil

    @Flag(help: "Skip macOS notification")
    var noNotification: Bool = false

    @Flag(help: "Show effect and play sound even when Do Not Disturb / Focus is on")
    var ignoreDnd: Bool = false

    @Flag(help: "Skip system sound")
    var noSound: Bool = false

    @Flag(help: "List available system sounds and exit")
    var listSounds: Bool = false

    func validate() throws {
        guard (0.5...30).contains(duration) else {
            throw ValidationError("--duration must be between 0.5 and 30 seconds")
        }
        guard (0.1...5.0).contains(density) else {
            throw ValidationError("--density must be between 0.1 and 5.0")
        }
        guard button.count <= 4 else {
            throw ValidationError("maximum 4 buttons allowed (macOS limitation)")
        }
        for b in button {
            guard b.split(separator: ":", maxSplits: 1).count == 2 else {
                throw ValidationError("invalid button format '\(b)', expected \"Title:action\"")
            }
        }
        if let url {
            guard URL(string: url)?.scheme != nil else {
                throw ValidationError("--url '\(url)' is not a URL with a scheme (e.g. https://, slack://)")
            }
        }
        if let url = iconFileURL {
            guard NotificationIcon.fileExtensions.contains(url.pathExtension.lowercased()) else {
                throw ValidationError("--icon-file must be a png, jpg or gif image")
            }
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  size.isRegularFile == true else {
                throw ValidationError("--icon-file '\(url.path)' does not exist")
            }
            // UNNotificationAttachment rejects images over 10 MB.
            guard (size.fileSize ?? 0) <= 10_000_000 else {
                throw ValidationError("--icon-file must be at most 10 MB")
            }
        }
        if (pushoverConfig != nil || pushSound != nil) && push != .pushover {
            throw ValidationError("--pushover-config and --push-sound need --push pushover")
        }
        _ = try loadPush()
    }

    private func loadPush() throws -> PushoverConfig? {
        switch push {
        case .pushover:
            let file = pushoverConfig.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
            return try PushoverConfig.load(file: file, emergency: ignoreDnd, sound: pushSound)
        case nil:
            return nil
        }
    }

    private var iconFileURL: URL? {
        iconFile.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath).standardizedFileURL }
    }

    // Re-exec with clean environment to work around SIGBUS caused by
    // terminal emulators (e.g. Alacritty + zsh) on Apple Silicon.
    static func main() {
        if getenv("_RINGABELL") == nil {
            let pass = ["HOME", "PATH", "TMPDIR", "USER", "LOGNAME", "SHELL",
                        "SSH_AUTH_SOCK", "LANG", "LC_ALL", "LC_CTYPE", "TERM"] + PushoverConfig.environmentVars
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
        if listSounds {
            SoundPlayer.availableSounds().forEach { print($0) }
            throw ExitCode.success
        }

        var parsedColors = ConfettiConfig.parseColors(colors)
        if parsedColors.isEmpty {
            fputs("ringabell: no valid colors in '\(colors)', using defaults\n", stderr)
            parsedColors = ConfettiConfig.parseColors(ConfettiConfig.defaultColors)
        }

        let buttons = button.enumerated().map { index, spec -> NotificationButton in
            let parts = spec.split(separator: ":", maxSplits: 1)
            let title = ConfettiConfig.templateReplace(String(parts[0]), context: context)
            return NotificationButton(id: "button-\(index)", title: title, action: String(parts[1]))
        }

        let config = ConfettiConfig(
            title: ConfettiConfig.templateReplace(title, context: context),
            subtitle: ConfettiConfig.templateReplace(subtitle, context: context),
            message: ConfettiConfig.templateReplace(message, context: context),
            soundName: sound,
            colors: parsedColors,
            duration: duration,
            density: density,
            effect: effect,
            screen: screen,
            playSound: !noSound,
            showNotification: !noNotification,
            respectFocus: !ignoreDnd,
            url: url,
            icon: iconFileURL.map(NotificationIcon.file) ?? .emoji(icon),
            context: context,
            buttons: buttons,
            push: try loadPush()
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
