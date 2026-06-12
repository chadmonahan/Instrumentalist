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

    /// Chosen tune version (1 or 2) per programmable slot. Defaults to 1.
    private(set) var slotVersions: [ServiceSlot: Int] = [:]

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

    /// Show the 1st / 2nd "second tune" toggle whenever the displayed number has one.
    var showsVersionToggle: Bool {
        displayedNumber.map(HymnCatalog.hasSecondVersion) ?? false
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
            if isEditingSlot { commitSlot() } else { deselect() }
            return
        }
        activeSlot = slot
        padBuffer = ""
        selectedVersion = slotVersions[slot] ?? 1
        if slot == .postlude { postlude.selectForPlayback() } // queue/advance the rotation
        applyVolumePreset(for: slot)
        loadCurrent()
    }

    /// EXPERIMENTAL (may change/be removed after testing): selecting a slot
    /// presets the volume — Prelude/Postlude 50%, Opening/Memorial/Closing 80%.
    /// Fires only on fresh selection, so manual slider adjustments stick after.
    private func applyVolumePreset(for slot: ServiceSlot) {
        let level: Double = (slot == .prelude || slot == .postlude) ? 0.5 : 0.8
        #if targetEnvironment(simulator)
        audio.volume = level          // sim has no system volume; drive the fallback slider
        #else
        SystemVolume.set(Float(level))
        #endif
    }

    /// Commit the typed number into the active programmable slot ("Set Opening").
    func commitSlot() {
        guard let slot = activeSlot, slot.isProgrammable,
              let n = Int(padBuffer), HymnCatalog.isValid(n) else { return }
        let v = HymnCatalog.hasSecondVersion(n) ? selectedVersion : 1
        slotNumbers[slot] = n
        slotVersions[slot] = v
        padBuffer = ""
        // Prefetch both renditions: choir for the slot itself, piano for the prelude.
        store.prefetch(Hymn(number: n, type: .choir, version: v))
        store.prefetch(Hymn(number: n, type: .piano, version: v))
        loadCurrent()
    }

    /// Discard a staged slot edit, reverting to the slot's committed value.
    func cancelEdit() {
        guard isEditingSlot else { return }
        padBuffer = ""
        loadCurrent()
    }

    /// Clear the current slot selection and return to Play Now.
    private func deselect() {
        activeSlot = nil
        padBuffer = ""
        loadCurrent()
    }

    /// True whenever the back-out (✕) control should be available: a slot is
    /// selected and/or being edited.
    var canCancel: Bool { activeSlot != nil }

    /// Back out one level: discard a staged edit, otherwise exit the selected
    /// slot back to Play Now.
    func cancelOrExit() {
        if isEditingSlot { cancelEdit() } else { deselect() }
    }

    func setPlayNowType(_ type: HymnType) {
        playNowType = type
        loadCurrent()
    }

    func setVersion(_ version: Int) {
        selectedVersion = version
        // If a committed (non-editing) slot is current, switch its tune live.
        if let slot = activeSlot, slot.isProgrammable, !isEditingSlot, let n = slotNumbers[slot] {
            slotVersions[slot] = version
            store.prefetch(Hymn(number: n, type: .choir, version: version))
            store.prefetch(Hymn(number: n, type: .piano, version: version))
        }
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
                if let hymn = slotHymn(slot, type: .piano) {
                    urls += await cached(hymn)
                }
            }
            return urls

        case .postlude:
            return postlude.current.map { [$0] } ?? []

        case .some(let slot): // opening / memorial / closing
            guard let hymn = slotHymn(slot, type: slot.mainType) else { return [] }
            return await cached(hymn)
        }
    }

    /// A slot's hymn for a given rendition, honoring its chosen tune version.
    private func slotHymn(_ slot: ServiceSlot, type: HymnType) -> Hymn? {
        guard let n = slotNumbers[slot] else { return nil }
        return Hymn(number: n, type: type, version: slotVersions[slot] ?? 1)
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
            guard let hymn = slotHymn(slot, type: .choir) else { return .unset }
            return renditionState(hymn)

        case .prelude:
            let hymns = ServiceSlot.programmable.compactMap { slotHymn($0, type: .piano) }
            guard !hymns.isEmpty else { return .disabled }
            let states = hymns.map { store.state(for: $0) }
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
            guard let hymn = slotHymn(slot, type: slot.mainType) else { return .unset }
            return renditionState(hymn)
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
