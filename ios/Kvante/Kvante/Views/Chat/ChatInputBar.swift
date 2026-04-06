import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCamera: () -> Void
    let onHelp: () -> Void
    var onExplainDifferent: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // + button
                Menu {
                    Button { onCamera() } label: {
                        Label("Scan mit svar", systemImage: "camera")
                    }
                    Button { onHelp() } label: {
                        Label("Vis eksempel", systemImage: "lightbulb")
                    }
                    if let explain = onExplainDifferent {
                        Button { explain() } label: {
                            Label("Forklar anderledes", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    if let skip = onSkip {
                        Button { skip() } label: {
                            Label("Spring over", systemImage: "forward")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                        .frame(width: 44, height: 44)
                }

                // Text field
                TextField("Skriv dit svar her...", text: $text)
                    .font(.body)
                    .foregroundStyle(KvanteTheme.Colors.ink)
                    .submitLabel(.send)
                    .onSubmit { if !text.trimmingCharacters(in: .whitespaces).isEmpty { onSend() } }

                // Send button
                Button {
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty { onSend() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            text.trimmingCharacters(in: .whitespaces).isEmpty
                                ? KvanteTheme.Colors.sendInactive
                                : KvanteTheme.Colors.sendActive,
                            in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                        )
                        .shadow(
                            color: text.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .clear
                                : KvanteTheme.Colors.primaryShadow,
                            radius: 0, y: KvanteTheme.Shapes.buttonShadowHeight
                        )
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.inputRadius)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.inputRadius)
                            .stroke(KvanteTheme.Colors.inkSubtle, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KvanteTheme.Colors.cream)
    }
}
