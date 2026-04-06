import SwiftUI

struct PracticeSessionView: View {
    let sessionId: String
    let assignments: [PracticeAssignment]
    let apiClient: APIClient
    var onBack: (() -> Void)?

    @State private var chatViewModel: ChatViewModel?
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 0) {
            if isComplete {
                completionView
            } else if let vm = chatViewModel {
                ChatView(viewModel: vm, onBack: onBack)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { setupSession() }
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.success)
            }

            Text("Flot klaret!")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("Du har gennemført alle \(assignments.count) opgaver")
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            Button(action: { onBack?() }) {
                Text("Tilbage til forsiden")
                    .font(KvanteTheme.Fonts.buttonLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KvanteTheme.Colors.cream)
    }

    // MARK: - Setup

    private func setupSession() {
        let parsed = assignments.map { ParsedAssignment(from: $0) }
        let vm = ChatViewModel(
            assignments: parsed,
            sessionId: sessionId,
            apiClient: apiClient
        )
        vm.onSetComplete = { isComplete = true }
        chatViewModel = vm
    }
}
