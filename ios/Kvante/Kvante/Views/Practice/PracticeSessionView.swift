import SwiftUI

struct PracticeSessionView: View {
    let sessionId: String
    let assignments: [PracticeAssignment]
    let apiClient: APIClient

    @State private var currentIndex = 0
    @State private var chatViewModel: ChatViewModel?
    @State private var completedCount = 0

    private var currentAssignment: PracticeAssignment? {
        guard currentIndex < assignments.count else { return nil }
        return assignments[currentIndex]
    }

    private var isSessionComplete: Bool {
        currentIndex >= assignments.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            // Content
            if isSessionComplete {
                completionView
            } else if let vm = chatViewModel {
                ChatView(viewModel: vm)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupCurrentAssignment() }
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Opgave \(currentIndex + 1) af \(assignments.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedCount) løst")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(assignments.count, 1)), height: 6)
                        .animation(.easeInOut, value: currentIndex)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🎉")
                .font(.system(size: 72))

            Text("Flot klaret!")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Du har gennemført alle \(assignments.count) opgaver")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Setup

    private func setupCurrentAssignment() {
        guard let assignment = currentAssignment else { return }
        let parsed = ParsedAssignment(from: assignment)
        let vm = ChatViewModel(
            assignment: parsed,
            sessionId: sessionId,
            apiClient: apiClient
        )
        vm.onNextAssignment = { advanceToNext() }
        chatViewModel = vm
    }

    private func advanceToNext() {
        completedCount += 1
        currentIndex += 1
        chatViewModel = nil
        if !isSessionComplete {
            setupCurrentAssignment()
        }
    }
}
