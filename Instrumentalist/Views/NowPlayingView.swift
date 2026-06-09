import SwiftUI

/// The big current-hymn number, context label, toggles, optional "Set" button,
/// and the transport controls (play/pause + restart).
struct NowPlayingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            numberDisplay
            contextLabel
            toggles
            progressSection
            transport
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Number

    private var numberDisplay: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(model.displayedNumber.map(String.init) ?? "—")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: model.displayedNumber)
            if model.showsVersionToggle {
                Text(model.selectedVersion == 2 ? "2nd" : "1st")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ready)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.selectedVersion)
            }
        }
    }

    private var contextLabel: some View {
        Text(contextText)
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
    }

    private var contextText: String {
        if let slot = model.activeSlot {
            switch slot {
            case .prelude:
                let total = model.audio.totalDuration
                return total > 0 ? "Prelude • \(timeString(total))" : "Prelude"
            case .postlude:
                return "Postlude"
            default:
                return slot.title
            }
        }
        return "Play Now • \(model.playNowType == .piano ? "Piano" : "Choir")"
    }

    // MARK: - Progress (time played + remaining + bar)

    /// Always present (keeps layout stable); grayed out when nothing is loaded.
    private var progressSection: some View {
        let active = model.audio.hasLoadedItem
        return VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.idleFill)
                    Capsule().fill(Theme.ready)
                        .frame(width: max(0, geo.size.width * model.audio.progress))
                        .animation(.linear(duration: 0.2), value: model.audio.progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text(played)      // time played
                Spacer()
                Text(remaining)   // time remaining
            }
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.8))
        }
        .opacity(active ? 1 : 0.35)
    }

    private var played: String {
        model.audio.hasTiming ? timeString(model.audio.elapsed) : "0:00"
    }

    private var remaining: String {
        model.audio.hasTiming ? "-" + timeString(model.audio.remaining) : "0:00"
    }

    // MARK: - Toggles

    /// Fixed height so showing/hiding the Piano/Choir toggle doesn't reflow the
    /// column. (The 1st/2nd "second tune" toggle lives in the number pad.)
    private var toggles: some View {
        HStack(spacing: 12) {
            if model.showsTypeToggle {
                segToggle(left: "Piano", right: "Choir",
                          isLeft: model.playNowType == .piano) {
                    model.setPlayNowType($0 ? .piano : .choir)
                }
            }
        }
        .frame(height: 48)
    }

    private func segToggle(left: String, right: String, isLeft: Bool,
                           onSelect: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 0) {
            segHalf(left, selected: isLeft) { onSelect(true) }
            segHalf(right, selected: !isLeft) { onSelect(false) }
        }
        .background(Theme.idleFill, in: Capsule())
    }

    private func segHalf(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .black : .white)
                .padding(.vertical, 10)
                .padding(.horizontal, 22)
                .background(selected ? Theme.ready : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 16) {
            // Reset (left, always) · Play (center, constant size) · Cancel (right).
            // Cancel backs out: discards a staged edit, or exits a selected slot
            // to Play Now. Its slot is always reserved so the play button never
            // resizes and nothing jumps.
            circleButton(system: "arrow.counterclockwise") { model.restart() }

            Button { model.togglePlayPause() } label: {
                Image(systemName: playIcon)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Theme.textColor(for: model.playState))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Theme.color(for: model.playState), in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)

            circleButton(system: "xmark") { model.cancelOrExit() }
                .opacity(model.canCancel ? 1 : 0)
                .allowsHitTesting(model.canCancel)
        }
    }

    /// A circular transport button (Reset / Cancel), sized to match.
    private func circleButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(Theme.idleFill, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var playIcon: String {
        if model.playState == .downloading { return "arrow.down.circle" }
        return model.audio.isPlaying ? "pause.fill" : "play.fill"
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
