import SwiftUI

// MARK: - ArkFeedbackItem (wrapper for sheet binding)

struct ArkFeedbackItem: Identifiable {
    let id: String
    let assignment: ParsedAssignment
    let index: Int
}

// MARK: - AssignmentSheetView

struct AssignmentSheetView: View {
    let session: SessionViewModel
    let apiClient: APIClient
    let onSelectAssignment: (Int) -> Void
    var onBack: (() -> Void)?

    @State private var presentedFeedback: ArkFeedbackItem?
    @State private var isBulkScanning = false
    @State private var bulkScanError: String?
    @State private var bulkScanResponse: BulkSubmitResponse?
    @State private var presentedError: ArkFeedbackItem?
    @State private var presentedRescan: ArkFeedbackItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            paperBackground

            VStack(spacing: 0) {
                arkHeader

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(session.assignments.enumerated()), id: \.element.id) { index, assignment in
                            ArkCell(
                                assignment: assignment,
                                index: index,
                                status: session.statusByAssignment[assignment.id] ?? .notStarted,
                                scanId: session.latestScanId[assignment.id],
                                feedbackSummary: session.feedbackSummary[assignment.id],
                                errorDescription: session.errorDescription[assignment.id],
                                isCurrent: session.currentAssignmentIndex == index,
                                apiClient: apiClient,
                                onTap: { onSelectAssignment(index) },
                                onFeedbackTap: {
                                    if session.errorDescription[assignment.id] != nil {
                                        presentedError = ArkFeedbackItem(id: assignment.id, assignment: assignment, index: index)
                                    } else {
                                        presentedFeedback = ArkFeedbackItem(
                                            id: assignment.id,
                                            assignment: assignment,
                                            index: index
                                        )
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                if !isBulkScanning {
                    BulkScanButton(
                        hasIncompleteAssignments: session.completedCount < session.totalAssignments
                    ) { imageDataList in
                        Task { await performBulkScan(imageDataList) }
                    }
                    .padding(.bottom, 16)
                }

                if isBulkScanning {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(KvanteTheme.Colors.primary)
                        Text("Kvante læser dit ark...")
                            .font(.subheadline)
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, 16)
                }

                if let error = bulkScanError {
                    VStack(spacing: 8) {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Button("Prøv igen") { bulkScanError = nil }
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(16)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $presentedFeedback) { item in
            FeedbackPreviewSheet(
                assignment: item.assignment,
                session: session,
                apiClient: apiClient,
                onOpenChat: {
                    presentedFeedback = nil
                    onSelectAssignment(item.index)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $presentedError) { item in
            ErrorAnalysisSheet(
                assignment: item.assignment,
                studentAnswer: session.studentAnswer[item.assignment.id] ?? "?",
                errorDescription: session.errorDescription[item.assignment.id] ?? "",
                scanId: session.latestScanId[item.assignment.id],
                apiClient: apiClient,
                sessionId: session.sessionId,
                onOpenChat: {
                    presentedError = nil
                    onSelectAssignment(item.index)
                },
                onCorrected: { response in
                    presentedError = nil
                    if response.methodologySound {
                        session.markCompleted(item.assignment.id, feedback: nil)
                    } else {
                        session.statusByAssignment[item.assignment.id] = .inProgress
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $presentedRescan) { item in
            ConfirmAnswerSheet(
                assignment: item.assignment,
                kvanteRead: session.studentAnswer[item.assignment.id] ?? "?",
                sessionId: session.sessionId,
                apiClient: apiClient,
                onResult: { response in
                    presentedRescan = nil
                    if response.methodologySound {
                        session.markCompleted(item.assignment.id, feedback: nil)
                    } else {
                        session.statusByAssignment[item.assignment.id] = .inProgress
                    }
                },
                onDismiss: { presentedRescan = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Bulk Scan

    @MainActor
    private func performBulkScan(_ images: [Data]) async {
        isBulkScanning = true
        bulkScanError = nil
        do {
            let response = try await apiClient.bulkSubmit(sessionId: session.sessionId, images: images)
            session.processBulkResult(response)
            bulkScanResponse = response
        } catch {
            bulkScanError = error.localizedDescription
        }
        isBulkScanning = false
    }

    // MARK: - Header

    private var arkHeader: some View {
        VStack(spacing: 8) {
            // Drag handle (decorative, paper metaphor)
            RoundedRectangle(cornerRadius: 2)
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("Mit ark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("\(session.sessionName) — \(session.completedCount) af \(session.totalAssignments) løst")
                .font(.subheadline)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            // Back button
            HStack {
                Button {
                    onBack?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Hjem")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
        .background(
            Color.white.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Paper Background

    private var paperBackground: some View {
        ZStack {
            KvanteTheme.Colors.cream
            Canvas { context, size in
                // Sparse pixel-noise for paper texture
                var rng = SeededRandomNumberGenerator(seed: 42)
                let dotCount = Int(size.width * size.height / 200)
                for _ in 0..<dotCount {
                    let x = CGFloat.random(in: 0..<size.width, using: &rng)
                    let y = CGFloat.random(in: 0..<size.height, using: &rng)
                    let gray = CGFloat.random(in: 0.3...0.7, using: &rng)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color(white: gray))
                    )
                }
            }
            .opacity(0.04)
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Seeded RNG for consistent paper texture

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
