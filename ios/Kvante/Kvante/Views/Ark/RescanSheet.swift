import SwiftUI
import VisionKit

struct RescanSheet: View {
    let assignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient
    let onResult: (SubmissionResponse) -> Void
    let onDismiss: () -> Void

    @State private var typedAnswer = ""
    @State private var showScanner = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var showOrderTips: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenOrderTips_\(sessionId)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Opgave \(assignment.localId)")
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("Kvante kan ikke læse dit svar til denne opgave.")
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.ink)

            Button {
                showScanner = true
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("Scan igen")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text("Eller skriv dit svar:")
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)

                HStack {
                    TextField("Dit svar...", text: $typedAnswer)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        Task { await submitTypedAnswer() }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(KvanteTheme.Colors.primary)
                    }
                    .disabled(typedAnswer.isEmpty || isSubmitting)
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
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                if let first = images.first {
                    Task { await submitRescan(first) }
                }
            } onCancel: {
                showScanner = false
            }
        }
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
    private func submitTypedAnswer() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await apiClient.submitAnswer(
                sessionId: sessionId,
                assignmentId: assignment.id,
                answerText: typedAnswer,
                fullOcrText: typedAnswer,
                imageData: Data()
            )
            onResult(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    @MainActor
    private func submitRescan(_ image: UIImage) async {
        isSubmitting = true
        errorMessage = nil
        let jpegData = downscaleToJPEG(image)
        do {
            let response = try await apiClient.submitWork(
                sessionId: sessionId,
                assignmentId: assignment.id,
                imageData: jpegData
            )
            onResult(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
