import Foundation
import Observation

/// Manages the short postlude clips bundled inside the app. Clips live in
/// `Resources/Postludes/` and play in a simple rotation: each time the postlude
/// is freshly selected, the library advances to the next clip.
///
/// Clip files are named like `hdhymn215-post.mp3`; the embedded number is the
/// hymn number, surfaced as `currentNumber` for display.
@MainActor
@Observable
final class PostludeLibrary {
    @ObservationIgnored private let clips: [URL]
    /// Index of the clip currently queued / loaded.
    private var index = 0
    /// Becomes true after the first selection so we only advance on *subsequent* ones.
    private var primed = false

    /// Audio extensions we'll accept for bundled postlude clips.
    private static let audioExtensions = ["mp3", "m4a", "wav", "caf", "aif", "aiff"]

    init(bundle: Bundle = .main) {
        var found: [URL] = []
        for ext in Self.audioExtensions {
            found += bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
        }
        // Stable, predictable rotation order (natural sort: hdhymn80 < hdhymn215).
        clips = found.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    var hasClips: Bool { !clips.isEmpty }
    var count: Int { clips.count }

    /// The clip currently queued for the postlude (does not advance).
    var current: URL? {
        guard !clips.isEmpty else { return nil }
        return clips[index % clips.count]
    }

    /// Hymn number parsed from the current clip's filename, e.g. 215 from
    /// `hdhymn215-post.mp3`. Nil if the name has no number.
    var currentNumber: Int? { Self.number(from: current) }

    /// Queue the next clip for playback and return it. The first call keeps the
    /// first clip; each later call advances the rotation by one.
    @discardableResult
    func selectForPlayback() -> URL? {
        guard !clips.isEmpty else { return nil }
        if primed { index = (index + 1) % clips.count }
        primed = true
        return current
    }

    /// First contiguous run of digits in the file's base name.
    private static func number(from url: URL?) -> Int? {
        guard let stem = url?.deletingPathExtension().lastPathComponent else { return nil }
        var digits = ""
        for ch in stem {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}
