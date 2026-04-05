import SwiftUI

struct ActionChip: View {
    let model: ActionChipModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: model.icon)
                    .font(.system(size: 12))
                Text(model.label)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                model.isPrimary
                    ? AnyShapeStyle(Color.orange)
                    : AnyShapeStyle(Color(.systemGray5))
            )
            .foregroundStyle(model.isPrimary ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
