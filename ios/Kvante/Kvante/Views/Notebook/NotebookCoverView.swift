import SwiftUI

/// The book cover — first page in the notebook TabView.
struct NotebookCoverView: View {
    let studentName: String
    let totalSolved: Int
    let totalWeeks: Int

    var body: some View {
        ZStack {
            // Paper background
            KvanteTheme.Colors.cream.ignoresSafeArea()

            // Book spine on left edge
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(red: 0.91, green: 0.87, blue: 0.82), KvanteTheme.Colors.cream],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Kvante figure with pencil
                ZStack {
                    KvanteFace(expression: totalSolved > 0 ? .happy : .neutral)
                        .frame(width: 90, height: 90)

                    // Pencil next to Kvante
                    pencilShape
                        .offset(x: 50, y: 20)
                }
                .padding(.bottom, 20)

                // Title
                Text("Matematikbogen")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                // Subtitle — co-authors
                Text("\(studentName) & Kvante")
                    .font(.system(size: 15))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.6))
                    .padding(.top, 4)

                // Decorative dots (from Kvante's chest panel)
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i == 2 ? KvanteTheme.Colors.primary : KvanteTheme.Colors.kvanteDotBlue)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 24)

                // Stats badge
                Text("\(totalSolved) opgaver løst")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(KvanteTheme.Colors.teal, in: Capsule())
                    .padding(.top, 24)

                Spacer()

                // Swipe hint
                if totalWeeks > 0 {
                    Text("swipe for at bladre \u{203A}")
                        .font(.system(size: 12))
                        .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.3))
                        .padding(.bottom, 24)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Matematikbogen. \(studentName) og Kvante. \(totalSolved) opgaver løst")
    }

    // MARK: - Pencil shape

    /// Simple pencil drawn with SwiftUI shapes — orange body, brown tip, beige eraser.
    private var pencilShape: some View {
        VStack(spacing: 0) {
            // Eraser
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.96, green: 0.90, blue: 0.82))
                .frame(width: 6, height: 6)
            // Body
            Rectangle()
                .fill(KvanteTheme.Colors.primary)
                .frame(width: 6, height: 22)
            // Tip
            Triangle()
                .fill(Color(red: 0.24, green: 0.17, blue: 0.12))
                .frame(width: 6, height: 6)
        }
        .rotationEffect(.degrees(-25))
    }
}

/// Simple triangle shape for pencil tip.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
