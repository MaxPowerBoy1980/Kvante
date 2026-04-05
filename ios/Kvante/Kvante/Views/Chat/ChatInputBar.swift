import SwiftUI

struct ChatInputBar: View {
    let onCamera: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                Spacer()

                Button(action: onCamera) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                        Text("Scan mit svar")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}
