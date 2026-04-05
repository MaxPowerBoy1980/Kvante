import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCamera: () -> Void
    let onHelp: () -> Void

    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2)

            HStack(spacing: 10) {
                // + menu button
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                // Text field
                HStack(spacing: 8) {
                    TextField("Skriv til Kvante...", text: $text)
                        .font(.subheadline)
                        .submitLabel(.send)
                        .onSubmit { if !text.trimmingCharacters(in: .whitespaces).isEmpty { onSend() } }

                    Button(action: onCamera) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: Capsule())

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
                                ? Color(.systemGray4)
                                : .blue
                        )
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .confirmationDialog("Hvad vil du gøre?", isPresented: $showMenu) {
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
            Button("Annuller", role: .cancel) {}
        }
    }
}
