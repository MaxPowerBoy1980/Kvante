import SwiftUI

struct ProgressPillView: View {
    let currentIndex: Int
    let totalCount: Int
    let completedIds: Set<String>
    let assignments: [ParsedAssignment]
    let onTapAssignment: (Int) -> Void

    @State private var showDrawer = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showDrawer.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Opgave \(currentIndex + 1) af \(totalCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.ink)

                    Spacer()

                    Text("\(completedIds.count) løst")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.success)

                    Image(systemName: showDrawer ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)

            if showDrawer {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(assignments.enumerated()), id: \.element.id) { index, assignment in
                            Button {
                                onTapAssignment(index)
                                withAnimation { showDrawer = false }
                            } label: {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(tileTextColor(index: index, assignmentId: assignment.id))
                                    .background(
                                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                            .fill(tileColor(index: index, assignmentId: assignment.id))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                            .stroke(tileBorderColor(index: index, assignmentId: assignment.id), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func tileColor(index: Int, assignmentId: String) -> Color {
        if completedIds.contains(assignmentId) {
            return KvanteTheme.Colors.success
        } else if index == currentIndex {
            return KvanteTheme.Colors.primary
        } else {
            return KvanteTheme.Colors.cream
        }
    }

    private func tileTextColor(index: Int, assignmentId: String) -> Color {
        if completedIds.contains(assignmentId) || index == currentIndex {
            return .white
        } else {
            return KvanteTheme.Colors.textMuted
        }
    }

    private func tileBorderColor(index: Int, assignmentId: String) -> Color {
        if completedIds.contains(assignmentId) || index == currentIndex {
            return .clear
        } else {
            return KvanteTheme.Colors.inkSubtle
        }
    }
}
