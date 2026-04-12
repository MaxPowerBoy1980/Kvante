import SwiftUI

extension Notification.Name {
    static let kvanteCelebration = Notification.Name("kvanteCelebration")
}

struct KvanteHeaderBar: View {
    var session: SessionViewModel?
    var onNavigateHome: (() -> Void)? = nil
    var homeExpression: KvanteExpression = .neutral
    var showHomeDots: Bool = true
    @State private var isExpanded = false
    @State private var celebratingDotIndex: Int? = nil
    @State private var expression: KvanteExpression = .neutral

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
                .contentShape(Rectangle())
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
        .onChange(of: session?.isSetComplete) { _, _ in
            if session == nil {
                expression = homeExpression
            }
        }
        .onChange(of: homeExpression) { _, newValue in
            if session == nil {
                expression = newValue
            }
        }
        .onAppear {
            if session == nil {
                expression = homeExpression
            }
        }
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack(spacing: 12) {
            KvanteFace(expression: expression, size: 28)
                .clipped()
                #if DEBUG
                .onLongPressGesture {
                    NotificationCenter.default.post(name: .devCaptureRequested, object: nil)
                }
                #endif

            if let session {
                ProgressDotsView(
                    total: session.totalAssignments,
                    completedIds: Set(session.statusByAssignment.filter { $0.value == .done }.map(\.key)),
                    currentIndex: session.currentAssignmentIndex,
                    assignmentIds: session.assignments.map(\.id),
                    celebratingIndex: celebratingDotIndex
                )
            } else if showHomeDots {
                ProgressDotsView(
                    total: 6,
                    completedIds: [],
                    currentIndex: -1,
                    assignmentIds: [],
                    celebratingIndex: nil
                )
            }

            Spacer()

            #if DEBUG
            Text(Self.buildLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(KvanteTheme.Colors.textMuted.opacity(0.5))
            #endif

            StreakBadge(streak: session?.currentStreak ?? 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    #if DEBUG
    private static let buildLabel: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version)b\(build)"
    }()
    #endif

    // MARK: - Expanded

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let session {
                // Session active — progress + streak
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

                // Home button (icon)
                if onNavigateHome != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) { isExpanded = false }
                        onNavigateHome?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                            Text("Hjem")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(KvanteTheme.Colors.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(KvanteTheme.Colors.muted)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // No session — no welcome text (B1: welcome lives in mainCard)
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
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
