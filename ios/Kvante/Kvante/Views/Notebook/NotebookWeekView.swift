import SwiftUI

/// One week page in the notebook. Shows sessions grouped by type, collapsible.
struct NotebookWeekView: View {
    let week: NotebookWeek
    let viewModel: NotebookViewModel
    let apiClient: APIClient
    let pageLabel: String

    @State private var weeklyGroups: [NotebookSessionGroup] = []
    @State private var practiceGroups: [NotebookSessionGroup] = []
    @State private var isLoading = true
    @State private var selectedAssignment: NotebookAssignment?
    @State private var expandedSessions: Set<String> = []

    var body: some View {
        ZStack {
            paperBackground

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    weekHeader
                        .padding(.horizontal, 24)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        // Weekly sessions
                        if !weeklyGroups.isEmpty {
                            sectionLabel("Ugematematik")
                            ForEach(weeklyGroups) { group in
                                SessionGroupCard(
                                    group: group,
                                    isExpanded: expandedSessions.contains(group.id),
                                    onToggle: { toggleExpanded(group.id) },
                                    onTapAssignment: { selectedAssignment = $0 }
                                )
                                .padding(.horizontal, 24)
                            }
                        }

                        // Practice sessions
                        if !practiceGroups.isEmpty {
                            sectionLabel("Ekstra øvelser")
                            ForEach(practiceGroups) { group in
                                SessionGroupCard(
                                    group: group,
                                    isExpanded: expandedSessions.contains(group.id),
                                    onToggle: { toggleExpanded(group.id) },
                                    onTapAssignment: { selectedAssignment = $0 }
                                )
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            let result = viewModel.sessionGroups(for: week)
            weeklyGroups = result.weekly
            practiceGroups = result.practice
            isLoading = false
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentDetailSheet(assignment: assignment, apiClient: apiClient)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(KvanteTheme.Colors.textMuted)
            .padding(.horizontal, 24)
            .padding(.top, 4)
    }

    private func toggleExpanded(_ id: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSessions.contains(id) {
                expandedSessions.remove(id)
            } else {
                expandedSessions.insert(id)
            }
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

// MARK: - Session Group Card

/// A collapsible card showing one session's assignments.
struct SessionGroupCard: View {
    let group: NotebookSessionGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    let onTapAssignment: (NotebookAssignment) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header — always visible, entire row tappable
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    // Progress indicator
                    ZStack {
                        Circle()
                            .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 2)
                            .frame(width: 32, height: 32)
                        if group.solvedCount == group.totalCount && group.totalCount > 0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(KvanteTheme.Colors.success)
                        } else {
                            Text("\(group.solvedCount)/\(group.totalCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                            .lineLimit(1)
                        if !group.date.isEmpty {
                            Text(group.date)
                                .font(.system(size: 11))
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(SessionHeaderButtonStyle())

            // Expanded: show facit cards
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 8) {
                    ForEach(group.assignments) { assignment in
                        FacitCard(assignment: assignment)
                            .onTapGesture { onTapAssignment(assignment) }
                    }
                }
                .padding(14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(group.name). \(group.solvedCount) af \(group.totalCount) løst.")
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
               let correctAnswer = assignment.correctAnswer {
                if studentAnswer == correctAnswer {
                    // Correct
                    Text("✓ \(studentAnswer)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(KvanteTheme.Colors.success, in: Capsule())
                } else {
                    // Incorrect
                    Text("✗ \(studentAnswer)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(KvanteTheme.Colors.primary, in: Capsule())
                }
            } else if let studentAnswer = assignment.studentAnswer {
                // Has answer but no correct_answer in DB — can't verify, show orange
                Text(studentAnswer)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(KvanteTheme.Colors.primary, in: Capsule())
            } else if let correctAnswer = assignment.correctAnswer {
                // Done but no student answer recorded — show correct answer as green
                Text("✓ \(correctAnswer)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(KvanteTheme.Colors.success, in: Capsule())
            }
        default:
            Text("—")
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
               let correctAnswer = assignment.correctAnswer {
                if studentAnswer == correctAnswer {
                    return "Opgave: \(assignment.text). Dit svar: \(studentAnswer). Rigtigt."
                } else {
                    return "Opgave: \(assignment.text). Dit svar: \(studentAnswer). Forkert. Rigtigt svar: \(correctAnswer)."
                }
            } else if let studentAnswer = assignment.studentAnswer {
                return "Opgave: \(assignment.text). Dit svar: \(studentAnswer)."
            }
            return "Opgave: \(assignment.text). Løst."
        default:
            return "Opgave: \(assignment.text). Ikke besvaret."
        }
    }
}

// MARK: - Button Style

/// Gives subtle opacity feedback when pressing session header.
private struct SessionHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
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
