import SwiftUI

struct ActionChip: View {
    let model: ActionChipModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(model.label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    model.isPrimary
                        ? AnyShapeStyle(Color(red: 0.2, green: 0.55, blue: 0.5))
                        : AnyShapeStyle(Color(.systemGray5).opacity(0.5))
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
