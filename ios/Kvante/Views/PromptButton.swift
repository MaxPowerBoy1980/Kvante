import SwiftUI

struct PromptButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        PromptButton(title: "Vis mig et eksempel", icon: "lightbulb.fill", color: .orange) {}
        PromptButton(title: "Scan mit svar", icon: "camera.fill", color: .blue) {}
        PromptButton(title: "Næste opgave", icon: "arrow.right.circle.fill", color: .green) {}
    }
    .padding()
}
