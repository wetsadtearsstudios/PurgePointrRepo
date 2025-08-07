import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var useSecureErase: Bool {
        didSet {
            UserDefaults.standard.set(useSecureErase, forKey: "useSecureErase")
            print("🔧 useSecureErase updated: \(useSecureErase)")
        }
    }

    @Published var leaveSafetyBuffer: Bool {
        didSet {
            UserDefaults.standard.set(leaveSafetyBuffer, forKey: "leaveSafetyBuffer")
            print("🔧 leaveSafetyBuffer updated: \(leaveSafetyBuffer)")
        }
    }

    @Published var testMode: Bool {
        didSet {
            UserDefaults.standard.set(testMode, forKey: "testMode")
            print("🔧 testMode updated: \(testMode)")
        }
    }

    @Published var selectedVolumes: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedVolumes), forKey: "selectedVolumes")
            print("🗂️ selectedVolumes updated: \(selectedVolumes)")
        }
    }

    private let bookmarksKey = "volumeBookmarks"
    private(set) var volumeBookmarks: [URL: Data] = [:]

    var resolvedVolumePaths: Set<String> {
        var resolved: Set<String> = []

        for (url, data) in volumeBookmarks {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                var isDir: ObjCBool = false
                let pathExists = FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDir)

                if pathExists && isDir.boolValue && resolvedURL.startAccessingSecurityScopedResource() {
                    let path = resolvedURL.path

                    if path == "/System/Volumes/Data" {
                        print("✅ Accessed scoped resource: / (mapped from /System/Volumes/Data)")
                        resolved.insert("/")
                    } else {
                        print("✅ Accessed scoped resource: \(path)")
                        resolved.insert(path)
                    }
                } else {
                    print("❌ Failed to resolve or access: \(resolvedURL.path)")
                }
            } catch {
                print("❌ Failed to resolve bookmark for \(url): \(error)")
            }
        }

        print("📍 Resolved volume paths: \(resolved)")
        return resolved
    }

    func saveVolumeBookmarks(_ urls: [URL]) {
        // Replace '/' with '/System/Volumes/Data' so we can write to it
        let filtered = urls.map { $0.path == "/" ? URL(fileURLWithPath: "/System/Volumes/Data") : $0 }
        print("💾 Saving volume bookmarks for: \(filtered.map(\.path))")

        for url in filtered {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                volumeBookmarks[url] = bookmarkData
                print("✅ Created bookmark for \(url.path)")
            } catch {
                print("❌ Failed to create bookmark for \(url): \(error)")
            }
        }

        do {
            let dictionary = volumeBookmarks.reduce(into: [String: Data]()) { result, pair in
                result[pair.key.absoluteString] = pair.value
            }
            let encoded = try PropertyListEncoder().encode(dictionary)
            UserDefaults.standard.set(encoded, forKey: bookmarksKey)
            print("💾 Bookmarks saved to UserDefaults.")
        } catch {
            print("❌ Failed to encode and save volume bookmarks: \(error)")
        }
    }

    func loadVolumeBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else {
            print("📂 No stored volume bookmarks found.")
            return
        }

        do {
            let decoded = try PropertyListDecoder().decode([String: Data].self, from: data)
            volumeBookmarks = decoded.reduce(into: [:]) {
                if let url = URL(string: $1.key) {
                    $0[url] = $1.value
                }
            }
            print("📂 Loaded volume bookmarks: \(volumeBookmarks.keys.map(\.path))")
        } catch {
            print("❌ Failed to decode volume bookmarks: \(error)")
        }
    }

    func clearVolumeBookmarks() {
        print("🧹 Clearing existing bookmarks")
        volumeBookmarks.removeAll()
        UserDefaults.standard.removeObject(forKey: bookmarksKey)
    }

    private init() {
        self.useSecureErase = UserDefaults.standard.bool(forKey: "useSecureErase")
        self.leaveSafetyBuffer = UserDefaults.standard.bool(forKey: "leaveSafetyBuffer")
        self.testMode = UserDefaults.standard.bool(forKey: "testMode")

        if let savedVolumes = UserDefaults.standard.array(forKey: "selectedVolumes") as? [String] {
            self.selectedVolumes = Set(savedVolumes)
            print("📁 Loaded selectedVolumes: \(savedVolumes)")
        } else {
            self.selectedVolumes = []
            print("📁 No selectedVolumes found.")
        }

        loadVolumeBookmarks()
    }
}
