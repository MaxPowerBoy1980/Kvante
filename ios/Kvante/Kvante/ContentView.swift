import SwiftUI
import SwiftData

// MARK: - SessionRoute

enum SessionRoute: Hashable {
    case ark
    case chat
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [StudentProfile]
    @State private var serverDiscovery = ServerDiscovery()
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var errorMessage: String?

    // Navigation state — pre-session
    @State private var showPractice = false
    @State private var selectedTopic: TopicInfo?
    @State private var sessionHistory: [SessionSummary] = []

    // Navigation state — session (NavigationStack path)
    @State private var sessionPath: [SessionRoute] = []
    @State private var activeSession: SessionViewModel?
    @State private var activeChatViewModel: ChatViewModel?

    private var profile: StudentProfile? { profiles.first }

    private var apiClient: APIClient? {
        guard let url = serverDiscovery.serverURL else { return nil }
        return APIClient(baseURL: url)
    }

    var body: some View {
        NavigationStack(path: $sessionPath) {
            ZStack {
                KvanteTheme.Colors.background.ignoresSafeArea()

                Group {
                    if isLoading {
                        LoadingView(message: loadingMessage)
                    } else if profile == nil {
                        ChatOnboardingView(apiClient: apiClient) {}
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
                            onTapSession: { summary in
                                resumeSession(summary)
                            }
                        )
                        .task(id: serverDiscovery.serverURL) { await loadSessionHistory() }
                    }
                }
            }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .ark:
                    if let session = activeSession, let client = apiClient {
                        AssignmentSheetView(
                            session: session,
                            apiClient: client,
                            onSelectAssignment: { index in
                                session.goToAssignment(index)
                                sessionPath.append(.chat)
                            },
                            onBack: {
                                sessionPath.removeAll()
                            }
                        )
                    }
                case .chat:
                    if let vm = activeChatViewModel {
                        ChatView(
                            viewModel: vm,
                            onBack: { sessionPath.removeLast() },
                            onShowArk: { sessionPath.removeLast() }
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            KvanteHeaderBar(session: activeSession)
        }
        .onChange(of: sessionPath) { _, newValue in
            if newValue.isEmpty {
                activeSession = nil
                activeChatViewModel = nil
                // Refresh session history when returning to home
                Task { await loadSessionHistory() }
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

    // MARK: - Session Entry Flows

    private func startPracticeSession(topic: String, difficulty: Int) {
        guard let client = apiClient, let p = profile else { return }

        isLoading = true
        loadingMessage = "Kvante finder opgaver..."

        Task {
            do {
                let studentId = p.backendStudentId ?? "default"
                let practiceResponse = try await client.createPracticeSession(
                    studentId: studentId,
                    topic: topic,
                    difficulty: difficulty
                )
                // Fetch the full session detail with ark fields
                let response = try await client.getSession(sessionId: practiceResponse.sessionId)
                let session = SessionViewModel(from: response)
                activeSession = session
                activeChatViewModel = ChatViewModel(session: session, apiClient: client)
                selectedTopic = nil
                showPractice = false
                sessionPath = [.ark]
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
                // Fetch the full session detail with ark fields
                let response = try await client.getSession(sessionId: weekly.sessionId)
                let session = SessionViewModel(from: response)
                activeSession = session
                activeChatViewModel = ChatViewModel(session: session, apiClient: client)
                sessionPath = [.ark]
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func resumeSession(_ summary: SessionSummary) {
        guard let client = apiClient else { return }
        isLoading = true
        loadingMessage = "Henter session..."

        Task {
            do {
                let response = try await client.getSession(sessionId: summary.sessionId)
                let session = SessionViewModel(from: response)
                activeSession = session
                activeChatViewModel = ChatViewModel(session: session, apiClient: client)
                sessionPath = [.ark]
            } catch {
                errorMessage = "Kunne ikke abne session: \(error.localizedDescription)"
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
}

#Preview {
    ContentView()
        .modelContainer(for: [StudentProfile.self], inMemory: true)
}
