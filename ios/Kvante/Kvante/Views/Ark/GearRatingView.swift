import SwiftUI

/// Displays 0-6 filled gear icons representing the quality score.
struct GearRatingView: View {
    let score: Int
    let maxScore: Int = 6

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<maxScore, id: \.self) { index in
                GearShape()
                    .fill(index < score ? KvanteTheme.Colors.primary : Color(.systemGray5))
                    .frame(width: 28, height: 28)
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
