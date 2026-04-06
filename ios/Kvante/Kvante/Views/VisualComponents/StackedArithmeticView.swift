import SwiftUI

struct GridState {
    let columns: [String]
    let operation: String
    let topDigits: [Int]
    let bottomDigits: [Int]
    var answerDigits: [Int?]
    var crossedOut: [String: Bool]
    var replacements: [String: Int]
    var carries: [String: Int]
    var activeColumn: String?
    var currentExpression: String?
    var showAnswer: Bool

    init(columns: [String], operation: String, top: [Int], bottom: [Int]) {
        self.columns = columns
        self.operation = operation
        self.topDigits = top
        self.bottomDigits = bottom
        self.answerDigits = Array(repeating: nil, count: columns.count)
        self.crossedOut = [:]
        self.replacements = [:]
        self.carries = [:]
        self.activeColumn = nil
        self.currentExpression = nil
        self.showAnswer = false
    }

    static func from(visual: VisualInstruction) -> GridState {
        let columns = visual.stringArrayParam("columns") ?? ["Ti", "E"]
        let operation = visual.stringParam("operation") ?? "?"
        let top = visual.intArrayParam("top") ?? []
        let bottom = visual.intArrayParam("bottom") ?? []
        return GridState(columns: columns, operation: operation, top: top, bottom: bottom)
    }

    mutating func apply(visual: VisualInstruction) {
        let action = visual.action

        switch action {
        case "borrow":
            if let crossCol = visual.stringParam("cross_out_column") {
                crossedOut[crossCol] = true
                if let replacement = visual.intParam("replacement_value") {
                    replacements[crossCol] = replacement
                }
            }
            if let col = visual.stringParam("column"),
               let carryVal = visual.intParam("carry_value") {
                carries[col] = carryVal
            }
            activeColumn = visual.stringParam("column")
            currentExpression = nil

        case "carry":
            if let toCol = visual.stringParam("to_column"),
               let carryVal = visual.intParam("carry_value") {
                carries[toCol] = carryVal
            }
            activeColumn = visual.stringParam("from_column")
            currentExpression = nil

        case "compute":
            if let col = visual.stringParam("column"),
               let resultVal = visual.intParam("result_value"),
               let colIdx = columns.firstIndex(of: col) {
                answerDigits[colIdx] = resultVal
            }
            activeColumn = visual.stringParam("column")
            currentExpression = visual.stringParam("expression")

        case "answer":
            showAnswer = true
            activeColumn = nil
            currentExpression = nil

        default:
            break
        }
    }
}

struct StackedArithmeticView: View {
    let visual: VisualInstruction
    let animate: Bool
    let gridState: GridState

    var body: some View {
        let state = gridState
        // Guard: don't render grid if arrays don't match columns
        if state.columns.isEmpty
            || state.topDigits.count != state.columns.count
            || state.bottomDigits.count != state.columns.count {
            EmptyView()
        } else {
            VStack(spacing: 12) {
                if let expr = state.currentExpression {
                    Text(expr)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.teal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .transition(.scale.combined(with: .opacity))
                }

                gridView(state: state)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func gridView(state: GridState) -> some View {
        let opSymbol = state.operation == "addition" ? "+" : "−"
        let cellSize: CGFloat = 44
        let headerHeight: CGFloat = 24

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("")
                    .frame(width: cellSize, height: headerHeight)

                ForEach(state.columns, id: \.self) { col in
                    Text(col)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, height: headerHeight)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1)
                        }
                }
            }

            Divider()

            HStack(spacing: 0) {
                Text(opSymbol)
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    digitCell(
                        digit: state.topDigits[idx],
                        col: col,
                        isCrossedOut: state.crossedOut[col] == true,
                        replacement: state.replacements[col],
                        carry: state.carries[col],
                        isActive: state.activeColumn == col,
                        cellSize: cellSize
                    )
                }
            }

            HStack(spacing: 0) {
                Text("")
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    plainDigitCell(
                        digit: state.bottomDigits[idx],
                        isActive: state.activeColumn == col,
                        cellSize: cellSize
                    )
                }
            }

            Rectangle()
                .fill(Color.secondary)
                .frame(height: 2)
                .padding(.leading, cellSize)

            HStack(spacing: 0) {
                Text("")
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    answerDigitCell(
                        digit: state.answerDigits[idx],
                        isActive: state.activeColumn == col,
                        showGlow: state.showAnswer,
                        cellSize: cellSize
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func digitCell(digit: Int, col: String, isCrossedOut: Bool,
                           replacement: Int?, carry: Int?,
                           isActive: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.teal.opacity(0.1))
            }

            Text("\(digit)")
                .font(.custom("Marker Felt", size: 28))
                .foregroundStyle(isCrossedOut ? .secondary : .primary)

            if isCrossedOut {
                Path { path in
                    path.move(to: CGPoint(x: 8, y: cellSize - 8))
                    path.addLine(to: CGPoint(x: cellSize - 8, y: 8))
                }
                .stroke(Color.red, lineWidth: 2)
            }

            if let repl = replacement {
                Text("\(repl)")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundStyle(.red)
                    .offset(x: -12, y: -12)
            }

            if let c = carry {
                Text("\(c)")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundStyle(.teal)
                    .offset(x: -12, y: -12)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func plainDigitCell(digit: Int, isActive: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.teal.opacity(0.1))
            }
            Text("\(digit)")
                .font(.custom("Marker Felt", size: 28))
                .foregroundStyle(.primary)
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func answerDigitCell(digit: Int?, isActive: Bool,
                                  showGlow: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.teal.opacity(0.1))
            }
            if let d = digit {
                Text("\(d)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(.teal)
                    .shadow(color: showGlow ? .teal.opacity(0.6) : .clear, radius: showGlow ? 8 : 0)
                    .scaleEffect(showGlow ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.5).repeatCount(showGlow ? 2 : 0, autoreverses: true), value: showGlow)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
        }
    }
}
