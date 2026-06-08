import Foundation

/// Manages the short postlude clips bundled inside the app. Clips live in
/// `Resources/Postludes/` and are played in a simple rotation: each time the
/// postlude is selected anew, the library advances to the next clip.
@MainActor
final class PostludeLibrary {
    private let clips: [URL]
    private var index = 0

    /// Audio extensions we'll accept for bundled postlude clips.
    private static let audioExtensions = ["mp3", "m4a", "wav", "caf", "aif", "aiff"]

    init(bundle: Bundle = .main) {
        var found: [URL] = []
        for ext in Self.audioExtensions {
            found += bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
        }
        // Stable, predictable rotation order.
        clips = found.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        // Start one before the first clip so the first `advance()` lands on clip 0.
        index = clips.isEmpty ? 0 : clips.count - 1
    }

    var hasClips: Bool { !clips.isEmpty }
    var count: Int { clips.count }

    /// The clip currently queued for the postlude (does not advance).
    var current: URL? {
        guard !clips.isEmpty else { return nil }
        return clips[index % clips.count]
    }

    /// Advance to the next clip in rotation and return it.
    @discardableResult
    func advance() -> URL? {
        guard !clips.isEmpty else { return nil }
        index = (index + 1) % clips.count
        return current
    }
}
