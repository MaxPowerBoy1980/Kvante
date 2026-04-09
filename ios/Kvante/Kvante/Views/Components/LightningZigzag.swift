import SwiftUI

/// Coral lightning zigzag — Kvante's celebration signature.
/// Replaces the green checkmark for correct answers.
struct LightningZigzag: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        // Classic lightning bolt shape
        path.move(to: CGPoint(x: w * 0.58, y: 0))
        path.addLine(to: CGPoint(x: w * 0.33, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.42, y: h))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.40))
        path.closeSubpath()
        return path
    }
}

/// Animated lightning zigzag for celebrations.
struct LightningCelebration: View {
    let size: CGFloat
    @State private var flash = false

    var body: some View {
        LightningZigzag()
            .fill(KvanteTheme.Colors.primary)
            .frame(width: size * 0.5, height: size)
            .opacity(flash ? 1.0 : 0)
            .scaleEffect(flash ? 1.0 : 0.5)
            .onAppear {
                withAnimation(.spring(response: KvanteTheme.Celebration.chatFlashDuration, dampingFraction: 0.6)) {
                    flash = true
                }
            }
    }
}
