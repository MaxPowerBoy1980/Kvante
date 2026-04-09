import SwiftUI

extension Notification.Name {
    static let kvanteCelebration = Notification.Name("kvanteCelebration")
}

struct KvanteHeaderBar: View {
    var session: SessionViewModel?
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

            StreakBadge(streak: 0)  // Hardcoded until PR 2

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
                        Text("0 dage")  // Hardcoded until PR 2
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                    }
                }

                if !session.isSetComplete {
                    let next = session.currentAssignment
                    let idx = session.currentAssignmentIndex
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(KvanteTheme.Colors.primary.opacity(0.1))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(idx + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(KvanteTheme.Colors.primary)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(next.text)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(KvanteTheme.Colors.ink)
                                .lineLimit(1)
                            Text("Næste opgave")
                                .font(.system(size: 12))
                                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Text("Løs →")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(KvanteTheme.Colors.teal)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                            )
                    )
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
