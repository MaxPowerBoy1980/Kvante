import SwiftUI

struct ErrorAnalysisSheet: View {
    let assignment: ParsedAssignment
    let studentAnswer: String
    let errorDescription: String
    let scanId: String?
    let apiClient: APIClient
    let sessionId: String
    let onOpenChat: () -> Void
    let onCorrected: (SubmissionResponse) -> Void

    @State private var showCorrection = false
    @State private var correctedAnswer = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Opgave \(assignment.localId): \(assignment.text)")
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.ink)

            if let scanId {
                AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KvanteTheme.Colors.cream).frame(height: 120)
                        .overlay { ProgressView() }
                }
            }

            // What Kvante read
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text("Kvante læste: \(studentAnswer)")
                    .font(.body.weight(.medium))
            }

            // Error info
            if !errorDescription.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(KvanteTheme.Colors.primary)
                    Text(errorDescription)
                        .font(.body).foregroundStyle(KvanteTheme.Colors.ink)
                }
                .padding(12)
                .background(KvanteTheme.Colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            // Correction option
            if showCorrection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hvad skrev du?")
                        .font(.subheadline)
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    HStack {
                        TextField("Dit svar...", text: $correctedAnswer)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                        Button {
                            Task { await submitCorrected() }
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
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 10) {
                if !showCorrection {
                    Button {
                        showCorrection = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Kvante læste forkert — ret mit svar")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(KvanteTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KvanteTheme.Colors.primary, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onOpenChat()
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Få hjælp i chatten")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
    }

    @MainActor
    private func submitCorrected() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await apiClient.submitAnswer(
                sessionId: sessionId,
                assignmentId: assignment.id,
                answerText: correctedAnswer,
                fullOcrText: correctedAnswer,
                imageData: Data()
            )
            onCorrected(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
