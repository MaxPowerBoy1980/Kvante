import SwiftUI

struct TopicPickerView: View {
    let apiClient: APIClient
    let onSelect: (TopicInfo) -> Void

    @State private var topics: [TopicInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let topicColors: [String: Color] = [
        "addition": KvanteTheme.Colors.primary,
        "subtraktion": Color(hex: "e74c3c"),
        "multiplikation": Color(hex: "3498db"),
        "division": Color(hex: "6c5ce7"),
        "broeker": Color(hex: "9b59b6"),
        "decimaltal": KvanteTheme.Colors.teal,
        "geometri": KvanteTheme.Colors.success,
        "ligninger": Color(hex: "e84393"),
        "procent": Color(hex: "f39c12"),
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Henter emner...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Prøv igen") { loadTopics() }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(topics) { topic in
                            Button { onSelect(topic) } label: {
                                TopicCard(
                                    topic: topic,
                                    color: topicColors[topic.topic] ?? .gray
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .background(KvanteTheme.Colors.backgroundStart)
            }
        }
        .navigationTitle("Vælg emne")
        .task { loadTopics() }
    }

    private func loadTopics() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await apiClient.getTopics()
                topics = response.topics
            } catch {
                errorMessage = "Kunne ikke hente emner"
            }
            isLoading = false
        }
    }
}

struct TopicCard: View {
    let topic: TopicInfo
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: topic.icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(topic.name)
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.textPrimary)

            Text("\(topic.problemCount) opgaver")
                .font(.caption)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
