import SwiftUI

struct BulkScanFeedbackCard: View {
    let results: [BulkSubmitResult]
    let summary: BulkSubmitSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text("Kvante har tjekket dit ark")
                    .font(.headline)
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(results) { result in
                    HStack(spacing: 8) {
                        statusIcon(for: result.status)
                        Text(resultText(for: result))
                            .font(.subheadline)
                            .foregroundStyle(resultColor(for: result.status))
                    }
                }
            }

            Divider()

            Text(summaryText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.ink)

            if summary.incorrect > 0 || summary.uncertain > 0 {
                Text("Tap på en opgave på arket for at se mere")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(KvanteTheme.Colors.cream, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(KvanteTheme.Colors.inkSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        switch status {
        case "correct":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(KvanteTheme.Colors.success)
        case "incorrect":
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(KvanteTheme.Colors.primary)
        case "uncertain":
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.blue)
        default:
            Image(systemName: "minus.circle")
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
        }
    }

    private func resultText(for result: BulkSubmitResult) -> String {
        let base = result.assignmentText
        switch result.status {
        case "correct":
            return "\(base) = \(result.studentAnswer ?? "?")"
        case "incorrect":
            return "\(base) — \(result.errorDescription ?? "forkert")"
        case "uncertain":
            return "\(base) — kan ikke læse"
        default:
            return "\(base) — ikke fundet"
        }
    }

    private func resultColor(for status: String) -> Color {
        switch status {
        case "correct": return KvanteTheme.Colors.ink
        case "incorrect": return KvanteTheme.Colors.primary
        case "uncertain": return .blue
        default: return KvanteTheme.Colors.textSecondary
        }
    }

    private var summaryText: String {
        if summary.correct == summary.total {
            return "Alle \(summary.total) rigtige!"
        }
        return "\(summary.correct) af \(summary.total) rigtige"
    }
}
