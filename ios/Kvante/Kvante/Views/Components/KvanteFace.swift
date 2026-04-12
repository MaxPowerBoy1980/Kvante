import SwiftUI

enum KvanteExpression: Equatable {
    case neutral   // Round mouth (small circle)
    case happy     // Smiling arc
    case excited   // Bigger eyes
}

struct KvanteFace: View {
    var expression: KvanteExpression = .neutral
    var size: CGFloat = 34

    private var scale: CGFloat { size / 34.0 }

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 9 * scale)
                .fill(KvanteTheme.Colors.kvanteFace)
                .frame(width: size, height: size)

            // Left eye (round — like plush)
            Circle()
                .fill(.white)
                .frame(width: 8 * scale, height: 8 * scale)
                .overlay(
                    Circle()
                        .fill(Color(hex: "1a1a1a"))
                        .frame(width: 4 * scale, height: 4 * scale)
                )
                .offset(x: -6 * scale, y: -3 * scale)

            // Right eye (square — like plush)
            RoundedRectangle(cornerRadius: 2 * scale)
                .fill(.white)
                .frame(width: 8 * scale, height: (expression == .excited ? 11 : 9) * scale)
                .overlay(
                    Circle()
                        .fill(Color(hex: "1a1a1a"))
                        .frame(width: 4 * scale, height: 4 * scale)
                )
                .offset(x: 6 * scale, y: -3 * scale)

            // Mouth
            mouthView

            // Antenna stem
            Rectangle()
                .fill(KvanteTheme.Colors.ink)
                .frame(width: 2 * scale, height: 7 * scale)
                .offset(y: -(size / 2 + 2 * scale))

            // Antenna pom-pom
            Circle()
                .fill(KvanteTheme.Colors.antennePink)
                .frame(width: 7 * scale, height: 7 * scale)
                .offset(y: -(size / 2 + 6.5 * scale))
        }
        .frame(width: size, height: size + 14 * scale)  // Account for antenna
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expression)
    }

    @ViewBuilder
    private var mouthView: some View {
        switch expression {
        case .neutral:
            Circle()
                .fill(Color(hex: "1a1a1a"))
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(y: 7 * scale)
        case .happy, .excited:
            // Smiling arc using a trimmed circle stroke
            Circle()
                .trim(from: 0.1, to: 0.4)
                .stroke(Color(hex: "1a1a1a"), lineWidth: 2 * scale)
                .frame(width: 12 * scale, height: 12 * scale)
                .offset(y: 5 * scale)
        }
    }
}
