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

    /// Build a completed grid showing the full solved computation with carries/borrows.
    static func completed(a: Int, b: Int, operation: String) -> GridState {
        let columnNames: [[String]] = [
            ["E"], ["Ti", "E"], ["H", "Ti", "E"],
            ["T", "H", "Ti", "E"], ["Tt", "T", "H", "Ti", "E"],
        ]

        func toDigits(_ n: Int, _ length: Int) -> [Int] {
            var digits: [Int] = []
            var val = n
            for _ in 0..<length { digits.append(val % 10); val /= 10 }
            return digits.reversed()
        }

        if operation == "addition" {
            let answer = a + b
            let numDigits = max(String(a).count, String(b).count, String(answer).count)
            let cols = columnNames[numDigits - 1]
            let top = toDigits(a, numDigits)
            let bottom = toDigits(b, numDigits)
            var state = GridState(columns: cols, operation: operation, top: top, bottom: bottom)

            var carry = 0
            for i in stride(from: numDigits - 1, through: 0, by: -1) {
                let total = top[i] + bottom[i] + carry
                state.answerDigits[i] = total % 10
                let newCarry = total / 10
                if newCarry > 0 && i > 0 {
                    state.carries[cols[i - 1]] = newCarry
                }
                carry = newCarry
            }
            state.showAnswer = true
            return state
        } else {
            // Subtraction
            let numDigits = max(String(a).count, String(b).count)
            let cols = columnNames[numDigits - 1]
            let top = toDigits(a, numDigits)
            let bottom = toDigits(b, numDigits)
            var state = GridState(columns: cols, operation: operation, top: top, bottom: bottom)

            var working = top
            for i in stride(from: numDigits - 1, through: 0, by: -1) {
                if working[i] < bottom[i] {
                    // Borrow
                    var j = i - 1
                    while j >= 0 && working[j] == 0 { j -= 1 }
                    if j >= 0 {
                        for k in j..<i {
                            state.crossedOut[cols[k]] = true
                            state.replacements[cols[k]] = working[k] - 1
                            working[k] -= 1
                            working[k + 1] += 10
                        }
                    }
                }
                state.answerDigits[i] = working[i] - bottom[i]
            }
            state.showAnswer = true
            return state
        }
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

    /// Returns true if the digit at index is a leading zero (all digits left of it are also zero).
    private func isLeadingZero(digits: [Int], at index: Int) -> Bool {
        guard digits[index] == 0 else { return false }
        return digits[0...index].allSatisfy { $0 == 0 }
    }

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
                        .foregroundStyle(KvanteTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(KvanteTheme.Colors.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
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
                        .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.4))
                        .frame(width: cellSize, height: headerHeight)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(KvanteTheme.Colors.ink.opacity(0.2))
                                .frame(width: 1)
                        }
                }
            }

            Divider()

            // Top number row (no operator)
            HStack(spacing: 0) {
                Text("")
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    let hidden = isLeadingZero(digits: state.topDigits, at: idx)
                    digitCell(
                        digit: state.topDigits[idx],
                        col: col,
                        isCrossedOut: state.crossedOut[col] == true,
                        replacement: state.replacements[col],
                        carry: state.carries[col],
                        isActive: state.activeColumn == col,
                        cellSize: cellSize,
                        hidden: hidden
                    )
                }
            }

            // Bottom number row (operator on left)
            HStack(spacing: 0) {
                Text(opSymbol)
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .frame(width: cellSize, height: cellSize)

                ForEach(Array(state.columns.enumerated()), id: \.offset) { idx, col in
                    let hidden = isLeadingZero(digits: state.bottomDigits, at: idx)
                    plainDigitCell(
                        digit: state.bottomDigits[idx],
                        isActive: state.activeColumn == col,
                        cellSize: cellSize,
                        hidden: hidden
                    )
                }
            }

            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.5))
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
                           isActive: Bool, cellSize: CGFloat,
                           hidden: Bool = false) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }

            if !hidden {
                Text("\(digit)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(isCrossedOut ? KvanteTheme.Colors.ink.opacity(0.3) : KvanteTheme.Colors.ink)
            }

            if isCrossedOut {
                Path { path in
                    path.move(to: CGPoint(x: 8, y: cellSize - 8))
                    path.addLine(to: CGPoint(x: cellSize - 8, y: 8))
                }
                .stroke(KvanteTheme.Colors.primary, lineWidth: 2)
            }

            if let repl = replacement {
                Text("\(repl)")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .offset(x: -12, y: -12)
            }

            if let c = carry {
                Text("\(c)")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .offset(x: -12, y: -12)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.2))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func plainDigitCell(digit: Int, isActive: Bool, cellSize: CGFloat,
                                hidden: Bool = false) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }
            if !hidden {
                Text("\(digit)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.2))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func answerDigitCell(digit: Int?, isActive: Bool,
                                  showGlow: Bool, cellSize: CGFloat) -> some View {
        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }
            if let d = digit {
                Text("\(d)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .shadow(color: showGlow ? .teal.opacity(0.6) : .clear, radius: showGlow ? 8 : 0)
                    .scaleEffect(showGlow ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.5).repeatCount(showGlow ? 2 : 0, autoreverses: true), value: showGlow)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.2))
                .frame(width: 1)
        }
    }
}
