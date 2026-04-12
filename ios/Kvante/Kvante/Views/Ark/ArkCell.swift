import SwiftUI

struct ArkCell: View {
    let assignment: ParsedAssignment
    let index: Int
    let status: ArkStatus
    let scanId: String?
    let feedbackSummary: String?
    let errorDescription: String?
    let isCurrent: Bool
    let apiClient: APIClient
    let onTap: () -> Void
    let onFeedbackTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Cell head
                cellHead
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                Divider()
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                // Visual slot
                visualSlot
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)

                // Cell foot
                cellFoot
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .background(cellBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(cellBorder)
            .overlay(currentOverlay)
            .shadow(
                color: isCurrent ? KvanteTheme.Colors.primary.opacity(0.20) : .clear,
                radius: isCurrent ? 6 : 0,
                y: isCurrent ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cell Head

    private var cellHead: some View {
        HStack {
            Text("OPG \(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(KvanteTheme.Colors.textMuted)

            Spacer()

            Text(assignment.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineLimit(1)
        }
    }

    // MARK: - Visual Slot

    @ViewBuilder
    private var visualSlot: some View {
        switch status {
        case .done:
            if let scanId {
                ScannedImageView(
                    data: nil,
                    scanId: scanId,
                    apiClient: apiClient,
                    maxPixelSize: 400
                )
            } else {
                statusPlaceholder(icon: "checkmark.circle.fill", text: "Løst", color: KvanteTheme.Colors.success)
            }

        case .inProgress:
            if let scanId {
                ZStack {
                    ScannedImageView(
                        data: nil,
                        scanId: scanId,
                        apiClient: apiClient,
                        maxPixelSize: 400
                    )
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("I gang")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(KvanteTheme.Colors.primary)
                                )
                            Spacer()
                        }
                    }
                }
            } else {
                statusPlaceholder(icon: "pencil.circle", text: "Du arbejder på den...", color: KvanteTheme.Colors.primary)
            }

        case .notStarted:
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(KvanteTheme.Colors.inkSubtle)
                .overlay(
                    Text("Tryk for at løse")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                )
        }
    }

    private func statusPlaceholder(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(KvanteTheme.Colors.textMuted)
        }
    }

    // MARK: - Cell Foot

    private var cellFoot: some View {
        HStack(spacing: 6) {
            // Status badge
            switch status {
            case .done:
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                    Text("løst")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(KvanteTheme.Colors.success)

            case .inProgress:
                HStack(spacing: 3) {
                    Image(systemName: "pencil")
                        .font(.caption2.weight(.bold))
                    Text("i gang")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(KvanteTheme.Colors.primary)

            case .notStarted:
                EmptyView()
            }

            // Error description (shown when status is not done and error is present)
            if status != .done, let errorDescription {
                Text(errorDescription)
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.primary)
                    .lineLimit(2)
            } else if let feedbackSummary {
                // Feedback teaser
                Text(feedbackSummary)
                    .font(.caption2.italic())
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            // Info button (feedback preview or error detail)
            if feedbackSummary != nil || (status != .done && errorDescription != nil) {
                Button(action: onFeedbackTap) {
                    Image(systemName: "info.circle.fill")
                        .font(.body)
                        .foregroundStyle(KvanteTheme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Styling

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(backgroundFill)
    }

    private var backgroundFill: Color {
        switch status {
        case .notStarted: return KvanteTheme.Colors.cream
        case .inProgress: return KvanteTheme.Colors.primary.opacity(0.08)
        case .done: return KvanteTheme.Colors.success.opacity(0.08)
        }
    }

    @ViewBuilder
    private var cellBorder: some View {
        if isCurrent {
            // currentOverlay handles the border when this is the active assignment
            EmptyView()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: borderWidth)
        }
    }

    private var borderColor: Color {
        switch status {
        case .notStarted: return KvanteTheme.Colors.inkSubtle
        case .inProgress: return KvanteTheme.Colors.primary
        case .done: return KvanteTheme.Colors.success
        }
    }

    private var borderWidth: CGFloat {
        switch status {
        case .notStarted: return 1
        case .inProgress: return 2
        case .done: return 1.5
        }
    }

    @ViewBuilder
    private var currentOverlay: some View {
        if isCurrent {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(KvanteTheme.Colors.primary, lineWidth: 2)

                // Current indicator dot
                Circle()
                    .fill(KvanteTheme.Colors.primary)
                    .frame(width: 8, height: 8)
                    .offset(x: 6, y: 6)
            }
        }
    }
}
