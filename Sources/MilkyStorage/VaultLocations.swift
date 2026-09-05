import Foundation

/// Where a vault lives, and how it syncs. All three cloud options are just folders
/// the OS or a helper app keeps in sync, so the app treats them identically.
public enum VaultKind: String, Sendable {
    case local, iCloud, dropbox, git

    public var label: String {
        switch self {
        case .local: return "On My Mac"
        case .iCloud: return "iCloud Drive"
        case .dropbox: return "Dropbox"
        case .git: return "Git Repository"
        }
    }

    public var symbol: String {
        switch self {
        case .local: return "internaldrive"
        case .iCloud: return "icloud"
        case .dropbox: return "shippingbox"
        case .git: return "arrow.triangle.branch"
        }
    }
}

public enum VaultLocations {
    public static var iCloudDrive: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Mobile Documents/com~apple~CloudDocs")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public static var dropbox: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for candidate in ["Dropbox", "Library/CloudStorage/Dropbox"] {
            let url = home.appending(path: candidate)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    /// Infers how a folder syncs from where it sits, so the UI can say so without asking.
    public static func kind(of url: URL) -> VaultKind {
        let path = url.standardizedFileURL.path
        if FileManager.default.fileExists(atPath: url.appending(path: ".git").path) { return .git }
        if path.contains("com~apple~CloudDocs") || path.contains("Mobile Documents") { return .iCloud }
        if path.contains("/Dropbox") { return .dropbox }
        return .local
    }
}

/// Remembers recently opened vaults across launches. Bookmarks survive the folder
/// being moved or renamed, which plain paths do not.
public enum VaultBookmarks {
    private static let key = "com.oddurs.milky.recentVaults"
    private static let lastKey = "com.oddurs.milky.lastVault"

    public static func remember(_ url: URL) {
        guard let data = try? url.bookmarkData(options: [.withSecurityScope],
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
                ?? url.bookmarkData() else { return }
        var all = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
        all.removeAll { resolve($0)?.standardizedFileURL == url.standardizedFileURL }
        all.insert(data, at: 0)
        UserDefaults.standard.set(Array(all.prefix(10)), forKey: key)
        UserDefaults.standard.set(data, forKey: lastKey)
    }

    public static func recents() -> [URL] {
        let all = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
        return all.compactMap(resolve)
    }

    public static func last() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: lastKey) else { return nil }
        return resolve(data)
    }

    public static func forget() {
        UserDefaults.standard.removeObject(forKey: lastKey)
    }

    private static func resolve(_ data: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale)
                ?? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
