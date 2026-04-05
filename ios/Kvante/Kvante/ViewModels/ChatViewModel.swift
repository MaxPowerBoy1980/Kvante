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
            content: .text("Hej! Klar til at kigge på denne opgave? Løs den med blyant og papir, og scan dit svar når du er klar. Tryk + hvis du har brug for hjælp 🤖")
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
        case "next_step":
            showNextExampleStep()
        default:
            handleFollowup(chip.id)
        }
    }

    // Pending example steps for step-by-step reveal
    private var pendingExampleSteps: [AnimationStep] = []
    private var currentExampleStepIndex = 0

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

                // Store all steps for step-by-step reveal
                pendingExampleSteps = example.steps
                currentExampleStepIndex = 0

                // Show intro message
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Her er et eksempel med andre tal: **\(example.exampleProblem)**")
                ))

                // Show first step
                showNextExampleStep()
            } catch {
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                ))
            }
        }
    }

    private func showNextExampleStep() {
        guard currentExampleStepIndex < pendingExampleSteps.count else { return }

        let step = pendingExampleSteps[currentExampleStepIndex]
        let isLast = currentExampleStepIndex == pendingExampleSteps.count - 1

        let chips: [ActionChipModel] = isLast
            ? [ActionChipModel(id: "scan", label: "Scan mit svar", icon: "camera.fill", isPrimary: true)]
            : [ActionChipModel(id: "next_step", label: "Næste trin →", icon: "arrow.right", isPrimary: false)]

        messages.append(ChatMessage(
            sender: .kvante,
            content: .exampleStep(step, currentExampleStepIndex + 1, pendingExampleSteps.count),
            actions: chips
        ))

        currentExampleStepIndex += 1
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
            // Step 1: Try Apple OCR first (instant, on-device)
            let ocr = await HandwritingOCR.recognize(imageData: imageData)

            var readAnswer: String
            var source: String

            if !ocr.answer.isEmpty && !ocr.fullText.isEmpty {
                readAnswer = ocr.fullText
                source = "Apple OCR"
            } else {
                // Gemini fallback for reading
                do {
                    // Use submitWork just to read — but we need the answer text
                    let result = try await apiClient.submitWork(
                        sessionId: sessionId,
                        assignmentId: currentAssignment.id,
                        imageData: imageData
                    )
                    readAnswer = result.studentAnswer
                    source = "Gemini Vision"
                } catch {
                    replaceLoading(loadingId, with: ChatMessage(
                        sender: .kvante,
                        content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                    ))
                    return
                }
            }

            // Step 2: ALWAYS ask student to confirm
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

    /// Extract the final answer from full text (e.g. "50 + 30 = 80" → "80")
    private func extractAnswer(from text: String) -> String {
        if let equalsRange = text.range(of: "=", options: .backwards) {
            let after = String(text[equalsRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let firstToken = after.components(separatedBy: .whitespaces).first ?? after
            if !firstToken.isEmpty { return firstToken }
        }
        // Fallback: last number-like token
        let tokens = text.components(separatedBy: .whitespaces)
        if let last = tokens.last(where: { $0.first?.isNumber == true }) { return last }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Student confirmed the OCR reading is correct
    func confirmAnswer(_ fullText: String) {
        guard let imageData = pendingImageData else { return }

        let answer = extractAnswer(from: fullText)

        // Student confirms
        messages.append(ChatMessage(
            sender: .student,
            content: .text("Mit svar: \(fullText)")
        ))

        let loadingId = addLoading("Tjekker dit svar...")

        Task { @MainActor in
            do {
                let submission = try await apiClient.submitAnswer(
                    sessionId: sessionId,
                    assignmentId: currentAssignment.id,
                    answerText: answer,
                    fullOcrText: fullText,
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
