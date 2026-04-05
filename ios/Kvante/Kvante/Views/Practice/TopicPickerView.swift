import SwiftUI

struct TopicPickerView: View {
    let apiClient: APIClient
    let onSelect: (TopicInfo) -> Void

    @State private var topics: [TopicInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let topicColors: [String: Color] = [
        "addition": .orange,
        "subtraktion": .red,
        "multiplikation": .blue,
        "division": .indigo,
        "broeker": .purple,
        "decimaltal": .teal,
        "geometri": .green,
        "ligninger": .pink,
        "procent": .yellow,
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

            Text("\(topic.problemCount) opgaver")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
