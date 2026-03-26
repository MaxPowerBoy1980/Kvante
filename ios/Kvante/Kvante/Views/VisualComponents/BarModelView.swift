import SwiftUI

struct BarModelVisualView: View {
    let visual: VisualInstruction
    let animate: Bool

    private var action: String { visual.action }
    private var segments: Int { visual.intParam("segments") ?? visual.intParam("count") ?? 4 }
    private var fillIndex: Int { visual.intParam("index") ?? 0 }
    private var fillLabel: String { visual.stringParam("label") ?? "" }
    private var labelText: String { visual.stringParam("text") ?? "" }
    private var labelPosition: String { visual.stringParam("position") ?? "below" }

    @State private var visibleSegments = 0
    @State private var filledIndex: Int? = nil
    @State private var showLabel = false

    var body: some View {
        VStack(spacing: 8) {
            if showLabel && labelPosition == "above" {
                Text(labelText)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(segmentColor(i))
                        .frame(height: 50)
                        .overlay(
                            Rectangle()
                                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if i == filledIndex {
                                    Text(fillLabel)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                        )
                        .opacity(i < visibleSegments ? 1 : 0.2)
                        .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.15), value: visibleSegments)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 2)
            )

            if showLabel && labelPosition != "above" {
                Text(labelText)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .onAppear { if animate { startAnimation() } }
        .onChange(of: animate) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func segmentColor(_ index: Int) -> Color {
        if index == filledIndex { return .blue }
        return Color.secondary.opacity(0.1)
    }

    private func startAnimation() {
        switch action {
        case "draw_bar", "split":
            visibleSegments = segments
        case "fill_segment":
            visibleSegments = segments
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.4)) { filledIndex = fillIndex }
            }
        case "label":
            visibleSegments = segments
            withAnimation(.spring.delay(0.2)) { showLabel = true }
        default: break
        }
    }
}
