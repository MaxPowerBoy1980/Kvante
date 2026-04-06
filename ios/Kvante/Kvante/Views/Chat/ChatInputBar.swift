import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCamera: () -> Void
    let onHelp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2)

            HStack(spacing: 10) {
                // + menu button
                Menu {
                    Button {
                        onCamera()
                    } label: {
                        Label("Scan mit svar", systemImage: "camera.fill")
                    }
                    Button {
                        onHelp()
                    } label: {
                        Label("Hjælp mig med opgaven", systemImage: "lightbulb.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(KvanteTheme.Colors.primary)
                }

                // Text field
                HStack(spacing: 8) {
                    TextField("Skriv til Kvante...", text: $text)
                        .font(.subheadline)
                        .foregroundStyle(KvanteTheme.Colors.textPrimary)
                        .submitLabel(.send)
                        .onSubmit { if !text.trimmingCharacters(in: .whitespaces).isEmpty { onSend() } }

                    Button(action: onCamera) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                            .foregroundStyle(KvanteTheme.Colors.mutedText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(KvanteTheme.Colors.muted, in: Capsule())

                // Send button
                Button {
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSend()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            text.trimmingCharacters(in: .whitespaces).isEmpty
                                ? KvanteTheme.Colors.sendInactive
                                : KvanteTheme.Colors.sendActive
                        )
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(KvanteTheme.Colors.backgroundStart.opacity(0.95))
        }
    }
}
