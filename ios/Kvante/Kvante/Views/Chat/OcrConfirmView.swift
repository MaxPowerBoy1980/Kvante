import SwiftUI

struct OcrConfirmView: View {
    let readText: String
    let source: String
    let onConfirm: (String) -> Void

    @State private var isEditing = false
    @State private var correctedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // What Kvante read
            Text("Jeg læste:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(readText)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            Text("Er det rigtigt?")
                .font(.subheadline)

            if isEditing {
                // Correction mode
                HStack(spacing: 10) {
                    TextField("Skriv dit svar", text: $correctedText)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        let answer = correctedText.trimmingCharacters(in: .whitespaces)
                        if !answer.isEmpty {
                            onConfirm(answer)
                        }
                    } label: {
                        Text("OK")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                    .disabled(correctedText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                // Confirm / Correct buttons
                HStack(spacing: 12) {
                    Button {
                        onConfirm(readText)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                            Text("Ja, det er rigtigt")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        correctedText = readText
                        isEditing = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("Nej, ret")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Source label
            Text(source)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
