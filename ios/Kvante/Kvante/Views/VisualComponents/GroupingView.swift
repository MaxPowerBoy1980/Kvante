import SwiftUI

struct GroupingVisualView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeGrouped: Int  // Objects already grouped in prior steps

    private var action: String { visual.action }
    private var count: Int { visual.intParam("count") ?? 0 }
    private var groupIndex: Int { visual.intParam("group_index") ?? 0 }
    private var groupSize: Int { visual.intParam("size") ?? 1 }
    private var totalGroups: Int { visual.intParam("groups") ?? 1 }
    private var perGroup: Int { visual.intParam("per_group") ?? 1 }

    @State private var placedCount = 0
    @State private var formedGroup = false
    @State private var showLabels = false

    var body: some View {
        VStack(spacing: 16) {
            switch action {
            case "place_objects":
                // Show objects appearing in a cluster
                let cols = min(count, 8)
                let rows = (count + cols - 1) / cols
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(0..<rows, id: \.self) { row in
                        GridRow {
                            ForEach(0..<cols, id: \.self) { col in
                                let idx = row * cols + col
                                if idx < count {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 20, height: 20)
                                        .opacity(idx < placedCount ? 1 : 0)
                                        .animation(.spring(duration: 0.2).delay(Double(idx) * 0.08), value: placedCount)
                                }
                            }
                        }
                    }
                }

            case "form_group":
                // Show a group being formed
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<groupSize, id: \.self) { _ in
                            Circle()
                                .fill(formedGroup ? Color.green : Color.blue)
                                .frame(width: 20, height: 20)
                        }
                    }
                    if formedGroup {
                        Text("Gruppe \(groupIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(formedGroup ? Color.green : Color.clear, lineWidth: 2)
                )

            case "label_groups":
                // Show all groups with labels
                HStack(spacing: 16) {
                    ForEach(0..<totalGroups, id: \.self) { i in
                        VStack(spacing: 4) {
                            HStack(spacing: 3) {
                                ForEach(0..<perGroup, id: \.self) { _ in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 16, height: 16)
                                }
                            }
                            if showLabels {
                                Text("Gruppe \(i + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 1.5)
                        )
                    }
                }

            default:
                EmptyView()
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
        case "place_objects":
            placedCount = count
        case "form_group":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.4)) { formedGroup = true }
            }
        case "label_groups":
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) { showLabels = true }
        default: break
        }
    }
}
