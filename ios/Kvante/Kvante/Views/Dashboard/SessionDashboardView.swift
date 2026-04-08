import SwiftUI

struct SessionDashboardView: View {
    let session: SessionSummary
    let onBack: () -> Void
    var onContinue: (() -> Void)? = nil
    var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Hjem")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(KvanteTheme.Colors.inkSubtle)
                    .frame(height: 1),
                alignment: .bottom
            )

            ScrollView {
                VStack(spacing: 20) {
                    // Session header
                    VStack(spacing: 8) {
                        Text(session.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(KvanteTheme.Colors.ink)

                        Text("\(session.completedCount) af \(session.assignmentCount) opgaver løst")
                            .font(.subheadline)
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(KvanteTheme.Colors.ink.opacity(0.1))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(KvanteTheme.Colors.success)
                                    .frame(
                                        width: geo.size.width * CGFloat(session.completedCount) / CGFloat(max(session.assignmentCount, 1)),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 40)

                        if session.isCompleted {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(KvanteTheme.Colors.success)
                                Text("Gennemført")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(KvanteTheme.Colors.success)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 20)

                    // Date
                    Text(session.displayDate)
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)

                    // Continue button — only shown if session is not yet completed
                    if let onContinue, !session.isCompleted {
                        Button(action: onContinue) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(isLoading ? "Henter…" : "Fortsæt session")
                                    .font(KvanteTheme.Fonts.buttonLabel)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
                        .disabled(isLoading)
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(KvanteTheme.Colors.cream)
        .toolbar(.hidden, for: .navigationBar)
    }
}
