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

    @ObservationIgnored private let player = AVQueuePlayer()
    @ObservationIgnored private var currentURLs: [URL] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    init() {
        configureSession()
        player.actionAtItemEnd = .advance
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
        }
    }

    /// Load an ordered set of local file URLs, ready to play. Does not start playback.
    func load(urls: [URL]) {
        currentURLs = urls
        rebuildQueue()
        hasLoadedItem = !urls.isEmpty
        isPlaying = false
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

    /// Restart from the very beginning of the (first) item.
    func restart() {
        rebuildQueue()
        player.seek(to: .zero)
        player.play()
    }

    func stop() {
        player.pause()
        player.removeAllItems()
        currentURLs = []
        hasLoadedItem = false
        isPlaying = false
    }

    /// Total duration of an ordered set of local files (used for the prelude total).
    nonisolated static func totalDuration(of urls: [URL]) async -> TimeInterval {
        var total: TimeInterval = 0
        for url in urls {
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                total += CMTimeGetSeconds(duration)
            }
        }
        return total
    }
}
