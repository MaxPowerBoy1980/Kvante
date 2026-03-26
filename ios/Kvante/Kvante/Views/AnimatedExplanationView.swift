import SwiftUI

struct AnimatedExplanationView: View {
    let example: ExampleResponse

    @State private var player: AnimationPlayer

    init(example: ExampleResponse) {
        self.example = example
        self._player = State(initialValue: AnimationPlayer(steps: example.steps))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Example problem header
            Text(example.exampleProblem)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Steps
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(example.steps.enumerated()), id: \.element.id) { index, step in
                            StepCardView(
                                step: step,
                                isActive: index == player.currentStepIndex,
                                isCompleted: index < player.currentStepIndex,
                                animate: index == player.currentStepIndex,
                                cumulativeObjects: player.cumulativeObjects,
                                cumulativeCrossedOut: player.cumulativeCrossedOut,
                                cumulativeRows: player.cumulativeRows,
                                cumulativeGrouped: player.cumulativeGrouped
                            )
                            .id(step.step)
                            .opacity(index <= player.currentStepIndex ? 1 : 0.3)
                        }

                        // Note
                        if !example.note.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text(example.note)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: player.currentStepIndex) { _, newIndex in
                    let stepNum = example.steps[min(newIndex, example.steps.count - 1)].step
                    withAnimation { proxy.scrollTo(stepNum, anchor: .center) }
                }
            }

            // Controls
            HStack(spacing: 24) {
                Button {
                    player.previousStep()
                } label: {
                    Label("Forrige", systemImage: "chevron.left")
                        .font(.callout)
                }
                .disabled(player.isAtStart)

                Button {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button {
                    player.nextStep()
                } label: {
                    Label("Naeste trin", systemImage: "chevron.right")
                        .font(.callout)
                }
                .disabled(player.isAtEnd)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Eksempel")
        .onAppear { player.play() }
    }
}

struct StepCardView: View {
    let step: AnimationStep
    let isActive: Bool
    let isCompleted: Bool
    let animate: Bool
    let cumulativeObjects: Int
    let cumulativeCrossedOut: Int
    let cumulativeRows: Int
    let cumulativeGrouped: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Step header
            HStack {
                Text("Trin \(step.step)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange, in: Capsule())

                Text(step.text)
                    .font(.subheadline)
                    .fontWeight(isActive ? .medium : .regular)

                Spacer()

                if isActive {
                    Text("Afspiller")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            // Visual component
            VisualComponentView(
                visual: step.visual,
                animate: animate,
                cumulativeObjects: cumulativeObjects,
                cumulativeCrossedOut: cumulativeCrossedOut,
                cumulativeRows: cumulativeRows,
                cumulativeGrouped: cumulativeGrouped
            )
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(isCompleted ? 0.6 : 1)
        .padding(.horizontal, 20)
    }
}
