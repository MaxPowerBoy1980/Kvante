import Foundation
import SwiftUI

@Observable
class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var isLoading = false
    var showScanner = false

    // MARK: - Context

    private(set) var currentAssignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient

    // Track submission for follow-ups
    private var currentSubmissionId: String?

    // Callback for parent to advance to next assignment
    var onNextAssignment: (() -> Void)?

    // MARK: - Init

    init(assignment: ParsedAssignment, sessionId: String, apiClient: APIClient) {
        self.currentAssignment = assignment
        self.sessionId = sessionId
        self.apiClient = apiClient
        sendWelcome()
    }

    // MARK: - Welcome

    private func sendWelcome() {
        let intro = ChatMessage(
            sender: .kvante,
            content: .assignmentIntro(currentAssignment)
        )
        messages.append(intro)

        let welcome = ChatMessage(
            sender: .kvante,
            content: .text("Hvad vil du gøre? Du kan bede mig om hjælp, eller scanne dit svar når du er klar."),
            actions: [
                ActionChipModel(id: "help", label: "Hjælp mig med opgaven", icon: "lightbulb.fill", isPrimary: false),
                ActionChipModel(id: "scan", label: "Scan mit svar", icon: "camera.fill", isPrimary: true),
            ]
        )
        messages.append(welcome)
    }

    // MARK: - Actions

    func handleChip(_ chip: ActionChipModel) {
        switch chip.id {
        case "help":
            requestHelp()
        case "scan":
            showScanner = true
        case "next_assignment":
            onNextAssignment?()
            return
        case "try_again":
            tryAgain()
        case "another_example":
            requestHelp()
        default:
            handleFollowup(chip.id)
        }
    }

    func requestHelp() {
        // Student message
        messages.append(ChatMessage(
            sender: .student,
            content: .text("Hjælp mig med opgaven")
        ))

        // Loading
        let loadingId = addLoading("Kvante laver et eksempel...")

        Task { @MainActor in
            do {
                let example = try await apiClient.getExample(
                    sessionId: sessionId,
                    assignmentId: currentAssignment.id
                )
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .example(example),
                    actions: [
                        ActionChipModel(id: "scan", label: "Scan mit svar", icon: "camera.fill", isPrimary: true),
                        ActionChipModel(id: "help", label: "Nyt eksempel", icon: "lightbulb.fill", isPrimary: false),
                    ]
                ))
            } catch {
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                ))
            }
        }
    }

    // Pending image data for confirmation flow
    private var pendingImageData: Data?
    private var pendingOcrFullText: String = ""

    func scanAnswer(_ imageData: Data) {
        // Student message with scanned image
        messages.append(ChatMessage(
            sender: .student,
            content: .scannedImage(imageData)
        ))

        let loadingId = addLoading("Kvante tyder dit svar...")

        Task { @MainActor in
            // Step 1: OCR (Apple first, then Gemini fallback)
            let ocr = await HandwritingOCR.recognize(imageData: imageData)

            var readAnswer: String
            var source: String

            if ocr.isCleanNumber && ocr.confidence > 0.3 {
                readAnswer = ocr.answer
                source = "Apple OCR"
            } else {
                // Gemini fallback
                do {
                    let result = try await apiClient.submitWork(
                        sessionId: sessionId,
                        assignmentId: currentAssignment.id,
                        imageData: imageData
                    )
                    readAnswer = result.studentAnswer
                    source = "Gemini Vision"
                    // If Gemini was used, we already have the submission — store it
                    currentSubmissionId = result.submissionId
                    pendingImageData = nil
                    // Skip confirmation, show result directly
                    showAnswerResult(
                        studentAnswer: result.studentAnswer,
                        correctAnswer: result.correctAnswer,
                        isCorrect: result.methodologySound,
                        source: source,
                        ocrDebug: "OCR: \"\(ocr.fullText)\"",
                        loadingId: loadingId
                    )
                    return
                } catch {
                    replaceLoading(loadingId, with: ChatMessage(
                        sender: .kvante,
                        content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                    ))
                    return
                }
            }

            // Step 2: Ask student to confirm
            pendingImageData = imageData
            pendingOcrFullText = ocr.fullText

            replaceLoading(loadingId, with: ChatMessage(
                sender: .kvante,
                content: .ocrConfirm(OcrConfirmation(
                    readText: readAnswer,
                    imageData: imageData,
                    source: source
                ))
            ))
        }
    }

    /// Student confirmed the OCR reading is correct
    func confirmAnswer(_ answer: String) {
        guard let imageData = pendingImageData else { return }

        // Student confirms
        messages.append(ChatMessage(
            sender: .student,
            content: .text("Mit svar: \(answer)")
        ))

        let loadingId = addLoading("Tjekker dit svar...")

        Task { @MainActor in
            do {
                let submission = try await apiClient.submitAnswer(
                    sessionId: sessionId,
                    assignmentId: currentAssignment.id,
                    answerText: answer,
                    fullOcrText: pendingOcrFullText,
                    imageData: imageData
                )
                currentSubmissionId = submission.submissionId
                pendingImageData = nil

                showAnswerResult(
                    studentAnswer: submission.studentAnswer,
                    correctAnswer: submission.correctAnswer,
                    isCorrect: submission.methodologySound,
                    source: "Apple OCR",
                    ocrDebug: "",
                    loadingId: loadingId
                )
            } catch {
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                ))
            }
        }
    }

    private func showAnswerResult(
        studentAnswer: String, correctAnswer: String,
        isCorrect: Bool, source: String, ocrDebug: String,
        loadingId: UUID
    ) {
        let result = AnswerResult(
            studentAnswer: studentAnswer,
            correctAnswer: correctAnswer,
            isCorrect: isCorrect,
            message: isCorrect
                ? "Flot klaret! Det er helt rigtigt."
                : "Ikke helt — prøv igen! Du kan også bede om hjælp.",
            source: source,
            ocrDebug: ocrDebug
        )

        let chips: [ActionChipModel] = isCorrect
            ? [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
            : [
                ActionChipModel(id: "scan", label: "Prøv igen", icon: "camera.fill", isPrimary: true),
                ActionChipModel(id: "help", label: "Hjælp mig", icon: "lightbulb.fill", isPrimary: false),
            ]

        replaceLoading(loadingId, with: ChatMessage(
            sender: .kvante,
            content: .answerResult(result),
            actions: chips
        ))
    }

    private func handleFollowup(_ actionId: String) {
        guard let submissionId = currentSubmissionId else { return }

        // Student message
        let chipLabel = messages.last?.actions.first(where: { $0.id == actionId })?.label ?? actionId
        messages.append(ChatMessage(
            sender: .student,
            content: .text(chipLabel)
        ))

        let loadingId = addLoading("Kvante tænker...")

        Task { @MainActor in
            do {
                let response = try await apiClient.sendFollowup(
                    submissionId: submissionId,
                    action: actionId
                )
                let chips = response.structuredPrompts.map { ActionChipModel.fromPrompt($0) }
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .feedback(response),
                    actions: chips
                ))
            } catch {
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                ))
            }
        }
    }

    private func tryAgain() {
        messages.append(ChatMessage(
            sender: .kvante,
            content: .text("Godt, prøv igen! Scan dit nye svar når du er klar."),
            actions: [
                ActionChipModel(id: "scan", label: "Scan mit svar", icon: "camera.fill", isPrimary: true),
                ActionChipModel(id: "help", label: "Hjælp mig med opgaven", icon: "lightbulb.fill", isPrimary: false),
            ]
        ))
    }

    // MARK: - Loading Helpers

    @discardableResult
    private func addLoading(_ text: String) -> UUID {
        isLoading = true
        let msg = ChatMessage(sender: .kvante, content: .loading(text))
        messages.append(msg)
        return msg.id
    }

    private func replaceLoading(_ id: UUID, with message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
        isLoading = false
    }
}
