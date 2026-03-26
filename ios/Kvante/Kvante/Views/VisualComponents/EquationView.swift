import SwiftUI

struct EquationVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var parts: [String] {
        visual.stringArrayParam("parts") ?? []
    }

    private var highlightIndex: Int? {
        visual.intParam("highlight")
    }

    @State private var visibleCount = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Text(part)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(partColor(index: index))
                    .shadow(
                        color: isHighlighted(index: index) ? .orange.opacity(0.6) : .clear,
                        radius: isHighlighted(index: index) ? 12 : 0
                    )
                    .opacity(index < visibleCount ? 1 : 0)
                    .scaleEffect(index < visibleCount ? 1 : 0.5)
                    .animation(.spring(duration: 0.4).delay(Double(index) * 0.3), value: visibleCount)
            }
        }
        .padding(20)
        .onAppear {
            if animate {
                visibleCount = parts.count
            }
        }
        .onChange(of: animate) { _, newValue in
            visibleCount = newValue ? parts.count : 0
        }
    }

    private func partColor(index: Int) -> Color {
        isHighlighted(index: index) ? .orange : .primary
    }

    private func isHighlighted(index: Int) -> Bool {
        highlightIndex == index
    }
}
