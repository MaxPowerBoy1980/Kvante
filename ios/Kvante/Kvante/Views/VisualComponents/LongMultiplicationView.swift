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
