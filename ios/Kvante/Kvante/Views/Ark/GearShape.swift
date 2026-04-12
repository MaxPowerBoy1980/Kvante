import SwiftUI

/// A gear/tandhjul shape matching Kvante's collar design.
/// 8-tooth gear with a circular center.
struct GearShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.65
        let teethCount = 8
        let anglePerTooth = (2 * .pi) / Double(teethCount)
        let toothWidth = anglePerTooth * 0.4

        var path = Path()

        for i in 0..<teethCount {
            let baseAngle = Double(i) * anglePerTooth - .pi / 2

            // Inner arc (between teeth)
            let innerStart = baseAngle + toothWidth / 2
            let innerEnd = baseAngle + anglePerTooth - toothWidth / 2
            path.addArc(center: center, radius: innerRadius, startAngle: .radians(innerStart), endAngle: .radians(innerEnd), clockwise: false)

            // Outer arc (tooth)
            let outerStart = innerEnd
            let outerEnd = outerStart + toothWidth
            path.addArc(center: center, radius: outerRadius, startAngle: .radians(outerStart), endAngle: .radians(outerEnd), clockwise: false)
        }

        path.closeSubpath()

        // Center hole
        let holeRadius = innerRadius * 0.35
        path.addEllipse(in: CGRect(
            x: center.x - holeRadius,
            y: center.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))

        return path
    }
}

#Preview {
    HStack(spacing: 12) {
        GearShape()
            .fill(Color.orange)
            .frame(width: 28, height: 28)
        GearShape()
            .fill(Color.orange)
            .frame(width: 28, height: 28)
        GearShape()
            .fill(Color(.systemGray5))
            .frame(width: 28, height: 28)
    }
    .padding()
}
