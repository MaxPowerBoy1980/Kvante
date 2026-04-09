import SwiftUI

struct CelebrationView: View {
    let tier: CelebrationTier

    @State private var animateFlash = false

    var body: some View {
        VStack(spacing: 12) {
            // Lightning zigzag instead of checkmark
            LightningCelebration(size: iconSize)

            Text(title)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.coral)

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
                .fill(KvanteTheme.Colors.coral.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                        .stroke(KvanteTheme.Colors.coral.opacity(0.3), lineWidth: 1.5)
                )
        )
        .onAppear {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: tier == .setComplete ? .heavy : .medium)
            generator.impactOccurred()

            if tier == .setComplete {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

            // Header animation is triggered separately via NotificationCenter (Task 9)
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
