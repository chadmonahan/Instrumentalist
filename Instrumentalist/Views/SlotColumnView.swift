import SwiftUI

/// The five slot buttons. Laid out vertically (landscape, down the left) or
/// horizontally (portrait, across the top) depending on `axis`.
struct SlotColumnView: View {
    let axis: Axis

    var body: some View {
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            ForEach(ServiceSlot.allCases) { slot in
                SlotButton(slot: slot)
            }
        }
    }
}
