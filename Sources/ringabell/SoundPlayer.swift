import AppKit

@MainActor
enum SoundPlayer {
    private static var currentSound: NSSound?

    static func play(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            fputs("ringabell: unknown sound '\(name)'\n", stderr)
            return
        }
        currentSound = sound
        sound.play()
    }
}
