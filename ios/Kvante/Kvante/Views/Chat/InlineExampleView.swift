import SwiftUI

/// Expandable worked example that unfolds step-by-step inside the chat.
struct InlineExampleView: View {
    let example: ExampleResponse
    @State private var expandedStep: Int? = nil
    @State private var player = AnimationPlayer(steps: [])

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill")
                        .font(.body)
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eksempel")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(example.exampleProblem)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            // Steps
            VStack(spacing: 8) {
                ForEach(Array(example.steps.enumerated()), id: \.element.id) { index, step in
                    StepRow(
                        step: step,
                        stepNumber: index + 1,
                        totalSteps: example.steps.count,
                        isExpanded: expandedStep == index,
                        player: player
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedStep = expandedStep == index ? nil : index
                            if expandedStep == index {
                                recalculatePlayer(upTo: index)
                            }
                        }
                    }
                }
            }

            // Note
            if !example.note.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(example.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(Color(red: 0.14, green: 0.14, blue: 0.18), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            player = AnimationPlayer(steps: example.steps)
        }
    }

    private func recalculatePlayer(upTo index: Int) {
        player.reset()
        for _ in 0..<index {
            player.nextStep()
        }
    }
}

struct StepRow: View {
    let step: AnimationStep
    let stepNumber: Int
    let totalSteps: Int
    let isExpanded: Bool
    let player: AnimationPlayer
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsed: step header (always visible)
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Text("\(stepNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.orange, in: Circle())

                    Text(step.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded: show visual
            if isExpanded {
                VisualComponentView(
                    visual: step.visual,
                    animate: true,
                    cumulativeObjects: player.cumulativeObjects,
                    cumulativeCrossedOut: player.cumulativeCrossedOut,
                    cumulativeRows: player.cumulativeRows,
                    cumulativeGrouped: player.cumulativeGrouped,
                    cumulativeGridState: player.cumulativeGridState,
                    cumulativeShortDivisionState: player.cumulativeShortDivisionState
                )
                .frame(maxWidth: .infinity)
                .padding(.leading, 34)
            }
        }
        .padding(10)
        .background(
            isExpanded
                ? Color.white.opacity(0.05)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}
