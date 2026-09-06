import Foundation

/// Watches the vault directory tree so edits made by Dropbox, iCloud, `git pull`,
/// or another device show up without the user doing anything.
public final class VaultWatcher {
    private var stream: FSEventStreamRef?
    private let root: URL
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.oddurs.milky.watcher")
    private var debounce: DispatchWorkItem?

    public init(root: URL, onChange: @escaping () -> Void) {
        self.root = root
        self.onChange = onChange
    }

    public func start() {
        stop()
        let info = Unmanaged.passUnretained(self).toOpaque()
        var context = FSEventStreamContext(version: 0, info: info, retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<VaultWatcher>.fromOpaque(info).takeUnretainedValue()
            let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            guard VaultWatcher.isVaultChange(in: changed) else { return }
            _ = count
            watcher.scheduleNotification()
        }
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [root.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.4,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
                                     | kFSEventStreamCreateFlagNoDefer
                                     | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// True when at least one path is something a vault cares about.
    ///
    /// The stream watches the vault root, so it also sees every `.git/index`
    /// write. Without this, a sync fires the debounce, which rebuilds the whole
    /// index — reading every file — while git is still working.
    public static func isVaultChange(in paths: [String]) -> Bool {
        paths.contains { path in
            !path.split(separator: "/").contains { Vault.ignoredDirectories.contains(String($0)) }
        }
    }

    /// A save or a sync lands as a burst of events; collapse them into one reload.
    private func scheduleNotification() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { self.onChange() }
        }
        debounce = work
        queue.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    deinit { stop() }
}
