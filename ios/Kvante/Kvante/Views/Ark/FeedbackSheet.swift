import SwiftUI

struct FeedbackSheet: View {
    let assignmentId: String
    let assignmentText: String
    let assignmentIndex: Int
    let status: String // "correct", "incorrect", "uncertain", "done", "in_progress"
    let errorType: String? // "procedural", "understanding", "careless"
    let studentAnswer: String?
    let scanId: String?
    let cropRegion: CropRegion?
    let gearScore: GearScore?
    let improvementTip: String?
    let feedbackSummary: String?
    let submissionId: String?
    let isHistorical: Bool
    let apiClient: APIClient

    var onRetry: (() -> Void)?
    var onShowExample: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText: String?
    @State private var isLoadingFeedback = false
    @State private var scanImage: UIImage?
    @State private var isLoadingScan = false

    // MARK: - Computed Properties

    private var isCorrect: Bool {
        status == "correct" || status == "done"
    }

    private var pixelartName: String {
        if let gs = gearScore, gs.total == 6 { return "rob2_surprised" }
        if isCorrect { return "rob2_happy" }
        switch errorType {
        case "understanding": return "rob2_sad"
        default: return "rob2"
        }
    }

    private var headlineText: String {
        if isCorrect { return "Rigtigt!" }
        switch errorType {
        case "careless", "procedural": return "T\u{00e6}t p\u{00e5}!"
        default: return "Ikke helt"
        }
    }

    private var headlineColor: Color {
        isCorrect ? KvanteTheme.Colors.success : KvanteTheme.Colors.primary
    }

    private var questionText: String? {
        guard !isHistorical, !isCorrect else { return nil }
        switch errorType {
        case "procedural": return "Vil du pr\u{00f8}ve igen, eller skal jeg vise dig et eksempel med andre tal?"
        case "understanding": return "Skal jeg vise dig hvordan man l\u{00f8}ser den slags opgaver?"
        case "careless": return "Det var bare en lille glider \u{2014} vil du pr\u{00f8}ve igen?"
        default: return "Vil du pr\u{00f8}ve igen, eller skal jeg vise dig et eksempel med andre tal?"
        }
    }

    private var showHelpButton: Bool {
        !isHistorical && !isCorrect && errorType != "careless"
    }

    private var showRetryButton: Bool {
        !isHistorical && !isCorrect
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kvanteHeader
                scanSection
                Divider()
                feedbackSection
                tipSection
                actionSection
            }
            .padding(20)
        }
        .background(KvanteTheme.Colors.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await loadContent()
        }
    }

    // MARK: - 1. Kvante Header

    private var kvanteHeader: some View {
        VStack(spacing: 10) {
            Image(pixelartName)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text(headlineText)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(headlineColor)

            Text(assignmentText)
                .font(.system(size: 14))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            if let gs = gearScore {
                GearRatingView(score: gs.total)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2. Scan Section

    @ViewBuilder
    private var scanSection: some View {
        if isLoadingScan {
            RoundedRectangle(cornerRadius: 10)
                .fill(KvanteTheme.Colors.cream)
                .frame(height: 200)
                .overlay { ProgressView() }
        } else if let scanImage {
            ZStack {
                Image(uiImage: scanImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        if let cropRegion {
                            BoundingBoxOverlay(region: cropRegion)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 300)
        } else if scanId != nil {
            // Fallback placeholder when no image loaded
            RoundedRectangle(cornerRadius: 10)
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(height: 120)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
        }
    }

    // MARK: - 4. Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KVANTE SIGER")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                .textCase(.uppercase)

            if isLoadingFeedback {
                HStack(spacing: 10) {
                    Image("rob2_thinking")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)

                    Text("Kvante kigger p\u{00e5} dit arbejde...")
                        .font(.body.italic())
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                }
                .padding(12)
            } else {
                let displayText = feedbackText ?? feedbackSummary
                if let displayText {
                    Text(displayText)
                        .font(.body)
                        .foregroundStyle(KvanteTheme.Colors.ink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(KvanteTheme.Colors.teal.opacity(0.08))
                        )
                }
            }
        }
    }

    // MARK: - 5. Tip Section

    @ViewBuilder
    private var tipSection: some View {
        if isCorrect,
           let tip = improvementTip,
           gearScore?.total != 6 {
            VStack(alignment: .leading, spacing: 8) {
                Text("TIP FRA KVANTE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .textCase(.uppercase)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(KvanteTheme.Colors.primary)
                        .frame(width: 3)

                    Text(tip)
                        .font(.body)
                        .foregroundStyle(KvanteTheme.Colors.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - 6. Action Section

    @ViewBuilder
    private var actionSection: some View {
        if !isHistorical, !isCorrect {
            VStack(spacing: 14) {
                if let question = questionText {
                    Text(question)
                        .font(.body.italic())
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 12) {
                    if showRetryButton {
                        Button {
                            dismiss()
                            onRetry?()
                        } label: {
                            Text("Jeg pr\u{00f8}ver igen")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(KvanteTheme.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.buttonRadius)
                                        .stroke(KvanteTheme.Colors.primary, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if showHelpButton {
                        Button {
                            dismiss()
                            onShowExample?()
                        } label: {
                            Text("Ja, vis mig!")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.buttonRadius)
                                        .fill(KvanteTheme.Colors.primary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Loading Logic

    private func loadContent() async {
        // Load scan image
        if let sid = scanId {
            isLoadingScan = true
            scanImage = await ScanImageCache.shared.image(
                for: sid, apiClient: apiClient, maxPixelSize: 800
            )
            isLoadingScan = false
        }

        // Load feedback text lazily
        if feedbackText == nil, feedbackSummary == nil, let subId = submissionId {
            isLoadingFeedback = true
            do {
                let response = try await apiClient.getFeedback(submissionId: subId)
                feedbackText = response.feedbackText
            } catch {
                // Fallback: show nothing rather than crash
            }
            isLoadingFeedback = false
        }
    }
}
