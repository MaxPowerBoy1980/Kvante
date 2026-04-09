import SwiftUI

/// Progress dots inspired by Kvante plush's breast panel.
/// Blue for solved, orange for current, dashed for unsolved.
struct ProgressDotsView: View {
    let total: Int
    let completedIds: Set<String>
    let currentIndex: Int
    let assignmentIds: [String]
    var dotSize: CGFloat = 9
    var spacing: CGFloat = 5

    /// Which dot just completed — triggers pulse animation
    var celebratingIndex: Int? = nil

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<total, id: \.self) { i in
                let assignmentId = i < assignmentIds.count ? assignmentIds[i] : ""
                let isDone = completedIds.contains(assignmentId)
                let isCurrent = i == currentIndex && !isDone
                let isCelebrating = i == celebratingIndex

                Circle()
                    .fill(dotColor(isDone: isDone, isCurrent: isCurrent))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                KvanteTheme.Colors.kvanteDotBlue.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                            )
                            .opacity(isDone || isCurrent ? 0 : 1)
                    )
                    .scaleEffect(isCelebrating ? 1.3 : 1.0)
                    .shadow(
                        color: isCelebrating ? KvanteTheme.Colors.kvanteDotBlue.opacity(0.5) : .clear,
                        radius: isCelebrating ? 4 : 0
                    )
                    .animation(
                        isCelebrating
                            ? .spring(response: KvanteTheme.Celebration.dotPulseDuration, dampingFraction: 0.5)
                            : .default,
                        value: isCelebrating
                    )
            }
        }
    }

    private func dotColor(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return KvanteTheme.Colors.kvanteDotBlue }
        if isCurrent { return KvanteTheme.Colors.primary }
        return KvanteTheme.Colors.kvanteDotBlue.opacity(0.15)
    }
}
