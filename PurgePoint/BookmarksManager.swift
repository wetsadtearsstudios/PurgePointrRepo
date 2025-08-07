import Foundation

class BookmarksManager {
    static let shared = BookmarksManager()
    private let key = "BookmarkStorage"
    private var rawBookmarks = [URL: Data]()

    private init() {
        load()
    }

    func save(urls: [URL]) {
        for url in urls {
            do {
                let data = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                rawBookmarks[url] = data
            } catch {
                print("❌ Could not create bookmark for \(url): \(error)")
            }
        }
        do {
            let dict = rawBookmarks.reduce(into: [String: Data]()) { result, pair in
                result[pair.key.absoluteString] = pair.value
            }
            let encoded = try PropertyListEncoder().encode(dict)
            UserDefaults.standard.set(encoded, forKey: key)
        } catch {
            print("❌ Failed storing bookmarks: \(error)")
        }
    }

    func storedBookmarkURLs() -> [URL] {
        return rawBookmarks.compactMap { (url, data) in
            var isStale = false
            do {
                let resolved = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return resolved
            } catch {
                print("❌ Failed to resolve bookmark for \(url): \(error)")
                return nil
            }
        }
    }

    func resolvedVolumePaths() -> Set<String> {
        var paths = Set<String>()

        for (url, data) in rawBookmarks {
            var isStale = false
            do {
                let resolved = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if resolved.startAccessingSecurityScopedResource() {
                    paths.insert(resolved.path)
                } else {
                    print("🔒 Could not access security scope for \(resolved.path)")
                }
            } catch {
                print("❌ Failed to resolve bookmark: \(error)")
            }
        }

        return paths
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            let decoded = try PropertyListDecoder().decode([String: Data].self, from: data)
            rawBookmarks = decoded.reduce(into: [URL: Data]()) { result, pair in
                if let url = URL(string: pair.key) {
                    result[url] = pair.value
                }
            }
        } catch {
            print("❌ Failed to load bookmarks: \(error)")
        }
    }
}
