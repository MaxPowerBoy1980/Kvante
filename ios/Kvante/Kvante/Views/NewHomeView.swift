import SwiftUI
import SwiftData

struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void
    let onWeekly: () -> Void
    let onNotebook: () -> Void
    let sessionHistory: [SessionSummary]
    let onTapSession: (SessionSummary) -> Void

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

    /// Most recent weekly session for mini-ark preview
    private var currentWeekly: SessionSummary? {
        sessionHistory.first { !$0.isCompleted } ?? sessionHistory.first
    }

    var body: some View {
        ZStack {
            KvanteTheme.Colors.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Welcome
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hej, \(profile.name)!")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(KvanteTheme.Colors.ink)

                        if let weekly = currentWeekly {
                            let remaining = weekly.assignmentCount - weekly.completedCount
                            Text("\(weekly.name) — du har \(remaining) opgave\(remaining == 1 ? "" : "r") tilbage")
                                .font(.system(size: 15))
                                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        } else {
                            Text("Klar til at blive skarpere til matematik?")
                                .font(.system(size: 15))
                                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Primary CTA: Weekly math
                    weeklyCard
                        .padding(.horizontal, 24)

                    // Secondary: Practice
                    practiceCard
                        .padding(.horizontal, 24)

                    // Notebook
                    notebookCard
                        .padding(.horizontal, 24)

                    // Server status
                    if serverDiscovery.serverURL == nil {
                        Text(serverDiscovery.isSearching
                            ? "Leder efter serveren..."
                            : "Ingen server fundet")
                            .font(.caption)
                            .foregroundStyle(KvanteTheme.Colors.textMuted)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - Weekly Card

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ugens matematik")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            if let weekly = currentWeekly {
                Text("Næste: \(weekly.name)")
                    .font(.system(size: 13))
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)

                // Mini-ark preview
                HStack(spacing: 8) {
                    ForEach(0..<weekly.assignmentCount, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(miniArkColor(index: i, completed: weekly.completedCount))
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(miniArkBorder(index: i, completed: weekly.completedCount), lineWidth: miniArkBorderWidth(index: i, completed: weekly.completedCount))
                            )
                            .overlay(miniArkLabel(index: i, completed: weekly.completedCount))
                    }
                }
            }

            Button(action: {
                if let weekly = currentWeekly {
                    onTapSession(weekly)
                } else {
                    onWeekly()
                }
            }) {
                Text(currentWeekly != nil ? "Fortsæt" : "Start ugens opgaver")
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

    // MARK: - Mini Ark Helpers

    private func miniArkColor(index: Int, completed: Int) -> Color {
        if index < completed {
            return KvanteTheme.Colors.success.opacity(0.1)
        } else if index == completed {
            return KvanteTheme.Colors.primary.opacity(0.1)
        }
        return KvanteTheme.Colors.ink.opacity(0.03)
    }

    private func miniArkBorder(index: Int, completed: Int) -> Color {
        if index < completed {
            return KvanteTheme.Colors.success.opacity(0.3)
        } else if index == completed {
            return KvanteTheme.Colors.primary.opacity(0.4)
        }
        return KvanteTheme.Colors.ink.opacity(0.12)
    }

    private func miniArkBorderWidth(index: Int, completed: Int) -> CGFloat {
        if index == completed { return 2 }
        return 1.5
    }

    @ViewBuilder
    private func miniArkLabel(index: Int, completed: Int) -> some View {
        if index < completed {
            Text("✓")
                .font(.system(size: 10))
                .foregroundStyle(KvanteTheme.Colors.success)
        } else if index == completed {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(KvanteTheme.Colors.primary)
        }
    }
}
