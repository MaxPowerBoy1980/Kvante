import SwiftUI

struct ArrayGridState {
    let rows: Int          // a (multiplikand, antal rækker)
    let cols: Int          // b (multiplikator, antal pr. række)

    var revealedRows: Int           // 0...rows
    var currentCumulative: Int?     // running total, nil før første row
    var showResult: Bool
    var resultText: String?

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.revealedRows = 0
        self.currentCumulative = nil
        self.showResult = false
        self.resultText = nil
    }

    static func from(visual: VisualInstruction) -> ArrayGridState {
        let rows = visual.intParam("rows") ?? 0
        let cols = visual.intParam("cols") ?? 0
        return ArrayGridState(rows: rows, cols: cols)
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            // No-op: AnimationPlayer reassigns the entire state via from(visual:)
            // when it sees a setup action.
            break
        case "row":
            revealedRows = (visual.intParam("row_index") ?? 0) + 1
            currentCumulative = visual.intParam("cumulative")
        case "reveal":
            revealedRows = rows
            showResult = true
            if let r = visual.intParam("result") {
                resultText = String(r)
            }
        default:
            break
        }
    }
}

struct ArrayGridCleanView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: ArrayGridState

    private let cellSize: CGFloat = 24
    private let cellSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 12) {
            // The grid — a × b cells with row-by-row reveal
            VStack(spacing: cellSpacing) {
                ForEach(0..<state.rows, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<state.cols, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(KvanteTheme.Colors.primary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    .opacity(row < state.revealedRows ? 1 : 0)
                    .scaleEffect(row < state.revealedRows ? 1 : 0.6)
                    .animation(.spring(duration: 0.35), value: state.revealedRows)
                }
            }

            // Running total under the grid (only when at least one row is visible
            // and we haven't yet shown the final result)
            if let cum = state.currentCumulative, !state.showResult {
                Text("\(cum)")
                    .font(.custom("Marker Felt", size: 22))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .transition(.opacity)
            }

            // Final result with celebration treatment
            if state.showResult, let result = state.resultText {
                Text("\(state.rows) × \(state.cols) = \(result)")
                    .font(.custom("Marker Felt", size: 24))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .scaleEffect(1.05)
                    .shadow(color: .teal.opacity(0.6), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
    }
}

#Preview("Setup (6×8, ingen rækker afsløret)") {
    let state = ArrayGridState(rows: 6, cols: 8)
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "setup"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Mid-state (6×8, 3 rækker, cum=24)") {
    var state = ArrayGridState(rows: 6, cols: 8)
    state.revealedRows = 3
    state.currentCumulative = 24
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "row"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Final state (6×8 = 48)") {
    var state = ArrayGridState(rows: 6, cols: 8)
    state.revealedRows = 6
    state.currentCumulative = 48
    state.showResult = true
    state.resultText = "48"
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Worst case 9×9 = 81 (iPad)") {
    var state = ArrayGridState(rows: 9, cols: 9)
    state.revealedRows = 9
    state.currentCumulative = 81
    state.showResult = true
    state.resultText = "81"
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}

#Preview("Worst case 9×9 = 81 (iPhone SE)", traits: .fixedLayout(width: 320, height: 568)) {
    var state = ArrayGridState(rows: 9, cols: 9)
    state.revealedRows = 9
    state.currentCumulative = 81
    state.showResult = true
    state.resultText = "81"
    return ArrayGridCleanView(
        visual: VisualInstruction.make(type: "single_digit_array", action: "reveal"),
        animate: false,
        state: state
    )
    .padding()
}
