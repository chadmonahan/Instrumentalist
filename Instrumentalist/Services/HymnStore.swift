import Foundation
import Observation

/// Download state for a single hymn rendition, keyed by file name.
enum DownloadState: Equatable {
    case notCached
    case downloading
    case ready
    case failed
}

/// Downloads hymn renditions from Azure and caches them **permanently** on disk
/// so they play offline once fetched.
///
/// Files are stored in Application Support (not Caches) so the OS won't purge them.
/// The cache key is the blob file name (e.g. `chior356-1.mp3`), which is identical
/// locally and remotely.
@MainActor
@Observable
final class HymnStore {
    /// Per-file download state, keyed by file name.
    private(set) var states: [String: DownloadState] = [:]

    private let directory: URL
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Hymns", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        primeStatesFromDisk()
    }

    /// Mark anything already on disk as `.ready` at launch.
    private func primeStatesFromDisk() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "mp3" {
            states[url.lastPathComponent] = .ready
        }
    }

    func state(for hymn: Hymn) -> DownloadState {
        states[hymn.fileName] ?? .notCached
    }

    /// Local file URL for a hymn, if it's been downloaded.
    func localURL(for hymn: Hymn) -> URL? {
        let url = directory.appendingPathComponent(hymn.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func fileURL(for hymn: Hymn) -> URL {
        directory.appendingPathComponent(hymn.fileName)
    }

    /// Ensure a hymn is cached locally, downloading if needed. Returns the local URL,
    /// or throws on failure. Safe to call repeatedly — a cache hit returns immediately.
    @discardableResult
    func ensureCached(_ hymn: Hymn) async throws -> URL {
        if let local = localURL(for: hymn) {
            states[hymn.fileName] = .ready
            return local
        }

        states[hymn.fileName] = .downloading
        do {
            let (tempURL, response) = try await session.download(from: hymn.remoteURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let dest = fileURL(for: hymn)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            states[hymn.fileName] = .ready
            return dest
        } catch {
            states[hymn.fileName] = .failed
            throw error
        }
    }

    /// Kick off caching without awaiting the result (fire-and-forget prefetch).
    func prefetch(_ hymn: Hymn) {
        guard state(for: hymn) != .ready, state(for: hymn) != .downloading else { return }
        Task { try? await ensureCached(hymn) }
    }
}
