import Foundation
import Observation

/// Visual state of a slot or play button, mapped to a color in `Theme`.
enum ControlState {
    case unset       // red    — nothing assigned / error
    case editing     // yellow — being edited on the pad
    case downloading // yellow — fetching audio
    case ready       // green  — assigned and playable
    case disabled    // gray   — not available yet (e.g. prelude with no queued hymns)
}

/// The single source of truth for the whole screen. Owns the services and derives
/// everything the views render. There are no "modes": tapping a slot or keying a
/// number simply changes the current selection.
@MainActor
@Observable
final class AppModel {
    let store: HymnStore
    let audio: AudioController
    let postlude: PostludeLibrary

    /// nil = "Play Now" (a free, keyed-in hymn). Otherwise a service slot is current.
    private(set) var activeSlot: ServiceSlot?

    /// Digits typed on the pad since the last commit/selection.
    private(set) var padBuffer: String = ""

    /// Committed hymn numbers for the three programmable slots.
    private(set) var slotNumbers: [ServiceSlot: Int] = [:]

    /// Rendition chosen for a Play Now hymn (piano vs choir toggle).
    private(set) var playNowType: HymnType = .piano

    /// Selected version (1 or 2) for hymns that have a second rendition.
    private(set) var selectedVersion: Int = 1

    init() {
        self.store = HymnStore()
        self.audio = AudioController()
        self.postlude = PostludeLibrary()
    }

    // MARK: - Derived display

    /// The large number shown above the pad, or nil if nothing is selected.
    var displayedNumber: Int? {
        if let n = Int(padBuffer) { return n }
        if let slot = activeSlot {
            if slot == .postlude { return postlude.currentNumber }
            if slot.isProgrammable { return slotNumbers[slot] }
        }
        return nil
    }

    /// True when the user is editing a programmable slot (typed but not yet "Set").
    var isEditingSlot: Bool {
        guard let slot = activeSlot, slot.isProgrammable else { return false }
        return !padBuffer.isEmpty
    }

    /// Show the 1 / 2 version toggle only for Play Now hymns that have a v2.
    var showsVersionToggle: Bool {
        activeSlot == nil && (displayedNumber.map(HymnCatalog.hasSecondVersion) ?? false)
    }

    /// Show the Piano / Choir toggle only in Play Now.
    var showsTypeToggle: Bool { activeSlot == nil }

    var isPlayNow: Bool { activeSlot == nil }

    // MARK: - Pad input

    func keyDigit(_ d: Int) {
        // Typing while a non-numeric slot (prelude/postlude) is active starts a fresh Play Now.
        if let slot = activeSlot, !slot.isProgrammable {
            activeSlot = nil
        }
        guard padBuffer.count < 3 else { return }
        if padBuffer.isEmpty && d == 0 { return } // no leading zero
        padBuffer.append(String(d))
        selectedVersion = 1
        if activeSlot == nil { loadCurrent() } // keep Play Now ready to play
    }

    func backspace() {
        guard !padBuffer.isEmpty else { return }
        padBuffer.removeLast()
        selectedVersion = 1
        if activeSlot == nil { loadCurrent() }
    }

    // MARK: - Slot selection & editing

    func selectSlot(_ slot: ServiceSlot) {
        if activeSlot == slot {
            // Re-tap confirms the edit (the slot button doubles as "Set"); with
            // nothing staged it just returns to Play Now.
            if isEditingSlot {
                commitSlot()
            } else {
                activeSlot = nil
                padBuffer = ""
                loadCurrent()
            }
            return
        }
        activeSlot = slot
        padBuffer = ""
        selectedVersion = 1
        if slot == .postlude { postlude.selectForPlayback() } // queue/advance the rotation
        loadCurrent()
    }

