import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [StudentProfile]
    @State private var serverDiscovery = ServerDiscovery()
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var errorMessage: String?

    // Navigation state
    @State private var showPractice = false
    @State private var selectedTopic: TopicInfo?
    @State private var practiceSession: PracticeSessionResponse?

    private var profile: StudentProfile? { profiles.first }

    private var apiClient: APIClient? {
        guard let url = serverDiscovery.serverURL else { return nil }
        return APIClient(baseURL: url)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KvanteTheme.Colors.background.ignoresSafeArea()

            Group {
                if isLoading {
                    LoadingView(message: loadingMessage)
                } else if profile == nil {
                    ChatOnboardingView(apiClient: apiClient) {}
                } else if let session = practiceSession, let client = apiClient {
                    PracticeSessionView(
                        sessionId: session.sessionId,
                        assignments: session.assignments,
                        apiClient: client
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                practiceSession = nil
                                selectedTopic = nil
                                showPractice = false
                            } label: {
                                Label("Afslut", systemImage: "xmark")
                            }
                        }
                    }
                } else if let topic = selectedTopic {
                    DifficultyPickerView(topic: topic) { difficulty in
                        startPracticeSession(topic: topic.topic, difficulty: difficulty)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { selectedTopic = nil } label: {
                                Label("Tilbage", systemImage: "chevron.left")
                            }
                        }
                    }
                } else if showPractice, let client = apiClient {
                    TopicPickerView(apiClient: client) { topic in
                        selectedTopic = topic
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showPractice = false } label: {
                                Label("Hjem", systemImage: "chevron.left")
                            }
                        }
                    }
                } else if let p = profile {
                    NewHomeView(
                        profile: p,
                        serverDiscovery: serverDiscovery,
                        onPractice: { showPractice = true }
                    )
                }
            }
            }
        }
        .alert("Fejl", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            serverDiscovery.startSearching()
        }
    }

    private func startPracticeSession(topic: String, difficulty: Int) {
        guard let client = apiClient, let p = profile else { return }

        isLoading = true
        loadingMessage = "Kvante finder opgaver..."

        Task {
            do {
                let studentId = p.backendStudentId ?? "default"
                let session = try await client.createPracticeSession(
                    studentId: studentId,
                    topic: topic,
                    difficulty: difficulty
                )
                practiceSession = session
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Assignment.self, Submission.self, StudentProfile.self],
                        inMemory: true)
}
