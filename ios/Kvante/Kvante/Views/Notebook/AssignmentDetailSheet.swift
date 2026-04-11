import SwiftUI

/// Detail sheet for a single assignment in the notebook.
/// Shows assignment text, student/correct answers, scan image, and Kvante feedback.
struct AssignmentDetailSheet: View {
    let assignment: NotebookAssignment
    let apiClient: APIClient

    @State private var scanImage: UIImage?
    @State private var isLoadingScan = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Label
                Text("Opgave \(assignment.position + 1) \u{00B7} Uge \(assignment.weekNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(KvanteTheme.Colors.textMuted)

                // Assignment text
                Text(assignment.text)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                // Result section
                resultSection

                // Scan image
                scanSection

                // Kvante feedback
                if let feedback = assignment.feedbackSummary, !feedback.isEmpty {
                    feedbackSection(feedback)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(KvanteTheme.Colors.cream)
        .task {
            await loadScanImage()
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        switch assignment.arkStatus {
        case "done":
            if let studentAnswer = assignment.studentAnswer,
               let correctAnswer = assignment.correctAnswer {
                if studentAnswer == correctAnswer {
                    // Correct
                    HStack(spacing: 4) {
                        Text("Dit svar:")
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        Text("\(studentAnswer) \u{2713}")
                            .foregroundStyle(KvanteTheme.Colors.success)
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 20))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Opgave: \(assignment.text). Dit svar: \(studentAnswer). Rigtigt.")
                } else {
                    // Incorrect
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("Dit svar")
                                .font(.system(size: 11))
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                            Text(studentAnswer)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(KvanteTheme.Colors.primary)
                        }
                        VStack(spacing: 4) {
                            Text("Rigtigt svar")
                                .font(.system(size: 11))
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                            Text("\(correctAnswer) \u{2713}")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(KvanteTheme.Colors.success)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Opgave: \(assignment.text). Dit svar: \(studentAnswer). Forkert. Rigtigt svar: \(correctAnswer).")
                }
            } else if let studentAnswer = assignment.studentAnswer {
                // Has student answer but no correct answer in DB
                HStack(spacing: 4) {
                    Text("Dit svar:")
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    Text(studentAnswer)
                        .fontWeight(.bold)
                }
                .font(.system(size: 20))
            }
        default:
            Text("Ikke besvaret")
                .font(.system(size: 16))
                .foregroundStyle(KvanteTheme.Colors.textMuted)
                .accessibilityLabel("Opgave: \(assignment.text). Ikke besvaret.")
        }
    }

    // MARK: - Scan image

    @ViewBuilder
    private var scanSection: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
            )
            .overlay {
                if let image = scanImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Dit h\u{00E5}ndskrevne arbejde")
                } else if isLoadingScan {
                    ProgressView()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundStyle(KvanteTheme.Colors.textMuted.opacity(0.5))
                        Text("Ingen scanning")
                            .font(.system(size: 12))
                            .foregroundStyle(KvanteTheme.Colors.textMuted)
                    }
                }
            }
            .frame(minHeight: 200)
    }

    // MARK: - Feedback

    private func feedbackSection(_ feedback: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Mini Kvante
            KvanteFace(expression: .happy)
                .frame(width: 20, height: 20)

            Text(feedback)
                .font(.system(size: 13))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineSpacing(4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KvanteTheme.Colors.teal.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kvante siger: \(feedback)")
    }

    // MARK: - Load scan

    private func loadScanImage() async {
        guard let scanId = assignment.scanId else { return }
        isLoadingScan = true
        defer { isLoadingScan = false }
        // Use larger maxPixelSize for detail sheet (full-width display)
        scanImage = try? await ScanImageCache.shared.image(for: scanId, apiClient: apiClient, maxPixelSize: 800)
    }
}
