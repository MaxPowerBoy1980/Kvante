import SwiftUI

struct DifficultyPickerView: View {
    let topic: TopicInfo
    let onSelect: (Int) -> Void

    private let difficultyInfo: [(level: Int, label: String, description: String, emoji: String)] = [
        (1, "Let", "Til dig der lige er begyndt", "🌱"),
        (2, "Mellem", "Du har styr på det grundlæggende", "🌿"),
        (3, "Svær", "For dig der vil udfordres", "🌳"),
        (4, "Ekspert", "Til de helt store udfordringer", "🏆"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Topic header
            VStack(spacing: 8) {
                Image(systemName: topic.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(topic.name)
                    .font(.title2.weight(.bold))
            }
            .padding(.top, 20)

            // Difficulty cards
            VStack(spacing: 12) {
                ForEach(difficultyInfo, id: \.level) { info in
                    let available = topic.difficulties.contains(info.level)
                    Button { onSelect(info.level) } label: {
                        HStack(spacing: 14) {
                            Text(info.emoji)
                                .font(.title)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.label)
                                    .font(.headline)
                                Text(info.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if available {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Ingen opgaver")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                        .opacity(available ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .navigationTitle("Vælg sværhedsgrad")
    }
}
