import SwiftUI

struct AssignmentCardView: View {
    let assignment: ParsedAssignment
    let isRecommended: Bool
    let onTap: () -> Void

    private let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .teal]

    private var cardColor: Color {
        let hash = abs(assignment.id.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Opgave \(assignment.localId)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .opacity(0.8)
                    Spacer()
                    if isRecommended {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    HStack(spacing: 3) {
                        let clamped = min(assignment.difficultyEstimate, 3)
                        ForEach(0..<clamped, id: \.self) { _ in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 7, height: 7)
                        }
                    }
                }

                Text(assignment.text)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(3)

                Text(assignment.topic)
                    .font(.subheadline)
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if isRecommended {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.yellow, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
