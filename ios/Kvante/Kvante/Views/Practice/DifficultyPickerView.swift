import SwiftUI

struct DifficultyPickerView: View {
    let topic: TopicInfo
    let onSelect: (Int) -> Void

    private let levels: [(level: Int, label: String, description: String, dotCount: Int, color: Color)] = [
        (1, "Let", "Til dig der øver", 1, KvanteTheme.Colors.difficultyEasy),
        (2, "Normal", "Dit niveau", 2, KvanteTheme.Colors.difficultyNormal),
        (3, "Svær", "Udfordring", 3, KvanteTheme.Colors.difficultyHard),
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Topic header
            VStack(spacing: 8) {
                Image(systemName: topic.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text(topic.name)
                    .font(.title2.weight(.bold))
            }
            .padding(.top, 20)

            // Difficulty cards
            VStack(spacing: 12) {
                ForEach(levels, id: \.level) { info in
                    let available = topic.difficulties.contains(info.level)
                    Button { onSelect(info.level) } label: {
                        HStack(spacing: 14) {
                            // Dot icon in colored box
                            RoundedRectangle(cornerRadius: 10)
                                .fill(info.color.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    HStack(spacing: 3) {
                                        ForEach(0..<info.dotCount, id: \.self) { _ in
                                            Circle()
                                                .fill(info.color)
                                                .frame(width: info.dotCount == 1 ? 10 : (info.dotCount == 2 ? 8 : 7),
                                                       height: info.dotCount == 1 ? 10 : (info.dotCount == 2 ? 8 : 7))
                                        }
                                    }
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.label)
                                    .font(.headline)
                                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
                                Text(info.description)
                                    .font(.subheadline)
                                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                            }

                            Spacer()

                            if available {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                            } else {
                                Text("Ingen opgaver")
                                    .font(.caption2)
                                    .foregroundStyle(KvanteTheme.Colors.mutedText)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                                .fill(KvanteTheme.Colors.kvanteBubble)
                                .overlay(
                                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                                        .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
                                )
                        )
                        .opacity(available ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!available)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(KvanteTheme.Colors.backgroundStart)
        .navigationTitle("Vælg sværhedsgrad")
    }
}
