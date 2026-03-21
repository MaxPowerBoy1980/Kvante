import SwiftUI

struct ExampleView: View {
    let example: ExampleResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Example problem header
                Text(example.exampleProblem)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

                // Steps
                ForEach(example.steps) { step in
                    VStack(alignment: .leading, spacing: 12) {
                        // Step number
                        HStack {
                            Text("Trin \(step.step)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.orange, in: Capsule())
                            Text(step.instruction)
                                .font(.headline)
                        }

                        // Visual (monospaced for alignment)
                        Text(step.visual)
                            .font(.system(size: 24, design: .monospaced))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                        // Explanation
                        Text(step.explanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                // Note
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(example.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
        .navigationTitle("Eksempel")
    }
}
