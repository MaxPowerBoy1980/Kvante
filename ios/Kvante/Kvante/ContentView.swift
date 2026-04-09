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
    @State private var sessionHistory: [SessionSummary] = []
    @State private var selectedSession: SessionSummary?
    @State private var isResumingSession = false

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
                        apiClient: client,
                        onBack: {
                            practiceSession = nil
                            selectedTopic = nil
                            showPractice = false
                        }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                } else if let session = selectedSession {
                    SessionDashboardView(
                        session: session,
                        onBack: { selectedSession = nil },
                        onContinue: { resumeSession(session) },
                        isLoading: isResumingSession
                    )
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
                        onPractice: { showPractice = true },
                        onWeekly: { startWeeklySession() },
                        sessionHistory: sessionHistory,
                        onTapSession: { session in
                            selectedSession = session
                        }
                    )
                    .task(id: serverDiscovery.serverURL) { await loadSessionHistory() }
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
        .devCaptureButton(apiClient: apiClient)
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

    private func startWeeklySession() {
        guard let client = apiClient, let p = profile else { return }
        isLoading = true
        loadingMessage = "Kvante laver ugematematik..."

        Task {
            do {
                let studentId = p.backendStudentId ?? "default"
                let weekly = try await client.createWeeklySession(
                    studentId: studentId,
                    gradeLevel: p.gradeLevel
                )
                practiceSession = PracticeSessionResponse(
                    sessionId: weekly.sessionId,
                    assignments: weekly.assignments
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func loadSessionHistory() async {
        guard let client = apiClient, let p = profile else { return }
        let studentId = p.backendStudentId ?? "default"
        if let history = try? await client.getSessionHistory(studentId: studentId) {
            sessionHistory = history.sessions
        }
    }

    private func resumeSession(_ summary: SessionSummary) {
        guard let client = apiClient else { return }
        isResumingSession = true
        Task {
            do {
                let session = try await client.getSession(sessionId: summary.sessionId)
                practiceSession = session
                selectedSession = nil
            } catch {
                errorMessage = "Kunne ikke åbne session: \(error.localizedDescription)"
            }
            isResumingSession = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Assignment.self, Submission.self, StudentProfile.self],
                        inMemory: true)
}
