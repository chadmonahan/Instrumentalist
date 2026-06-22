import SwiftUI

/// One of the five large service-slot buttons. Color reflects state; the active
/// slot gets a white ring. Shows the assigned hymn number(s) under the title.
struct SlotButton: View {
    @Environment(AppModel.self) private var model
    let slot: ServiceSlot

    private var state: ControlState { model.slotState(slot) }
    private var isActive: Bool { model.activeSlot == slot }
    /// Mid-edit: this slot is active and a new number is staged on the pad.
    private var isEditing: Bool { isActive && model.isEditingSlot }

    var body: some View {
        Button {
            model.selectSlot(slot)
        } label: {
            VStack(spacing: 4) {
                Text(isEditing ? "Set \(slot.title)" : slot.title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isEditing {
                    Label(model.padBuffer, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                } else {
                    Text(detail)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .opacity(0.9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(Theme.textColor(for: state))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 6)
            .background(Theme.color(for: state), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.activeRing, lineWidth: isActive ? 4 : 0)
            )
            // Recede the non-active buttons so the active one (vivid + white ring)
            // clearly stands out even when several share the same green state.
            .opacity(isActive ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(state == .disabled)
    }

    /// Secondary line under the title (non-editing state; editing is handled inline).
    private var detail: String {
        switch slot {
        case .opening, .memorial, .closing:
            if let n = model.slotNumbers[slot] { return "\(n)" }
            return "—"

        case .prelude:
            let nums = ServiceSlot.programmable.compactMap { model.slotNumbers[$0] }
            return nums.isEmpty ? "—" : nums.map(String.init).joined(separator: " · ")

        case .postlude:
            if let n = model.postlude.currentNumber { return "\(n)" }
            return model.postlude.hasClips ? "rotation" : "no clips"
        }
    }
}
