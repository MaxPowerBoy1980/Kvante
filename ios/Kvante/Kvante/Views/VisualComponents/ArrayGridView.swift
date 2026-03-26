import SwiftUI

struct ArrayGridVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var rows: Int { visual.intParam("rows") ?? 1 }
    private var columns: Int { visual.intParam("columns") ?? 1 }
    private var highlightRow: Int? { visual.intParam("row_index") }
    private var total: Int? { visual.intParam("total") }
    private var expression: String? { visual.stringParam("expression") }

    @State private var visibleRows = 0
    @State private var showHighlight = false
    @State private var showTotal = false

    var body: some View {
        VStack(spacing: 12) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { _ in
                            Circle()
                                .fill(rowColor(row))
                                .frame(width: 20, height: 20)
                        }
                    }
                    .opacity(row < visibleRows ? 1 : 0)
                    .scaleEffect(row < visibleRows ? 1 : 0.3)
                    .animation(.spring(duration: 0.3).delay(Double(row) * 0.4), value: visibleRows)
                }
            }

            // Running total
            if action == "build_row" && visibleRows > 0 {
                Text("\(columns) x \(visibleRows) = \(columns * visibleRows)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Show total label
            if let expression, showTotal {
                Text(expression)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func rowColor(_ row: Int) -> Color {
        if showHighlight && row == highlightRow { return .orange }
        return .blue
    }

    private func startAnimation() {
        switch action {
        case "build_row":
            visibleRows = rows  // SwiftUI animates each row via delay
        case "highlight_row":
            visibleRows = rows
            withAnimation(.easeInOut(duration: 0.3)) { showHighlight = true }
        case "show_total":
            visibleRows = rows
            withAnimation(.spring) { showTotal = true }
        default: break
        }
    }
}
