import SwiftUI

struct WorkingView: View {
    let assignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient

    @State private var showScanner = false
    @State private var showExample = false
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var exampleResponse: ExampleResponse?
    @State private var submissionResponse: SubmissionResponse?
    @State private var feedbackResponse: FeedbackResponse?
    @State private var errorMessage: String?
    @State private var explainText: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: loadingMessage)
            } else if let feedback = feedbackResponse, let submission = submissionResponse {
                FeedbackView(
                    feedback: feedback,
                    submission: submission,
                    assignment: assignment,
                    sessionId: sessionId,
                    apiClient: apiClient
                )
            } else {
                workingContent
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onScan: { imageData in
                    showScanner = false
                    submitWork(imageData: imageData)
                },
                onCancel: { showScanner = false }
            )
        }
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    ExampleView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
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
        .navigationTitle("Opgave \(assignment.id)")
    }

    private var workingContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Assignment text
                Text(assignment.text)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                // Explain text if requested
                if let explain = explainText {
                    Text(explain)
                        .font(.body)
                        .padding(16)
                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // Action buttons
                VStack(spacing: 12) {
                    PromptButton(
                        title: "Vis mig et eksempel",
                        icon: "lightbulb.fill",
                        color: .orange
                    ) { getExample() }

                    PromptButton(
                        title: "Jeg forstår ikke opgaven",
                        icon: "questionmark.circle.fill",
                        color: .purple
                    ) { explainAssignment() }

                    PromptButton(
                        title: "Scan mit svar",
                        icon: "camera.fill",
                        color: .blue
                    ) { showScanner = true }
                }
                .padding(.horizontal, 20)
            }
            .padding(24)
        }
    }

    private func getExample() {
        isLoading = true
        loadingMessage = "Kvante laver et eksempel"
        Task {
            do {
                let example = try await apiClient.getExample(
                    sessionId: sessionId, assignmentId: assignment.id)
                exampleResponse = example
                showExample = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func explainAssignment() {
        isLoading = true
        loadingMessage = "Kvante tænker"
        Task {
            do {
                let response = try await apiClient.explainTask(
                    sessionId: sessionId, assignmentId: assignment.id)
                explainText = response.feedbackText
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func submitWork(imageData: Data) {
        isLoading = true
        loadingMessage = "Kvante kigger på dit svar"
        Task {
            do {
                let submission = try await apiClient.submitWork(
                    sessionId: sessionId,
                    assignmentId: assignment.id,
                    imageData: imageData
                )
                submissionResponse = submission
                let feedback = try await apiClient.getFeedback(
                    submissionId: submission.submissionId)
                feedbackResponse = feedback
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
