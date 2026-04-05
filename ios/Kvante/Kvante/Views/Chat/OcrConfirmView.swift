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
                        .fill(Color(red: 0.3, green: 0.3, blue: 0.5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jeg har scannet dit billede!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Er det her rigtigt?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Reading card
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DIT SVAR")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)

                    if isEditing {
                        HStack {
                            TextField("Skriv dit svar", text: $correctedText)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Button {
                                let answer = correctedText.trimmingCharacters(in: .whitespaces)
                                if !answer.isEmpty { onConfirm(answer) }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                            .disabled(correctedText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        HStack {
                            Text(readText)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color(.systemGray6).opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
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
                        .background(Color(red: 0.2, green: 0.55, blue: 0.5), in: RoundedRectangle(cornerRadius: 14))
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
                            .background(Color(.systemGray5).opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Source
            Text(source)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(red: 0.14, green: 0.14, blue: 0.18), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
