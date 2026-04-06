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
                        ? AnyShapeStyle(KvanteTheme.Colors.primary)
                        : AnyShapeStyle(KvanteTheme.Colors.muted)
                )
                .foregroundStyle(
                    model.isPrimary
                        ? Color.white
                        : KvanteTheme.Colors.textPrimary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