    /// Commit the typed number into the active programmable slot ("Set Opening").
    func commitSlot() {
        guard let slot = activeSlot, slot.isProgrammable,
              let n = Int(padBuffer), HymnCatalog.isValid(n) else { return }
        slotNumbers[slot] = n
        padBuffer = ""
        // Prefetch both renditions: choir for the slot itself, piano for the prelude.
        store.prefetch(Hymn(number: n, type: .choir))
        store.prefetch(Hymn(number: n, type: .piano))
        loadCurrent()
    }

    /// Discard a staged slot edit, reverting to the slot's committed value.
    func cancelEdit() {
        guard isEditingSlot else { return }
        padBuffer = ""
        loadCurrent()
    }

    func setPlayNowType(_ type: HymnType) {
        playNowType = type
        loadCurrent()
    }

    func setVersion(_ version: Int) {
        selectedVersion = version
        loadCurrent()
    }

    // MARK: - Transport

    func togglePlayPause() {
        if audio.isPlaying { audio.pause() } else { play() }
    }

    func play() {
        Task {
            let urls = await resolveCurrentURLs()
            guard !urls.isEmpty else { return }
            audio.load(urls: urls)
            audio.play()
        }
    }

    func restart() {
        audio.restart()
    }

    /// Load (but don't play) the current selection so play is instant and the
    /// play button reflects readiness.
    private func loadCurrent() {
        Task {
            let urls = await resolveCurrentURLs()
            audio.load(urls: urls)
        }
    }

    /// Resolve the current selection to an ordered list of local file URLs,
    /// downloading hymns as needed.
    private func resolveCurrentURLs() async -> [URL] {
        switch activeSlot {
        case .none:
            guard let n = displayedNumber, HymnCatalog.isValid(n) else { return [] }
            return await cached(Hymn(number: n, type: playNowType, version: selectedVersion))

        case .prelude:
            var urls: [URL] = []
            for slot in ServiceSlot.programmable {
                if let n = slotNumbers[slot] {
                    urls += await cached(Hymn(number: n, type: .piano))
                }
            }
            return urls

        case .postlude:
            return postlude.current.map { [$0] } ?? []

        case .some(let slot): // opening / memorial / closing
            guard let n = slotNumbers[slot] else { return [] }
            return await cached(Hymn(number: n, type: slot.mainType))
        }
    }

    /// Ensure a hymn is cached and return its URL (empty on failure).
    private func cached(_ hymn: Hymn) async -> [URL] {
        if let url = try? await store.ensureCached(hymn) { return [url] }
        return []
    }

    // MARK: - Button visual state

    func slotState(_ slot: ServiceSlot) -> ControlState {
        if slot == activeSlot && isEditingSlot { return .editing }

        switch slot {
        case .opening, .memorial, .closing:
            guard let n = slotNumbers[slot] else { return .unset }
            return renditionState(Hymn(number: n, type: .choir))

        case .prelude:
            let numbers = ServiceSlot.programmable.compactMap { slotNumbers[$0] }
            guard !numbers.isEmpty else { return .disabled }
            let states = numbers.map { store.state(for: Hymn(number: $0, type: .piano)) }
            if states.contains(.downloading) { return .downloading }
            if states.contains(.failed) { return .unset }
            return .ready

        case .postlude:
            return postlude.hasClips ? .ready : .unset
        }
    }

    /// State of the play button for the current selection.
    var playState: ControlState {
        switch activeSlot {
        case .none:
            guard let n = displayedNumber, HymnCatalog.isValid(n) else { return .unset }
            return renditionState(Hymn(number: n, type: playNowType, version: selectedVersion))
        case .prelude, .postlude:
            return slotState(activeSlot!)
        case .some(let slot):
            guard let n = slotNumbers[slot] else { return .unset }
            return renditionState(Hymn(number: n, type: slot.mainType))
        }
    }

    private func renditionState(_ hymn: Hymn) -> ControlState {
        switch store.state(for: hymn) {
        case .ready:       return .ready
        case .downloading: return .downloading
        case .failed:      return .unset
        case .notCached:   return .ready // assigned; will download on play
        }
    }
}
