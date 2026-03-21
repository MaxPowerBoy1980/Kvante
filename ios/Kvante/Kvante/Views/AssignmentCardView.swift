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
                    Text(assignment.id.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    if isRecommended {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    // Difficulty dots
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Circle()
                                .fill(i <= assignment.difficultyEstimate
                                    ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Text(assignment.text)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(3)

                Text(assignment.topic)
                    .font(.caption)
                    .opacity(0.8)
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
