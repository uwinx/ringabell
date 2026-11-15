import Foundation

enum FocusStatus {
    private static let assertionsPath = "Library/DoNotDisturb/DB/Assertions.json"

    // The public API (INFocusStatusCenter) needs an entitlement an ad-hoc signed
    // binary can't carry, so read the Focus daemon's state file instead.
    // An unreadable file (no Full Disk Access) counts as Focus off.
    static var isActive: Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(assertionsPath)
        guard let data = try? Data(contentsOf: url) else { return false }
        return hasActiveAssertion(data)
    }

    static func hasActiveAssertion(_ data: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stores = root["data"] as? [[String: Any]]
        else { return false }
        return stores.contains { store in
            !((store["storeAssertionRecords"] as? [Any]) ?? []).isEmpty
        }
    }
}
