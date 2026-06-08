import SwiftUI

/// One of the five large service-slot buttons. Color reflects state; the active
/// slot gets a white ring. Shows the assigned hymn number(s) under the title.
struct SlotButton: View {
    @Environment(AppModel.self) private var model
    let slot: ServiceSlot

    private var state: ControlState { model.slotState(slot) }
    private var isActive: Bool { model.activeSlot == slot }

    var body: some View {
        Button {
            model.selectSlot(slot)
        } label: {
            VStack(spacing: 4) {
                Text(slot.title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text(detail)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .opacity(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(Theme.textColor(for: state))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .background(Theme.color(for: state), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.activeRing, lineWidth: isActive ? 4 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    /// Secondary line under the title.
    private var detail: String {
        switch slot {
        case .opening, .memorial, .closing:
            if isActive && model.isEditingSlot { return model.padBuffer }
            if let n = model.slotNumbers[slot] { return "\(n)" }
            return "—"

        case .prelude:
            let nums = ServiceSlot.programmable.compactMap { model.slotNumbers[$0] }
            return nums.isEmpty ? "—" : nums.map(String.init).joined(separator: " · ")

        case .postlude:
            return model.postlude.hasClips ? "rotation" : "no clips"
        }
    }
}
