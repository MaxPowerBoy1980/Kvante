import SwiftUI

/// Shown when Kvante read a student's answer but confidence is low or the answer is wrong.
/// Lets the student confirm what Kvante read, or correct it by typing the actual answer.
struct ConfirmAnswerSheet: View {
    let assignment: ParsedAssignment
    let kvanteRead: String
    let sessionId: String
    let apiClient: APIClient
    let onResult: (SubmissionResponse) -> Void
    let onDismiss: () -> Void

    @State private var correctedAnswer = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var showOrderTips: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenOrderTips_\(sessionId)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Opgave \(assignment.localId): \(assignment.text)")
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.ink)

            // What Kvante read
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text("Kvante læste: \(kvanteRead)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KvanteTheme.Colors.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            // Confirm button
            Button {
                Task { await submitAnswer(kvanteRead) }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Ja, det er rigtigt")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KvanteTheme.Colors.success, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)

            // Correct section
            VStack(alignment: .leading, spacing: 8) {
                Text("Nej, jeg skrev:")
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)

                HStack {
                    TextField("Dit svar...", text: $correctedAnswer)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        Task { await submitAnswer(correctedAnswer) }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(KvanteTheme.Colors.primary)
                    }
                    .disabled(correctedAnswer.isEmpty || isSubmitting)
                }
            }

            if isSubmitting {
                ProgressView("Sender...")
                    .font(.subheadline)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if showOrderTips {
                orderTipsView
            }

            Spacer()
        }
        .padding(20)
    }

    private var orderTipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips til pæn orden", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.primary)

            VStack(alignment: .leading, spacing: 4) {
                tipRow("Skriv tydeligt med sort eller blå pen")
                tipRow("Brug linjer eller tern-papir")
                tipRow("Giv god plads mellem opgaverne")
                tipRow("Skriv opgavenummeret ved hvert svar")
            }
        }
        .padding(12)
        .background(KvanteTheme.Colors.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .onAppear {
            UserDefaults.standard.set(true, forKey: "hasSeenOrderTips_\(sessionId)")
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(KvanteTheme.Colors.textSecondary)
    }

    @MainActor
    private func submitAnswer(_ answer: String) async {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await apiClient.submitAnswer(
                sessionId: sessionId,
                assignmentId: assignment.id,
                answerText: answer,
                fullOcrText: answer,
                imageData: Data()
            )
            onResult(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
