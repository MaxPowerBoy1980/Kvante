import SwiftUI

struct CelebrationView: View {
    let tier: CelebrationTier

    @State private var animateScale = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.1))
                    .frame(width: iconSize, height: iconSize)
                Image(systemName: "checkmark")
                    .font(.system(size: iconSize * 0.4, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.success)
            }
            .scaleEffect(animateScale ? 1.0 : 0.5)
            .opacity(animateScale ? 1.0 : 0)

            Text(title)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.success)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(KvanteTheme.Colors.ink)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                .fill(KvanteTheme.Colors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                        .stroke(KvanteTheme.Colors.success, lineWidth: 2)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animateScale = true
            }
        }
    }

    private var iconSize: CGFloat {
        switch tier {
        case .routine: return 48
        case .persevered: return 56
        case .setComplete: return 72
        }
    }

    private var fontSize: CGFloat {
        switch tier {
        case .routine: return 20
        case .persevered: return 22
        case .setComplete: return 28
        }
    }

    private var title: String {
        switch tier {
        case .routine: return "Rigtigt!"
        case .persevered: return "Du blev ved — og det lykkedes!"
        case .setComplete: return "Du klarede dem alle!"
        }
    }

    private var subtitle: String {
        switch tier {
        case .routine: return ""
        case .persevered: return "Godt gået at du ikke gav op."
        case .setComplete: return ""
        }
    }
}
