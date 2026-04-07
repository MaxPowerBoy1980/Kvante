import SwiftUI

struct LongMultiplicationState {
    let multiplicand: Int
    let multiplier: Int
    let multiplicandDigits: [Int]
    let multiplierDigits: [Int]

    var partials: [Partial]
    var activePartialIndex: Int?
    var currentExpressionChain: String?
    var currentCarries: [Int?]    // parallel to multiplicandDigits, written order
    var showSum: Bool
    var sumTotal: Int?
    var showResult: Bool
    var resultText: String?

    struct Partial {
        let value: Int
        let digits: [Int]
        let shift: Int
    }

    init(multiplicand: Int, multiplier: Int,
         multiplicandDigits: [Int], multiplierDigits: [Int]) {
        self.multiplicand = multiplicand
        self.multiplier = multiplier
        self.multiplicandDigits = multiplicandDigits
        self.multiplierDigits = multiplierDigits
        self.partials = []
        self.activePartialIndex = nil
        self.currentExpressionChain = nil
        self.currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
        self.showSum = false
        self.sumTotal = nil
        self.showResult = false
        self.resultText = nil
    }

    static func from(visual: VisualInstruction) -> LongMultiplicationState {
        let mc = visual.intParam("multiplicand") ?? 0
        let mp = visual.intParam("multiplier") ?? 0
        let mcDigits = visual.intArrayParam("multiplicand_digits") ?? []
        let mpDigits = visual.intArrayParam("multiplier_digits") ?? []
        return LongMultiplicationState(
            multiplicand: mc,
            multiplier: mp,
            multiplicandDigits: mcDigits,
            multiplierDigits: mpDigits
        )
    }

    mutating func apply(visual: VisualInstruction) {
        switch visual.action {
        case "setup":
            // No-op: AnimationPlayer reassigns the entire state via from(visual:)
            // when it sees a setup action. This is also how try_yours resets to
            // a fresh, empty grid with the student's numbers.
            break

        case "partial_product":
            let value = visual.intParam("value") ?? 0
            let digits = visual.intArrayParam("digits") ?? []
            let shift = visual.intParam("shift") ?? 0
            partials.append(Partial(value: value, digits: digits, shift: shift))
            activePartialIndex = partials.count - 1
            currentExpressionChain = visual.stringParam("expression_chain")

            // carries: parallel to multiplicandDigits, may be missing entirely
            if let cs = visual.optionalIntArrayParam("carries") {
                currentCarries = cs
            } else {
                currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
            }

        case "sum_partials":
            showSum = true
            sumTotal = visual.intParam("total")
            currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
            activePartialIndex = nil
            currentExpressionChain = nil

        case "reveal":
            showResult = true
            if let r = visual.intParam("result") {
                resultText = String(r)
            }
            // Single-partial case: sum_partials was skipped, so reveal must
            // also clear the lingering carry/active state.
            if !showSum {
                currentCarries = Array(repeating: nil, count: multiplicandDigits.count)
                activePartialIndex = nil
                currentExpressionChain = nil
            }

        default:
            break
        }
    }
}

struct LongMultiplicationView: View {
    let visual: VisualInstruction
    let animate: Bool
    let state: LongMultiplicationState

    @State private var revealedSegments: Int = 0
    @State private var chainAnimationTask: Task<Void, Never>?

    private let cellSize: CGFloat = 36
    private let largeFont: Font = .custom("Marker Felt", size: 28)
    private let smallFont: Font = .custom("Marker Felt", size: 18)

    /// Total grid width: enough cells to show the widest row.
    /// Worst case: a partial value can be wider than the multiplicand
    /// (e.g. 999 × 9 = 8991 is 4 digits when multiplicand is 3 digits).
    private var gridWidth: Int {
        var width = max(state.multiplicandDigits.count, state.multiplierDigits.count)
        for p in state.partials {
            width = max(width, p.digits.count + p.shift)
        }
        if state.showSum, let t = state.sumTotal {
            width = max(width, String(t).count)
        }
        return width
    }

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            // Mente (carry) row
            carryRow()
            // Multiplicand row
            digitRow(state.multiplicandDigits, alignRight: true,
                     prefix: "", color: KvanteTheme.Colors.ink)
            // Multiplier row with × prefix
            digitRow(state.multiplierDigits, alignRight: true,
                     prefix: "×", color: KvanteTheme.Colors.ink)
            // Line under multiplier
            Rectangle()
                .fill(KvanteTheme.Colors.ink.opacity(0.5))
                .frame(height: 3)
                .frame(width: CGFloat(gridWidth + 1) * cellSize)
            // Partial product rows
            ForEach(Array(state.partials.enumerated()), id: \.offset) { idx, partial in
                partialRow(partial, isActive: state.activePartialIndex == idx)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(16)
        .animation(.easeOut(duration: 0.3), value: state.partials.count)
    }

    @ViewBuilder
    private func carryRow() -> some View {
        // currentCarries is parallel to multiplicandDigits in WRITTEN order.
        // Pad on the left so the carry positions line up with the multiplicand
        // row above the line.
        let leadingEmptyCells = gridWidth - state.multiplicandDigits.count

        HStack(spacing: 0) {
            // Operator cell column
            Color.clear.frame(width: cellSize, height: cellSize / 1.5)
            // Empty leading cells
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize / 1.5)
            }
            // Carry cells
            ForEach(Array(state.currentCarries.enumerated()), id: \.offset) { _, carry in
                if let c = carry {
                    Text("\(c)")
                        .font(smallFont)
                        .foregroundStyle(.orange)
                        .frame(width: cellSize, height: cellSize / 1.5)
                        .transition(.opacity)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize / 1.5)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.currentCarries.map { $0 ?? -1 })
    }

    @ViewBuilder
    private func partialRow(_ partial: LongMultiplicationState.Partial,
                            isActive: Bool) -> some View {
        // Render with shifted zeros: a partial of digits=[8,2,4] and shift=1
        // becomes "8 2 4 0" (one extra '0' on the right).
        let displayDigits = partial.digits + Array(repeating: 0, count: partial.shift)
        let leadingEmptyCells = gridWidth - displayDigits.count

        HStack(spacing: 0) {
            // Empty operator cell column
            Color.clear.frame(width: cellSize, height: cellSize)
            // Empty leading cells
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize)
            }
            // Digit cells
            ForEach(Array(displayDigits.enumerated()), id: \.offset) { _, d in
                Text("\(d)")
                    .font(largeFont)
                    .foregroundStyle(KvanteTheme.Colors.ink)
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .background(
            isActive
                ? KvanteTheme.Colors.primary.opacity(0.1)
                : Color.clear
        )
    }

    @ViewBuilder
    private func digitRow(_ digits: [Int], alignRight: Bool, prefix: String,
                          color: Color) -> some View {
        let leadingEmptyCells = gridWidth - digits.count
        HStack(spacing: 0) {
            // Operator cell on the very left
            Text(prefix)
                .font(largeFont)
                .foregroundStyle(KvanteTheme.Colors.primary)
                .frame(width: cellSize, height: cellSize)
            // Empty leading cells to right-align
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize)
            }
            // Digit cells
            ForEach(Array(digits.enumerated()), id: \.offset) { _, d in
                Text("\(d)")
                    .font(largeFont)
                    .foregroundStyle(color)
                    .frame(width: cellSize, height: cellSize)
            }
        }
    }
}
