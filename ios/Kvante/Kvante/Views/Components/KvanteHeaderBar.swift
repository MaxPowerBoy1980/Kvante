import SwiftUI

extension Notification.Name {
    static let kvanteCelebration = Notification.Name("kvanteCelebration")
}

struct KvanteHeaderBar: View {
    var session: SessionViewModel?
    var onNavigateHome: (() -> Void)? = nil
    var onNavigateToAssignment: (() -> Void)? = nil
    @State private var isExpanded = false
    @State private var celebratingDotIndex: Int? = nil
    @State private var expression: KvanteExpression = .neutral

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
                .onTapGesture { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }

            if isExpanded {
                expandedPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider().opacity(0.3)
        }
        .background(isExpanded ? Color.white.opacity(0.98) : Color.white)
        .onReceive(NotificationCenter.default.publisher(for: .kvanteCelebration)) { notification in
            guard let info = notification.userInfo,
                  let index = info["assignmentIndex"] as? Int,
                  let isSetComplete = info["isSetComplete"] as? Bool else { return }
            handleCelebration(assignmentIndex: index, isSetComplete: isSetComplete)
        }
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack(spacing: 12) {
            KvanteFace(expression: expression, size: 34)
                .padding(.leading, 4)

            if let session {
                ProgressDotsView(
                    total: session.totalAssignments,
                    completedIds: Set(session.statusByAssignment.filter { $0.value == .done }.map(\.key)),
                    currentIndex: session.currentAssignmentIndex,
                    assignmentIds: session.assignments.map(\.id),
                    celebratingIndex: celebratingDotIndex
                )
            } else {
                ProgressDotsView(
                    total: 6,
                    completedIds: [],
                    currentIndex: -1,
                    assignmentIds: [],
                    celebratingIndex: nil
                )
            }

            Spacer()

            StreakBadge(streak: session?.currentStreak ?? 0)

            if isExpanded {
                Button { withAnimation(.spring(response: 0.3)) { isExpanded = false } } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Expanded

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session {
                // Session active — show progress + next assignment
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressDotsView(
                            total: session.totalAssignments,
                            completedIds: Set(session.statusByAssignment.filter { $0.value == .done }.map(\.key)),
                            currentIndex: session.currentAssignmentIndex,
                            assignmentIds: session.assignments.map(\.id),
                            dotSize: 16,
                            spacing: 7
                        )
                        Text("\(session.sessionName) — \(session.completedCount) af \(session.totalAssignments) løst")
                            .font(.caption)
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("🔥").font(.title2)
                        Text("\(session.currentStreak) dage")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                    }
                }

                // Next assignment card — bigger and tappable
                if !session.isSetComplete {
                    let next = session.currentAssignment
                    let idx = session.currentAssignmentIndex
                    Button {
                        withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        onNavigateToAssignment?()
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KvanteTheme.Colors.primary.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text("\(idx + 1)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(KvanteTheme.Colors.primary)
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(next.text)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(KvanteTheme.Colors.ink)
                                    .lineLimit(1)
                                Text("Næste opgave")
                                    .font(.system(size: 13))
                                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Text("Løs →")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(KvanteTheme.Colors.teal)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Home link
                if onNavigateHome != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        onNavigateHome?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Hjem")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(KvanteTheme.Colors.ink)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No session — show welcome message
                HStack(spacing: 12) {
                    KvanteFace(expression: .happy, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Klar til matematik?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                        Text("Vælg ugens opgaver eller øvelser nedenfor")
                            .font(.system(size: 13))
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [KvanteTheme.Colors.kvanteFace.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Celebration

    private func handleCelebration(assignmentIndex: Int, isSetComplete: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + KvanteTheme.Celebration.headerDelay) {
            withAnimation {
                expression = isSetComplete ? .excited : .happy
                celebratingDotIndex = assignmentIndex
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    expression = .neutral
                    celebratingDotIndex = nil
                }
            }
        }
    }
}
