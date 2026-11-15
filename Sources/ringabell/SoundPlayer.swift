import AppKit

@MainActor
enum SoundPlayer {
    private static var currentSound: NSSound?

    // Same directories NSSound(named:) searches.
    private nonisolated static let searchDirectories = [
        NSString(string: "~/Library/Sounds").expandingTildeInPath,
        "/Library/Sounds",
        "/System/Library/Sounds",
    ]
    private nonisolated static let audioExtensions: Set<String> = ["aiff", "aif", "wav", "caf", "mp3", "m4a"]

    static func play(named name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            fputs("ringabell: unknown sound '\(name)', see --list-sounds\n", stderr)
            return
        }
        currentSound = sound
        sound.play()
    }

    nonisolated static func availableSounds() -> [String] {
        let names = searchDirectories.flatMap { dir -> [String] in
            let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            return files
                .filter { audioExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .map { ($0 as NSString).deletingPathExtension }
        }
        return Set(names).sorted()
    }
}
