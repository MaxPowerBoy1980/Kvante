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
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                Spacer()
                Text("\(completedCount) løst")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.success)
            }
            .padding(.horizontal, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(KvanteTheme.Colors.muted)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(KvanteTheme.Colors.successGradient)
                        .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(assignments.count, 1)), height: 8)
                        .animation(.easeInOut, value: currentIndex)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(KvanteTheme.Colors.backgroundStart.opacity(0.95))
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.success)
            }

            Text("Flot klaret!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(KvanteTheme.Colors.textPrimary)

            Text("Du har gennemført alle \(assignments.count) opgaver")
                .font(.title3)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KvanteTheme.Colors.backgroundStart)
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
