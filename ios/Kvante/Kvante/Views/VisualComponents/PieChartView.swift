import SwiftUI

struct PieChartVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var parts: Int { visual.intParam("parts") ?? 4 }
    private var fillCount: Int { visual.intParam("count") ?? 0 }
    private var fillTotal: Int { visual.intParam("total") ?? parts }
    private var numerator: Int { visual.intParam("numerator") ?? fillCount }
    private var denominator: Int { visual.intParam("denominator") ?? fillTotal }

    @State private var filledSlices = 0
    @State private var showDivisions = false
    @State private var showFraction = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                .frame(width: 150, height: 150)

            // Filled slices
            ForEach(0..<filledSlices, id: \.self) { i in
                PieSlice(
                    startAngle: .degrees(Double(i) * 360.0 / Double(parts) - 90),
                    endAngle: .degrees(Double(i + 1) * 360.0 / Double(parts) - 90)
                )
                .fill(i == filledSlices - 1 ? Color.green : Color.blue)
                .frame(width: 150, height: 150)
                .transition(.opacity)
            }

            // Division lines
            if showDivisions {
                ForEach(0..<parts, id: \.self) { i in
                    let angle = Double(i) * 360.0 / Double(parts) - 90
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 1, height: 75)
                        .offset(y: -37.5)
                        .rotationEffect(.degrees(angle))
                }
            }

            // Fraction label
            if showFraction {
                Text("\(numerator)/\(denominator)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func startAnimation() {
        switch action {
        case "divide_circle":
            withAnimation(.easeInOut(duration: 0.5)) { showDivisions = true }
        case "fill_slices":
            showDivisions = true
            for i in 1...fillCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                    withAnimation(.easeInOut(duration: 0.3)) { filledSlices = i }
                }
            }
        case "label_fraction":
            showDivisions = true
            filledSlices = numerator
            withAnimation(.spring.delay(0.2)) { showFraction = true }
        default: break
        }
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}
