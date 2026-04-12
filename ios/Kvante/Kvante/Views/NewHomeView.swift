import SwiftUI
import SwiftData

struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void
    let onNotebook: () -> Void
    let sessionHistory: [SessionSummary]
    let onTapSession: (SessionSummary) -> Void

    @State private var chipFeedbackSession: SessionViewModel?
    @State private var chipFeedbackItem: ArkFeedbackItem?
    @State private var isLoadingChipFeedback = false

    private var notebookSolvedCount: Int {
        sessionHistory.reduce(0) { $0 + $1.completedCount }
    }

    private var notebookWeekCount: Int {
        let calendar = Calendar(identifier: .iso8601)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        var weeks = Set<String>()
        for s in sessionHistory {
            if let date = formatter.date(from: s.createdAt) {
                let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                if let y = comps.yearForWeekOfYear, let w = comps.weekOfYear {
                    weeks.insert("\(y)-W\(w)")
                }
            }
        }
        return weeks.count
    }

    /// First incomplete weekly session — drives tilstand 1
    /// Prioritises in-progress (completedCount > 0) over fresh (0 completed).
    /// Fresh sessions only count as active if there's no completed session to celebrate.
    private var activeWeekly: SessionSummary? {
        // 1. Session with actual progress (started but not finished)
        let inProgress = sessionHistory.first {
            $0.mode == "weekly" && $0.completedCount > 0
                && $0.completedCount < $0.assignmentCount && !$0.isCompleted
        }
        if let inProgress { return inProgress }

        // 2. Fresh session (0 completed) — only if nothing to celebrate
        let hasCompleted = sessionHistory.contains {
            $0.mode == "weekly" && ($0.isCompleted || $0.completedCount >= $0.assignmentCount)
        }
        if hasCompleted { return nil }

        return sessionHistory.first {
            $0.mode == "weekly" && $0.completedCount == 0 && !$0.isCompleted
        }
    }

    /// Most recent completed weekly session — drives tilstand 2
    private var completedWeekly: SessionSummary? {
        sessionHistory.first {
            $0.mode == "weekly" && ($0.isCompleted || $0.completedCount >= $0.assignmentCount)
        }
    }

    /// Show exercises card only in tilstand 1 (active weekly, not yet solved)
    private var showExercises: Bool {
        activeWeekly != nil
    }

    var body: some View {
        ZStack {
            KvanteTheme.Colors.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    mainCard

                    // "Se dit arbejde" link — only in tilstand 2 (triumf)
                    if activeWeekly == nil, completedWeekly != nil {
                        Button(action: onNotebook) {
                            Text("Se hvad du har lavet →")
                                .font(.system(size: 13))
                                .foregroundStyle(KvanteTheme.Colors.robBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    if showExercises {
                        practiceCard
                    }

                    notebookCard

                    // Server status
                    if serverDiscovery.serverURL == nil {
                        Text(serverDiscovery.isSearching
                            ? "Leder efter serveren..."
                            : "Ingen server fundet")
                            .font(.caption)
                            .foregroundStyle(KvanteTheme.Colors.textMuted)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(item: $chipFeedbackItem) { item in
            if let session = chipFeedbackSession,
               let serverURL = serverDiscovery.serverURL {
                let assignmentId = item.assignment.id
                FeedbackSheet(
                    assignmentId: assignmentId,
                    assignmentText: item.assignment.text,
                    assignmentIndex: item.index,
                    status: {
                        let s = session.statusByAssignment[assignmentId] ?? .notStarted
                        switch s {
                        case .done: return "done"
                        case .inProgress: return "in_progress"
                        case .notStarted: return "not_started"
                        }
                    }(),
                    errorType: session.errorType[assignmentId],
                    studentAnswer: session.studentAnswer[assignmentId],
                    scanId: session.latestScanId[assignmentId],
                    cropRegion: session.boundingBoxByAssignment[assignmentId],
                    gearScore: session.gearScoreByAssignment[assignmentId],
                    improvementTip: session.improvementTipByAssignment[assignmentId],
                    feedbackSummary: session.feedbackSummary[assignmentId],
                    submissionId: session.submissionIdByAssignment[assignmentId],
                    isHistorical: true,
                    apiClient: APIClient(baseURL: serverURL)
                )
            }
        }
    }

    // MARK: - Main Card (three states)

    @ViewBuilder
    private var mainCard: some View {
        if let active = activeWeekly {
            activeWeeklyCard(active)
        } else if let completed = completedWeekly {
            triumfCard(completed)
        } else {
            emptyCard
        }
    }

    // MARK: - Tilstand 1: Midt i ugen

    private func activeWeeklyCard(_ weekly: SessionSummary) -> some View {
        VStack(spacing: 14) {
            Image("rob2")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text("Opgave \(weekly.completedCount + 1) af \(weekly.assignmentCount)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("\(weekly.name)")
                .font(.system(size: 13))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            // Progress chips
            progressChips(
                total: weekly.assignmentCount,
                completed: weekly.completedCount,
                sessionId: weekly.sessionId
            )

            Button(action: { onTapSession(weekly) }) {
                Text("Fortsæt opgave \(weekly.completedCount + 1)")
                    .font(KvanteTheme.Fonts.buttonLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
            .disabled(serverDiscovery.serverURL == nil)
            .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
    }

    // MARK: - Tilstand 2: Alt er løst (triumf)

    private func triumfCard(_ weekly: SessionSummary) -> some View {
        VStack(spacing: 10) {
            Image("rob2_happy")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            // Lyn-zigzag (statisk i denne sprint)
            Text("⚡⚡⚡")
                .font(.system(size: 18))
                .foregroundStyle(KvanteTheme.Colors.primary)

            Text("Uge \(weekNumber(from: weekly)) er i hus!")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("\(weekly.assignmentCount) af \(weekly.assignmentCount) opgaver — flot arbejde")
                .font(.system(size: 13))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            // All done chips
            progressChips(
                total: weekly.assignmentCount,
                completed: weekly.assignmentCount,
                sessionId: weekly.sessionId
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .fill(
                    LinearGradient(
                        colors: [.white, KvanteTheme.Colors.triumphGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                        .stroke(KvanteTheme.Colors.primary.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
    }

    // MARK: - Tilstand 3: Ingen aktiv uge

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image("rob2")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text("Ingen nye opgaver endnu")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.textPrimary.opacity(0.5))

            Text("Der er ingen nye opgaver til dig endnu. Tjek igen snart!")
                .font(.system(size: 14))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                        .stroke(KvanteTheme.Colors.robBlue.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                )
        )
    }

    // MARK: - Practice Card

    private var practiceCard: some View {
        Button(action: onPractice) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(KvanteTheme.Colors.teal.opacity(0.1))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "dumbbell")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(KvanteTheme.Colors.teal)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ekstra øvelser")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KvanteTheme.Colors.ink)
                    Text("Træn det du har sværest ved")
                        .font(.system(size: 12))
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                            .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(serverDiscovery.serverURL == nil)
        .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
    }

    // MARK: - Notebook Card

    private var notebookCard: some View {
        Button(action: onNotebook) {
            HStack(spacing: 14) {
                // Mini book cover
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KvanteTheme.Colors.cream)
                        .frame(width: 42, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
                        )
                    // Mini book spine
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color(red: 0.91, green: 0.87, blue: 0.82), KvanteTheme.Colors.cream],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 5)
                        Spacer()
                    }
                    .frame(width: 42, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Mini Kvante
                    KvanteFace(expression: .happy)
                        .frame(width: 18, height: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Din matematikbog")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KvanteTheme.Colors.ink)
                    Text("\(profile.name) & Kvante — \(notebookSolvedCount) opgaver løst")
                        .font(.system(size: 12))
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)

                    if notebookSolvedCount > 0 {
                        HStack(spacing: 12) {
                            Text("\(notebookWeekCount) uger")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(KvanteTheme.Colors.teal)
                            Text("\(notebookSolvedCount) løst")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(KvanteTheme.Colors.success)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                            .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(serverDiscovery.serverURL == nil)
        .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
        .accessibilityLabel("Din matematikbog. \(notebookSolvedCount) opgaver løst")
    }

    // MARK: - Progress Chips

    private func progressChips(total: Int, completed: Int, sessionId: String) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                let isDone = i < completed
                let isCurrent = i == completed && completed < total

                RoundedRectangle(cornerRadius: 6)
                    .fill(chipFill(isDone: isDone, isCurrent: isCurrent))
                    .frame(height: 28)
                    .frame(maxWidth: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(chipBorder(isDone: isDone, isCurrent: isCurrent),
                                    lineWidth: isCurrent ? 2 : 1.5)
                    )
                    .overlay(chipLabel(index: i, isDone: isDone, isCurrent: isCurrent))
                    .onTapGesture {
                        if isDone {
                            loadFeedbackForChip(sessionId: sessionId, chipIndex: i)
                        }
                    }
            }
        }
    }

    private func chipFill(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return KvanteTheme.Colors.robBlue }
        if isCurrent { return KvanteTheme.Colors.primary.opacity(0.1) }
        return KvanteTheme.Colors.ink.opacity(0.03)
    }

    private func chipBorder(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return KvanteTheme.Colors.robBlue }
        if isCurrent { return KvanteTheme.Colors.primary.opacity(0.4) }
        return KvanteTheme.Colors.ink.opacity(0.12)
    }

    @ViewBuilder
    private func chipLabel(index: Int, isDone: Bool, isCurrent: Bool) -> some View {
        if isDone {
            Text("✓")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        } else if isCurrent {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(KvanteTheme.Colors.primary)
        } else {
            Text("\(index + 1)")
                .font(.system(size: 11))
                .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.3))
        }
    }

    /// Extract week number from session name (e.g. "Uge 15 — Addition" → "15")
    private func weekNumber(from session: SessionSummary) -> String {
        let name = session.name
        if let range = name.range(of: #"Uge (\d+)"#, options: .regularExpression) {
            let match = name[range]
            return match.replacingOccurrences(of: "Uge ", with: "")
        }
        return name
    }

    // MARK: - Chip Tap → FeedbackSheet

    private func loadFeedbackForChip(sessionId: String, chipIndex: Int) {
        guard let serverURL = serverDiscovery.serverURL else { return }
        isLoadingChipFeedback = true
        Task {
            do {
                let client = APIClient(baseURL: serverURL)
                let response = try await client.getSession(sessionId: sessionId)
                let session = SessionViewModel(from: response)
                chipFeedbackSession = session
                let assignment = session.assignments[chipIndex]
                chipFeedbackItem = ArkFeedbackItem(
                    id: assignment.id,
                    assignment: assignment,
                    index: chipIndex
                )
            } catch {
                print("Failed to load chip feedback: \(error)")
            }
            isLoadingChipFeedback = false
        }
    }
}
