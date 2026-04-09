import SwiftUI

/// One week page in the notebook. Shows facit cards for all assignments.
struct NotebookWeekView: View {
    let week: NotebookWeek
    let viewModel: NotebookViewModel
    let apiClient: APIClient
    let pageLabel: String

    @State private var weeklyAssignments: [NotebookAssignment] = []
    @State private var practiceAssignments: [NotebookAssignment] = []
    @State private var isLoading = true
    @State private var selectedAssignment: NotebookAssignment?

    var body: some View {
        ZStack {
            paperBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    weekHeader
                        .padding(.horizontal, 24)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        ForEach(weeklyAssignments) { assignment in
                            FacitCard(assignment: assignment)
                                .onTapGesture { selectedAssignment = assignment }
                                .padding(.horizontal, 24)
                        }

                        if !practiceAssignments.isEmpty {
                            Text("Ekstra \u{00F8}velser")
                                .font(.system(size: 11, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            ForEach(practiceAssignments) { assignment in
                                FacitCard(assignment: assignment)
                                    .onTapGesture { selectedAssignment = assignment }
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Uge \(week.weekNumber). \(week.solvedCount) af \(week.totalCount) opgaver l\u{00F8}st.")
        .task {
            let result = await viewModel.assignments(for: week)
            weeklyAssignments = result.weekly
            practiceAssignments = result.practice
            isLoading = false
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentDetailSheet(assignment: assignment, apiClient: apiClient)
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Uge \(week.weekNumber)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)
                Spacer()
                Text(week.dateRange)
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
            }
            Text("\(week.solvedCount) af \(week.totalCount) opgaver l\u{00F8}st")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KvanteTheme.Colors.teal)
        }
    }

    // MARK: - Paper background

    private var paperBackground: some View {
        ZStack {
            KvanteTheme.Colors.cream
            Canvas { context, size in
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

            // Book spine on left edge
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(red: 0.91, green: 0.87, blue: 0.82), KvanteTheme.Colors.cream],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Facit Card

/// A compact card showing assignment result: text, answer badge, feedback line.
struct FacitCard: View {
    let assignment: NotebookAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(assignment.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                Spacer()

                answerBadge
            }

            if let feedback = assignment.feedbackSummary, !feedback.isEmpty {
                Text(feedback)
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var answerBadge: some View {
        switch assignment.arkStatus {
        case "done":
            if let studentAnswer = assignment.studentAnswer,
               let correctAnswer = assignment.correctAnswer,
               studentAnswer != correctAnswer {
                // Incorrect
                Text("\u{2717} \(studentAnswer)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(KvanteTheme.Colors.primary, in: Capsule())
            } else if let answer = assignment.studentAnswer ?? assignment.correctAnswer {
                // Correct
                Text("\u{2713} \(answer)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(KvanteTheme.Colors.success, in: Capsule())
            }
        default:
            Text("\u{2014}")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(KvanteTheme.Colors.textMuted, in: Capsule())
        }
    }

    private var accessibilityText: String {
        switch assignment.arkStatus {
        case "done":
            if let studentAnswer = assignment.studentAnswer,
               let correctAnswer = assignment.correctAnswer,
               studentAnswer != correctAnswer {
                return "Opgave: \(assignment.text). Dit svar: \(studentAnswer). Forkert. Rigtigt svar: \(correctAnswer)."
            } else if let answer = assignment.studentAnswer {
                return "Opgave: \(assignment.text). Dit svar: \(answer). Rigtigt."
            }
            return "Opgave: \(assignment.text)."
        default:
            return "Opgave: \(assignment.text). Ikke besvaret."
        }
    }
}

// MARK: - SeededRNG (reused from AssignmentSheetView pattern)

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
