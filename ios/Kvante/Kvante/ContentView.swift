import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var serverDiscovery = ServerDiscovery()
    @State private var showScanner = false
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var errorMessage: String?

    // Navigation state
    @State private var pageResponse: PageScanResponse?
    @State private var selectedAssignment: ParsedAssignment?

    private var apiClient: APIClient? {
        guard let url = serverDiscovery.serverURL else { return nil }
        return APIClient(baseURL: url)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView(message: loadingMessage)
                } else if let assignment = selectedAssignment,
                          let page = pageResponse,
                          let client = apiClient {
                    WorkingView(
                        assignment: assignment,
                        sessionId: page.sessionId,
                        apiClient: client
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                selectedAssignment = nil
                            } label: {
                                Label("Tilbage", systemImage: "chevron.left")
                            }
                        }
                    }
                } else if let page = pageResponse {
                    AssignmentPickerView(pageResponse: page) { assignment in
                        selectedAssignment = assignment
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                pageResponse = nil
                                selectedAssignment = nil
                            } label: {
                                Label("Hjem", systemImage: "house.fill")
                            }
                        }
                    }
                } else {
                    HomeView(
                        serverDiscovery: serverDiscovery,
                        onScanPage: { showScanner = true }
                    )
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onScan: { imageData in
                    showScanner = false
                    scanPage(imageData: imageData)
                },
                onCancel: { showScanner = false }
            )
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

    private func scanPage(imageData: Data) {
        guard let client = apiClient else {
            errorMessage = "Ingen forbindelse til serveren"
            return
        }

        isLoading = true
        loadingMessage = "Kvante kigger på din side"

        Task {
            do {
                let response = try await client.scanPage(imageData: imageData)
                pageResponse = response

                // Cache session locally
                let session = Session(
                    id: response.sessionId,
                    detectedLanguage: response.detectedLanguage,
                    pageContext: response.pageContext,
                    suggestedStart: response.suggestedStart,
                    reasoning: response.reasoning
                )
                modelContext.insert(session)
                try? modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Assignment.self, Submission.self],
                        inMemory: true)
}
