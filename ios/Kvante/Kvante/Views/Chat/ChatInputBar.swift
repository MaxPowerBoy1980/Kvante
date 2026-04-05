import SwiftUI

struct ChatInputBar: View {
    let onCamera: () -> Void
    let onHelp: () -> Void

    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2)

            HStack(spacing: 12) {
                // + menu button
                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                // Text field placeholder
                HStack {
                    Text("Skriv dit svar her...")
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray3))
                    Spacer()
                    Button(action: onCamera) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: Capsule())

                // Send button (triggers camera for now)
                Button(action: onCamera) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
