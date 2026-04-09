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

    @State private var presentedFeedback: ArkFeedbackItem?

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
                                isCurrent: session.currentAssignmentIndex == index,
                                apiClient: apiClient,
                                onTap: {
                                    onSelectAssignment(index)
                                },
                                onFeedbackTap: {
                                    presentedFeedback = ArkFeedbackItem(
                                        id: assignment.id,
                                        assignment: assignment,
                                        index: index
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
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
                    // Pop back to home — handled by NavigationStack
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
