import SwiftUI

@Observable
class AnimationPlayer {
    let steps: [AnimationStep]
    private(set) var currentStepIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private var autoAdvanceTask: Task<Void, Never>?

    // Cumulative state for ObjectCollection
    private(set) var cumulativeObjects: Int = 0
    private(set) var cumulativeCrossedOut: Int = 0
    private(set) var cumulativeRows: Int = 2
    private(set) var cumulativeGrouped: Int = 0

    var currentStep: AnimationStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var isAtEnd: Bool { currentStepIndex >= steps.count - 1 }
    var isAtStart: Bool { currentStepIndex <= 0 }

    init(steps: [AnimationStep]) {
        self.steps = steps
    }

    func play() {
        isPlaying = true
        scheduleAutoAdvance()
    }

    func pause() {
        isPlaying = false
        autoAdvanceTask?.cancel()
    }

    func nextStep() {
        guard !isAtEnd else { return }
        updateCumulativeState(for: steps[currentStepIndex])
        currentStepIndex += 1
        if isPlaying { scheduleAutoAdvance() }
    }

    func previousStep() {
        guard !isAtStart else { return }
        currentStepIndex -= 1
        recalculateCumulativeState()
        if isPlaying { scheduleAutoAdvance() }
    }

    func reset() {
        currentStepIndex = 0
        cumulativeObjects = 0
        cumulativeCrossedOut = 0
        cumulativeRows = 2
        cumulativeGrouped = 0
        isPlaying = false
        autoAdvanceTask?.cancel()
    }

    // MARK: - Auto-advance

    private func scheduleAutoAdvance() {
        autoAdvanceTask?.cancel()
        guard !isAtEnd else {
            isPlaying = false
            return
        }

        let delay = pauseDuration(for: steps[currentStepIndex])
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            if !Task.isCancelled && isPlaying {
                nextStep()
            }
        }
    }

    private func pauseDuration(for step: AnimationStep) -> Double {
        switch step.visual.type {
        case "equation": return 1.5
        case "object_collection":
            let count = step.visual.intParam("count") ?? 0
            return count > 10 ? 3.5 : 2.5
        case "array_grid": return 3.5
        case "number_line":
            let jumps = step.visual.intParam("jumps") ?? 1
            return 2.0 + Double(jumps) * 0.5
        default: return 2.5
        }
    }

    // MARK: - Cumulative state

    private func updateCumulativeState(for step: AnimationStep) {
        let v = step.visual
        switch (v.type, v.action) {
        case ("object_collection", "draw"), ("object_collection", "add"):
            cumulativeObjects += v.intParam("count") ?? 0
            if let rows = v.intParam("rows") { cumulativeRows = rows }
        case ("object_collection", "cross_out"):
            cumulativeCrossedOut += v.intParam("count") ?? 0
        case ("grouping", "place_objects"):
            break // Just placing, not grouping
        case ("grouping", "form_group"):
            cumulativeGrouped += v.intParam("size") ?? 0
        default: break
        }
    }

    private func recalculateCumulativeState() {
        cumulativeObjects = 0
        cumulativeCrossedOut = 0
        cumulativeRows = 2
        cumulativeGrouped = 0
        for i in 0..<currentStepIndex {
            updateCumulativeState(for: steps[i])
        }
    }
}
