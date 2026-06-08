import Foundation
import AVFoundation
import Observation

/// Plays hymns through the device speaker. Handles both a single rendition and an
/// ordered queue (the prelude: three piano hymns back to back).
///
/// Uses `AVQueuePlayer` for everything — a single hymn is just a one-item queue —
/// so sequential prelude playback and single playback share one code path.
@MainActor
@Observable
final class AudioController {
    private(set) var isPlaying = false
    /// True while the current selection has audio loaded and ready to play.
    private(set) var hasLoadedItem = false

    /// Total runtime of the whole loaded selection (all queued items).
    private(set) var totalDuration: TimeInterval = 0
    /// Time left until the whole loaded selection finishes (spans the full queue).
    private(set) var remaining: TimeInterval = 0
    /// True once per-item durations have loaded and `remaining` is meaningful.
    private(set) var hasTiming = false

    /// App playback volume, 0...1 (relative to system volume). Bind directly.
    var volume: Double = 1.0 {
        didSet { player.volume = Float(min(1, max(0, volume))) }
    }

    /// Time played so far across the whole loaded selection.
    var elapsed: TimeInterval { max(0, totalDuration - remaining) }
    /// Fraction played, 0...1.
    var progress: Double { totalDuration > 0 ? min(1, max(0, elapsed / totalDuration)) : 0 }

    @ObservationIgnored private let player = AVQueuePlayer()
    @ObservationIgnored private var currentURLs: [URL] = []
    @ObservationIgnored private var itemDurations: [TimeInterval] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    init() {
        configureSession()
        player.actionAtItemEnd = .advance
        player.volume = Float(volume)
        addPeriodicObserver()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // .playback so audio plays through the mute switch and continues in the background.
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func addPeriodicObserver() {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.isPlaying = (self.player.timeControlStatus == .playing)
            self.recomputeRemaining()
        }
    }

    /// Recompute time left across the *whole* queue: durations of the items still
    /// queued (current + upcoming) minus how far into the current item we are.
    private func recomputeRemaining() {
        guard hasTiming, !itemDurations.isEmpty else { return }
        let remainingCount = player.items().count
        let total = itemDurations.count
        let startIndex = max(0, total - remainingCount)
        var rem = itemDurations[startIndex...].reduce(0, +)
        if let elapsed = player.currentItem?.currentTime(), elapsed.isNumeric {
            rem -= CMTimeGetSeconds(elapsed)
        }
        remaining = max(0, rem)
    }

    /// Load an ordered set of local file URLs, ready to play. Does not start playback.
    func load(urls: [URL]) {
        currentURLs = urls
        rebuildQueue()
        hasLoadedItem = !urls.isEmpty
        isPlaying = false
        // Reset timing; resolve per-item durations asynchronously, then publish.
        itemDurations = []
        totalDuration = 0
        remaining = 0
        hasTiming = false
        guard !urls.isEmpty else { return }
        Task {
            let durations = await Self.durations(of: urls)
            // Ignore if a newer selection was loaded in the meantime.
            guard urls == self.currentURLs else { return }
            self.itemDurations = durations
            self.totalDuration = durations.reduce(0, +)
            self.hasTiming = true
            self.recomputeRemaining()
        }
    }

    private func rebuildQueue() {
        player.pause()
        player.removeAllItems()
        for url in currentURLs {
            player.insert(AVPlayerItem(url: url), after: nil)
        }
        observeEndOfLastItem()
    }

    private func observeEndOfLastItem() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        guard let lastItem = player.items().last else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: lastItem, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
    }

    func play() {
        guard hasLoadedItem else { return }
        // If the queue has drained (finished), rebuild before playing again.
        if player.items().isEmpty { rebuildQueue() }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Reset to the very beginning of the (first) item and STOP — does not play.
    func restart() {
        player.pause()
        rebuildQueue()
        player.seek(to: .zero)
        isPlaying = false
        recomputeRemaining()
    }

    func stop() {
        player.pause()
        player.removeAllItems()
        currentURLs = []
        itemDurations = []
        hasLoadedItem = false
        isPlaying = false
        hasTiming = false
        totalDuration = 0
        remaining = 0
    }

    /// Durations (seconds) of an ordered set of local files, in order.
    nonisolated static func durations(of urls: [URL]) async -> [TimeInterval] {
        var result: [TimeInterval] = []
        for url in urls {
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                result.append(CMTimeGetSeconds(duration))
            } else {
                result.append(0)
            }
        }
        return result
    }

    /// Total duration of an ordered set of local files (used for the prelude total).
    nonisolated static func totalDuration(of urls: [URL]) async -> TimeInterval {
        await durations(of: urls).reduce(0, +)
    }
}
