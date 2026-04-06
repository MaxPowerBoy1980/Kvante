import SwiftUI

struct OcrConfirmView: View {
    let readText: String
    let source: String
    let onConfirm: (String) -> Void

    @State private var isEditing = false
    @State private var correctedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(KvanteTheme.Colors.kvanteAvatar)
                        .frame(width: 36, height: 36)
                    Text("🤖")
                        .font(.system(size: 16))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jeg har scannet dit billede!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.textPrimary)
                    Text("Er det her rigtigt?")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                }
            }

            // Reading card
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DIT SVAR")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(KvanteTheme.Colors.success)

                    if isEditing {
                        HStack {
                            TextField("Skriv dit svar", text: $correctedText)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(KvanteTheme.Colors.textPrimary)
                            Button {
                                let answer = correctedText.trimmingCharacters(in: .whitespaces)
                                if !answer.isEmpty { onConfirm(answer) }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(KvanteTheme.Colors.success)
                            }
                            .disabled(correctedText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        HStack {
                            Text(readText)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(KvanteTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(KvanteTheme.Colors.mutedText)
                        }
                    }
                }
                .padding(14)
                .background(KvanteTheme.Colors.muted, in: RoundedRectangle(cornerRadius: 14))
            }

            // Buttons
            if !isEditing {
                VStack(spacing: 10) {
                    Button {
                        onConfirm(readText)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.body)
                            Text("Ja, det er rigtigt")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KvanteTheme.Colors.success, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        correctedText = readText
                        isEditing = true
                    } label: {
                        Text("Nej, lad mig rette")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KvanteTheme.Colors.muted, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(KvanteTheme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Source
            Text(source)
                .font(.caption2)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
        )
    }
}
