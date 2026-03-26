import SwiftUI

struct FeedbackView: View {
    let feedback: FeedbackResponse
    let submission: SubmissionResponse
    let assignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient

    @State private var currentFeedback: FeedbackResponse
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showExample = false
    @State private var exampleResponse: ExampleResponse?

    init(feedback: FeedbackResponse, submission: SubmissionResponse,
         assignment: ParsedAssignment, sessionId: String, apiClient: APIClient) {
        self.feedback = feedback
        self.submission = submission
        self.assignment = assignment
        self.sessionId = sessionId
        self.apiClient = apiClient
        self._currentFeedback = State(initialValue: feedback)
    }

    private var toneColor: Color {
        switch currentFeedback.tone {
        case "celebratory": return .green
        case "encouraging": return .orange
        case "supportive": return .blue
        default: return .blue
        }
    }

    private var toneIcon: String {
        switch currentFeedback.tone {
        case "celebratory": return "star.fill"
        case "encouraging": return "hand.thumbsup.fill"
        case "supportive": return "heart.fill"
        default: return "message.fill"
        }
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Kvante tænker")
            } else {
                feedbackContent
            }
        }
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    AnimatedExplanationView(example: example)
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
    }

    private var feedbackContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Feedback text
                VStack(spacing: 16) {
                    Image(systemName: toneIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(toneColor)

                    Text(currentFeedback.feedbackText)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(toneColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))

                // Structured prompt buttons
                VStack(spacing: 12) {
                    ForEach(currentFeedback.structuredPrompts) { prompt in
                        promptButton(for: prompt)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func promptButton(for prompt: StructuredPrompt) -> some View {
        let (icon, color) = promptStyle(for: prompt.promptId)
        PromptButton(title: prompt.label, icon: icon, color: color) {
            handlePrompt(prompt.promptId)
        }
    }

    private func promptStyle(for id: String) -> (icon: String, color: Color) {
        switch id {
        case "explain_different": return ("arrow.triangle.2.circlepath", .purple)
        case "another_example": return ("lightbulb.fill", .orange)
        case "show_first_step": return ("1.circle.fill", .blue)
        case "what_did_well": return ("hand.thumbsup.fill", .green)
        case "try_again": return ("arrow.counterclockwise", .teal)
        case "next_assignment": return ("arrow.right.circle.fill", .green)
        default: return ("questionmark.circle", .gray)
        }
    }

    private func handlePrompt(_ actionId: String) {
        // next_assignment is client-side navigation — handled by parent
        if actionId == "next_assignment" {
            return
        }

        if actionId == "another_example" {
            getAnotherExample()
            return
        }

        if actionId == "try_again" {
            return
        }

        // All other actions go through followup endpoint
        isLoading = true
        Task {
            do {
                let response = try await apiClient.sendFollowup(
                    submissionId: submission.submissionId,
                    action: actionId
                )
                currentFeedback = response
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func getAnotherExample() {
        isLoading = true
        Task {
            do {
                let example = try await apiClient.getExample(
                    sessionId: sessionId,
                    assignmentId: assignment.id
                )
                exampleResponse = example
                showExample = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
