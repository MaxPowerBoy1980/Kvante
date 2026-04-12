import SwiftUI

/// Displays 0-6 filled icons representing the quality score.
/// TODO: Replace star.fill with custom tandhjul pixelart from Max (28×28pt @2x PNG)
struct GearRatingView: View {
    let score: Int
    let maxScore: Int = 6

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<maxScore, id: \.self) { index in
                Image(systemName: index < score ? "star.fill" : "star")
                    .font(.system(size: 22))
                    .foregroundStyle(index < score ? KvanteTheme.Colors.primary : Color(.systemGray4))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GearRatingView(score: 6)
        GearRatingView(score: 4)
        GearRatingView(score: 1)
        GearRatingView(score: 0)
    }
    .padding()
}
