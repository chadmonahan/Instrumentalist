import SwiftUI

/// Large 0–9 number pad with a backspace key.
struct NumberPadView: View {
    @Environment(AppModel.self) private var model

    private let rows: [[PadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.blank,    .digit(0), .back],
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 12) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        keyView(rows[r][c])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(_ key: PadKey) -> some View {
        switch key {
        case .digit(let d):
            padButton(label: "\(d)") { model.keyDigit(d) }
        case .back:
            padButton(label: "⌫") { model.backspace() }
        case .blank:
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func padButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.idleFill, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private enum PadKey {
        case digit(Int)
        case back
        case blank
    }
}
