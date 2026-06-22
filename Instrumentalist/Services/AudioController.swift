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

    /// Index of the item currently sounding within the loaded queue (0-based).
    /// For a single hymn this is always 0; for the prelude medley it advances
    /// 0 → 1 → 2 as each hymn plays, so the UI can show the current hymn number.
    private(set) var currentItemIndex = 0

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

    /// Name of the current audio output (e.g. "USB Audio", "Speaker").
    private(set) var outputRouteName: String = "—"
    /// True when audio is routed to an external output (USB / HDMI / headphones /
    /// Bluetooth) rather than the iPad's built-in speaker — i.e. it's reaching the PA.
    private(set) var isExternalOutput: Bool = false

    /// Called when the whole loaded selection plays through to the end.
    @ObservationIgnored var onFinished: (() -> Void)?

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
        observeAudioSession()
        updateRoute()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // .playback so audio plays through the mute switch and continues in the
        // background. The system auto-routes to a connected USB-C audio device
        // (USB output outranks the built-in speaker), so output reaches the PA
        // with no extra configuration.
        try? session.setCategory(.playback, mode: .default)
        // Activating the session can stall briefly while CoreAudio brings up the
        // route, so keep it off the launch/first-frame path. It's also activated
        // on demand right before playback (see `activateSession`).
        DispatchQueue.main.async { [weak self] in self?.activateSession() }
    }

    /// Ensure the audio session is active. Idempotent and cheap when already on.
    private func activateSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Output routing (USB-C / PA)

    private func observeAudioSession() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateRoute() }
        }
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
    }

    /// Refresh the published output-route info after a route change.
    private func updateRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        guard let output = route.outputs.first else {
            outputRouteName = "None"
            isExternalOutput = false
            return
        }
        outputRouteName = output.portName
        let builtIn: Set<AVAudioSession.Port> = [.builtInSpeaker, .builtInReceiver]
        isExternalOutput = !builtIn.contains(output.portType)
    }

    /// Pause on interruption (Siri, calls); resume only if the system says we may.
    /// If the adapter is unplugged mid-playback iOS pauses automatically — we do
    /// NOT auto-resume onto the iPad speaker, so a hymn never blasts out the
    /// tablet by accident.
    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            isPlaying = false
        case .ended:
            try? AVAudioSession.sharedInstance().setActive(true)
            if let optRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume) {
                player.play()
            }
        @unknown default:
            break
        }
    }

    private func addPeriodicObserver() {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.isPlaying = (self.player.timeControlStatus == .playing)
            self.currentItemIndex = max(0, self.currentURLs.count - self.player.items().count)
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
        currentItemIndex = 0
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
            Task { @MainActor in
                self?.isPlaying = false
                self?.onFinished?()
            }
        }
    }

    func play() {
        guard hasLoadedItem else { return }
        activateSession()
        // If the queue has drained (finished), rebuild before playing again.
        if player.items().isEmpty { rebuildQueue() }
        player.play()
    }

    /// Play the loaded selection starting `offset` seconds in, trimming whole
    /// leading items and seeking into the one that straddles the offset. Used to
    /// start a late prelude so it still finishes on time. Falls back to a normal
    /// start if there's no per-item timing yet or nothing to trim.
    func play(skipping offset: TimeInterval) {
        guard hasLoadedItem else { return }
        guard hasTiming, offset > 0 else { play(); return }
        activateSession()
        var into = offset
        var startIndex = 0
        while startIndex < itemDurations.count && into >= itemDurations[startIndex] {
            into -= itemDurations[startIndex]
            startIndex += 1
        }
        guard startIndex < currentURLs.count else { return } // skipped past the end
        player.pause()
        player.removeAllItems()
        for url in currentURLs[startIndex...] {
            player.insert(AVPlayerItem(url: url), after: nil)
        }
        observeEndOfLastItem()
        player.seek(to: CMTime(seconds: into, preferredTimescale: 600)) { [weak self] _ in
            self?.player.play()
        }
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
