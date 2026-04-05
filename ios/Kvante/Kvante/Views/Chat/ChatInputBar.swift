import SwiftUI

struct ChatInputBar: View {
    let onCamera: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2)

            HStack(spacing: 12) {
                // Text field placeholder (non-functional for now — paper-first)
                HStack {
                    Text("Skriv dit svar her...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onCamera) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: Capsule())

                // Send / Camera button
                Button(action: onCamera) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}
