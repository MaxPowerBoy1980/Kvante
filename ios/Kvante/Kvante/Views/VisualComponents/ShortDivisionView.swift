import SwiftUI

struct ShortDivisionState {
    let divisor: Int
    let digits: [Int]
    var rows: [(groupValue: Int, quotientDigit: Int, remainder: Int, leading: Bool)]
    var activeRow: Int?
    var currentExpression: String?
    var remainderValue: Int?
    var fractionWhole: Int?
    var fractionNumerator: Int?
    var fractionDenominator: Int?
    var decimalResult: String?
    var showResult: Bool
    var resultText: String?

    init(divisor: Int, digits: [Int]) {
        self.divisor = divisor
        self.digits = digits
        self.rows = []
        self.activeRow = nil
        self.currentExpression = nil
        self.remainderValue = nil
        self.fractionWhole = nil
        self.fractionNumerator = nil
        self.fractionDenominator = nil
        self.decimalResult = nil
        self.showResult = false
        self.resultText = nil
    }

    static func from(visual: VisualInstruction) -> ShortDivisionState {
        let divisor = visual.intParam("divisor") ?? 1
        let digits = visual.intArrayParam("digits") ?? []
        return ShortDivisionState(divisor: divisor, digits: digits)
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            break
        case "process_digit":
            let groupValue = visual.intParam("group_value") ?? 0
            let quotientDigit = visual.intParam("quotient_digit") ?? 0
            let remainder = visual.intParam("remainder") ?? 0
            let leading = visual.boolParam("leading") ?? false
            rows.append((groupValue: groupValue, quotientDigit: quotientDigit,
                         remainder: remainder, leading: leading))
            activeRow = rows.count - 1
            currentExpression = visual.stringParam("expression")
        case "show_remainder":
            remainderValue = visual.intParam("remainder")
            activeRow = nil
            currentExpression = nil
        case "show_fraction":
            fractionWhole = visual.intParam("whole")
            fractionNumerator = visual.intParam("numerator")
            fractionDenominator = visual.intParam("denominator")
        case "show_decimal":
            decimalResult = visual.stringParam("decimal_result")
        case "reveal":
            showResult = true
            activeRow = nil
            currentExpression = nil
            resultText = visual.stringParam("result")
        default:
            break
        }
    }
}

struct ShortDivisionView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: ShortDivisionState

    var body: some View {
        VStack(spacing: 12) {
            if let expr = state.currentExpression {
                Text(expr)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(KvanteTheme.Colors.primary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8))
                    .transition(.scale.combined(with: .opacity))
            }

            lollipopView

            if !state.showResult, let rem = state.remainderValue {
                Text("rest \(rem)")
                    .font(.custom("Marker Felt", size: 22))
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            if !state.showResult,
               let whole = state.fractionWhole,
               let num = state.fractionNumerator,
               let den = state.fractionDenominator {
                HStack(spacing: 4) {
                    Text("\(whole)")
                        .font(.custom("Marker Felt", size: 28))
                        .foregroundStyle(KvanteTheme.Colors.primary)
                    VStack(spacing: 0) {
                        Text("\(num)")
                            .font(.custom("Marker Felt", size: 18))
                        Rectangle()
                            .fill(KvanteTheme.Colors.ink)
                            .frame(width: 20, height: 2)
                        Text("\(den)")
                            .font(.custom("Marker Felt", size: 18))
                    }
                    .foregroundStyle(KvanteTheme.Colors.primary)
                }
                .transition(.opacity)
            }

            if !state.showResult, let dec = state.decimalResult {
                Text("= \(dec)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .transition(.opacity)
            }

            if state.showResult, let result = state.resultText {
                Text("= \(result)")
                    .font(.custom("Marker Felt", size: 32))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .shadow(color: .teal.opacity(0.6), radius: state.showResult ? 8 : 0)
                    .scaleEffect(state.showResult ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.5).repeatCount(2, autoreverses: true),
                               value: state.showResult)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var lollipopView: some View {
        let cellSize: CGFloat = 44

        VStack(spacing: 0) {
            Text("\(state.divisor)")
                .font(.custom("Marker Felt", size: 28))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(KvanteTheme.Colors.ink, lineWidth: 3)
                )

            ForEach(Array(state.rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 0) {
                    groupValueCell(row: row, idx: idx, cellSize: cellSize)

                    Rectangle()
                        .fill(KvanteTheme.Colors.ink)
                        .frame(width: 3)

                    quotientDigitCell(row: row, idx: idx, cellSize: cellSize)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            if !state.rows.isEmpty {
                Rectangle()
                    .fill(KvanteTheme.Colors.ink)
                    .frame(height: 3)
                    .frame(width: 120)
            }
        }
    }

    @ViewBuilder
    private func groupValueCell(row: (groupValue: Int, quotientDigit: Int, remainder: Int, leading: Bool),
                                 idx: Int, cellSize: CGFloat) -> some View {
        let isActive = state.activeRow == idx

        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }

            if idx > 0 {
                let prevRemainder = state.rows[idx - 1].remainder
                if prevRemainder > 0 {
                    HStack(spacing: 0) {
                        Text("\(prevRemainder)")
                            .font(.custom("Marker Felt", size: 18))
                            .foregroundStyle(.orange)
                        Text("\(row.groupValue % 10)")
                            .font(.custom("Marker Felt", size: 28))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                    }
                } else {
                    Text("\(row.groupValue)")
                        .font(.custom("Marker Felt", size: 28))
                        .foregroundStyle(KvanteTheme.Colors.ink)
                }
            } else {
                Text("\(row.groupValue)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }
        }
        .frame(width: 60, height: cellSize)
    }

    @ViewBuilder
    private func quotientDigitCell(row: (groupValue: Int, quotientDigit: Int, remainder: Int, leading: Bool),
                                    idx: Int, cellSize: CGFloat) -> some View {
        let isActive = state.activeRow == idx

        ZStack {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(KvanteTheme.Colors.primary.opacity(0.1))
            }

            if !row.leading {
                Text("\(row.quotientDigit)")
                    .font(.custom("Marker Felt", size: 28))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .animation(.spring(duration: 0.4), value: isActive)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}
