import Foundation
import SwiftUI

@Observable
class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var isLoading = false
    var isLoadingHistory = true
    var showScanner = false
    var inputText = ""

    private var syncedMessageIds: Set<UUID> = []
    private var isSyncing = false
    private var pendingSync = false

    // MARK: - Context

    // Multi-assignment state
    private(set) var allAssignments: [ParsedAssignment]
    var currentAssignmentIndex: Int = 0
    var completedAssignmentIds: Set<String> = []
    var attemptCounts: [String: Int] = [:]

    var currentAssignment: ParsedAssignment {
        allAssignments[currentAssignmentIndex]
    }

    var totalAssignments: Int { allAssignments.count }
    var completedCount: Int { completedAssignmentIds.count }
    var isSetComplete: Bool { completedAssignmentIds.count == allAssignments.count }

    let sessionId: String
    let apiClient: APIClient

    // Track submission for follow-ups
    private var currentSubmissionId: String?

    /// Whether current assignment uses stacked arithmetic (numbers > 30)
    private var isStackedArithmetic: Bool {
        let text = currentAssignment.text
        let topic = currentAssignment.topic
        let isAddSub = topic == "addition" || topic == "subtraction"
            || text.contains("+") || text.contains("-")
        let numbers = text.matches(of: /\d+/).compactMap { Int(String($0.output)) }
        return isAddSub && numbers.contains(where: { $0 > 30 })
    }

    /// Whether current assignment is multiplication (×, ·, or *)
    private var isMultiplicationAssignment: Bool {
        let text = currentAssignment.text
        let topic = currentAssignment.topic
        if topic == "multiplication" { return true }
        // Match × (U+00D7) or middle dot. Skip ASCII '*' since it's also used
        // as a bullet/wildcard in non-math text — multiplication tasks always
        // use × in our seed data and parsed pages.
        return text.contains("×") || text.contains("·")
    }

    /// Whether the current assignment's handwritten work needs Vision OCR.
    /// Apple OCR can't read columnar layouts (stacked addition/subtraction
    /// or long multiplication with mente notation).
    private var needsVisionOCR: Bool {
        isStackedArithmetic || isMultiplicationAssignment
    }

    var onSetComplete: (() -> Void)?

    // MARK: - Init

    init(assignments: [ParsedAssignment], sessionId: String, apiClient: APIClient) {
        self.allAssignments = assignments
        self.sessionId = sessionId
        self.apiClient = apiClient

        Task { @MainActor in
            await loadExistingMessages()
            if messages.isEmpty {
                sendWelcome()
            }
            isLoadingHistory = false
        }
    }

    // MARK: - Welcome

    private func sendWelcome() {
        let intro = ChatMessage(
            sender: .kvante,
            content: .assignmentIntro(currentAssignment)
        )
        appendMessage(intro)

        let welcome = ChatMessage(
            sender: .kvante,
            content: .text("Hej! Klar til at kigge på denne opgave? Løs den med blyant og papir, og scan dit svar når du er klar. Tryk + hvis du har brug for hjælp 🤖")
        )
        appendMessage(welcome)
    }

    // MARK: - Multi-assignment Navigation

    func advanceToNextAssignment() {
        completedAssignmentIds.insert(currentAssignment.id)

        if isSetComplete {
            let celebration = ChatMessage(
                sender: .kvante,
                content: .celebration(.setComplete)
            )
            appendMessage(celebration)
            onSetComplete?()
            return
        }

        // Move to next unfinished assignment
        if currentAssignmentIndex < allAssignments.count - 1 {
            currentAssignmentIndex += 1
        }

        // Reset submission tracking for new assignment
        currentSubmissionId = nil

        // Introduce next assignment in chat
        let intro = ChatMessage(
            sender: .kvante,
            content: .assignmentIntro(currentAssignment)
        )
        appendMessage(intro)

        let prompt = ChatMessage(
            sender: .kvante,
            content: .text("Her er din næste opgave. Brug + knappen for at scanne dit svar eller bede om hjælp.")
        )
        appendMessage(prompt)
    }

    func jumpToAssignment(_ index: Int) {
        guard index >= 0 && index < allAssignments.count else { return }
        currentAssignmentIndex = index
        currentSubmissionId = nil

        // If not yet introduced, introduce it
        let assignment = allAssignments[index]
        let alreadyIntroduced = messages.contains { msg in
            if case .assignmentIntro(let a) = msg.content {
                return a.id == assignment.id
            }
            return false
        }
        if !alreadyIntroduced {
            appendMessage(ChatMessage(sender: .kvante, content: .assignmentIntro(assignment)))
        }
    }

    func requestExplainDifferent() {
        guard let submissionId = currentSubmissionId else {
            appendMessage(ChatMessage(sender: .kvante, content: .text("Prøv først at løse opgaven, så kan jeg forklare på en anden måde.")))
            return
        }
        let loadingId = addLoading("Kvante tænker...")
        Task { @MainActor in
            do {
                let response = try await apiClient.sendFollowup(submissionId: submissionId, action: "explain_different")
                replaceLoading(loadingId, with: ChatMessage(sender: .kvante, content: .feedback(response)))
            } catch {
                replaceLoading(loadingId, with: ChatMessage(sender: .kvante, content: .text("Beklager, jeg kunne ikke forklare på en anden måde lige nu.")))
            }
        }
    }

    // MARK: - Actions

    func handleChip(_ chip: ActionChipModel) {
        switch chip.id {
        case "help":
            requestHelp()
        case "scan":
            showScanner = true
        case "next_assignment":
            advanceToNextAssignment()
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

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""

        appendMessage(ChatMessage(sender: .student, content: .text(text)))
        let loadingId = addLoading("Kvante tænker...")

        Task { @MainActor in
            do {
                let reply = try await apiClient.sendChat(
                    sessionId: sessionId,
                    assignmentId: currentAssignment.id,
                    message: text
                )
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text(reply)
                ))
            } catch {
                replaceLoading(loadingId, with: ChatMessage(
                    sender: .kvante,
                    content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                ))
            }
        }
    }

    // Pending example steps for step-by-step reveal
    private var pendingExampleSteps: [AnimationStep] = []
    private var currentExampleStepIndex = 0

    func requestHelp() {
        // Student message
        appendMessage(ChatMessage(
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
                    content: .text("Her er et eksempel med andre tal: \(example.exampleProblem)")
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

        // Build cumulative state for stacked arithmetic, short division, and long multiplication
        var gridState: GridState? = nil
        var shortDivisionState: ShortDivisionState? = nil
        var longMultState: LongMultiplicationState? = nil
        var arrayGridState: ArrayGridState? = nil
        for i in 0...currentExampleStepIndex {
            let s = pendingExampleSteps[i]
            guard let v = s.visual else { continue }
            if v.type == "stacked_arithmetic" {
                if v.action == "setup" {
                    gridState = GridState.from(visual: v)
                }
                gridState?.apply(visual: v)
            } else if v.type == "short_division" {
                if v.action == "setup" {
                    shortDivisionState = ShortDivisionState.from(visual: v)
                }
                shortDivisionState?.apply(visual: v)
            } else if v.type == "long_multiplication" {
                if v.action == "setup" {
                    longMultState = LongMultiplicationState.from(visual: v)
                }
                longMultState?.apply(visual: v)
            } else if v.type == "single_digit_array" {
                if v.action == "setup" {
                    arrayGridState = ArrayGridState.from(visual: v)
                }
                arrayGridState?.apply(visual: v)
            }
        }

        let chips: [ActionChipModel] = isLast
            ? []
            : [ActionChipModel(id: "next_step", label: "Næste trin →", icon: "arrow.right", isPrimary: false)]

        appendMessage(ChatMessage(
            sender: .kvante,
            content: .exampleStep(step, currentExampleStepIndex + 1, pendingExampleSteps.count,
                                  gridState, shortDivisionState, longMultState, arrayGridState),
            actions: chips
        ))

        currentExampleStepIndex += 1
    }

    // Pending image data for confirmation flow
    private var pendingImageData: Data?
    private var pendingOcrFullText: String = ""

    func scanAnswer(_ imageData: Data) {
        // Student message with scanned image
        appendMessage(ChatMessage(
            sender: .student,
            content: .scannedImage(imageData, scanId: nil)
        ))

        let loadingId = addLoading("Kvante tyder dit svar...")

        Task { @MainActor in
            var readAnswer: String
            var source: String

            // For columnar methods (stacked addition/subtraction with big numbers,
            // or long multiplication), use LLM Vision directly — Apple OCR can't
            // read columnar handwriting or mente notation.
            let useVision = needsVisionOCR

            if !useVision {
                // Simple problems: Apple OCR first (instant, on-device)
                let ocr = await HandwritingOCR.recognize(imageData: imageData, assignmentText: currentAssignment.text)
                if !ocr.answer.isEmpty && !ocr.fullText.isEmpty {
                    readAnswer = ocr.fullText
                    source = "Apple OCR"
                } else {
                    // Fall through to LLM Vision
                    do {
                        let result = try await apiClient.submitWork(
                            sessionId: sessionId,
                            assignmentId: currentAssignment.id,
                            imageData: imageData
                        )
                        readAnswer = result.studentAnswer
                        source = "Vision"
                    } catch {
                        replaceLoading(loadingId, with: ChatMessage(
                            sender: .kvante,
                            content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                        ))
                        return
                    }
                }
            } else {
                // Stacked arithmetic: LLM Vision reads the columnar handwriting.
                // submitWork already creates the submission and validates the answer.
                attemptCounts[currentAssignment.id, default: 0] += 1
                do {
                    let result = try await apiClient.submitWork(
                        sessionId: sessionId,
                        assignmentId: currentAssignment.id,
                        imageData: imageData
                    )
                    currentSubmissionId = result.submissionId
                    pendingImageData = nil

                    // Show result directly — no confirmation needed
                    showAnswerResult(
                        studentAnswer: result.studentAnswer,
                        correctAnswer: result.correctAnswer,
                        isCorrect: result.methodologySound,
                        source: "Vision",
                        ocrDebug: "",
                        loadingId: loadingId
                    )

                    // For correct columnar work: show completed grid (stacked) +
                    // explanation, or just the explanation text (multiplication).
                    if result.methodologySound {
                        let explanation = buildStackedExplanation(
                            answer: result.studentAnswer
                        )
                        let text = currentAssignment.text
                        let numbers = text.matches(of: /\d+/).compactMap { Int(String($0.output)) }

                        if isMultiplicationAssignment {
                            // No completed long-multiplication grid yet — just praise.
                            appendMessage(ChatMessage(
                                sender: .kvante,
                                content: .text(explanation),
                                actions: [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
                            ))
                        } else if numbers.count >= 2 {
                            // Stacked addition/subtraction: render the filled grid.
                            let a = numbers[0], b = numbers[1]
                            let topic = currentAssignment.topic
                            let op = (topic == "addition" || text.contains("+")) ? "addition" : "subtraction"
                            let completedState = GridState.completed(a: a, b: b, operation: op)

                            // Create a dummy visual instruction for the setup
                            let dummyVisual = VisualInstruction.make(
                                type: "stacked_arithmetic", action: "answer"
                            )
                            let step = AnimationStep(
                                step: 1, phase: "concrete",
                                text: explanation,
                                visual: dummyVisual,
                                audioCue: ""
                            )
                            appendMessage(ChatMessage(
                                sender: .kvante,
                                content: .exampleStep(step, 1, 1, completedState, nil, nil, nil),
                                actions: [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
                            ))
                        } else {
                            appendMessage(ChatMessage(
                                sender: .kvante,
                                content: .text(explanation),
                                actions: [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
                            ))
                        }
                    }

                    // Request feedback for wrong answers
                    if !result.methodologySound {
                        let feedbackLoadingId = addLoading("Kvante kigger på din metode...")
                        do {
                            let feedback = try await apiClient.getFeedback(
                                submissionId: result.submissionId
                            )
                            let chips = feedback.structuredPrompts.map { ActionChipModel.fromPrompt($0) }
                            replaceLoading(feedbackLoadingId, with: ChatMessage(
                                sender: .kvante,
                                content: .feedback(feedback),
                                actions: chips
                            ))
                        } catch {
                            replaceLoading(feedbackLoadingId, with: ChatMessage(
                                sender: .kvante,
                                content: .text("Prøv igen — tryk + for hjælp hvis du sidder fast.")
                            ))
                        }
                    }
                } catch {
                    replaceLoading(loadingId, with: ChatMessage(
                        sender: .kvante,
                        content: .text("Hovsa, noget gik galt: \(error.localizedDescription)")
                    ))
                }
                return
            }

            // Step 2: For non-stacked, ask student to confirm OCR
            pendingImageData = imageData
            pendingOcrFullText = readAnswer

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
        attemptCounts[currentAssignment.id, default: 0] += 1

        let answer = extractAnswer(from: fullText)

        // Student confirms
        appendMessage(ChatMessage(
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

                // Request feedback for wrong answers
                if !submission.methodologySound {
                    let feedbackLoadingId = addLoading("Kvante kigger på din metode...")
                    do {
                        let feedback = try await apiClient.getFeedback(
                            submissionId: submission.submissionId
                        )
                        let chips = feedback.structuredPrompts.map { ActionChipModel.fromPrompt($0) }
                        replaceLoading(feedbackLoadingId, with: ChatMessage(
                            sender: .kvante,
                            content: .feedback(feedback),
                            actions: chips
                        ))
                    } catch {
                        replaceLoading(feedbackLoadingId, with: ChatMessage(
                            sender: .kvante,
                            content: .text("Prøv igen — tryk + for hjælp hvis du sidder fast.")
                        ))
                    }
                }
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

        let chips: [ActionChipModel] = []  // chips moved to celebration

        replaceLoading(loadingId, with: ChatMessage(
            sender: .kvante,
            content: .answerResult(result),
            actions: chips
        ))

        // Add celebration for correct answers
        if isCorrect {
            let attempts = attemptCounts[currentAssignment.id, default: 1]
            let tier: CelebrationTier = attempts >= 2 ? .persevered : .routine
            appendMessage(ChatMessage(
                sender: .kvante,
                content: .celebration(tier),
                actions: [ActionChipModel(id: "next_assignment", label: "Næste opgave", icon: "arrow.right.circle.fill", isPrimary: true)]
            ))
        }
    }

    /// Build a deterministic explanation of how the student solved a columnar
    /// arithmetic problem (stacked addition/subtraction or long multiplication).
    private func buildStackedExplanation(answer: String) -> String {
        let text = currentAssignment.text
        let numbers = text.matches(of: /\d+/).compactMap { Int(String($0.output)) }
        guard numbers.count >= 2 else {
            return "Flot! Du har løst opgaven korrekt ved at stille tallene op i kolonner."
        }

        let a = numbers[0]
        let b = numbers[1]

        // Multiplication path: praise for delprodukter + sum
        if isMultiplicationAssignment {
            let result = a * b
            return "Du stillede \(a) og \(b) op og gangede dem ciffer for ciffer med delprodukter. Det gav \(result) — helt rigtigt!"
        }

        let topic = currentAssignment.topic
        let isAddition = topic == "addition" || text.contains("+")
        let op = isAddition ? "plus" : "minus"
        let result = isAddition ? a + b : a - b

        // Check if there were carries/borrows
        var hasCarry = false
        if isAddition {
            let aDigits = String(a).map { Int(String($0))! }
            let bDigits = String(b).map { Int(String($0))! }
            let maxLen = max(aDigits.count, bDigits.count)
            let aPadded = Array(repeating: 0, count: maxLen - aDigits.count) + aDigits
            let bPadded = Array(repeating: 0, count: maxLen - bDigits.count) + bDigits
            for i in stride(from: maxLen - 1, through: 0, by: -1) {
                if aPadded[i] + bPadded[i] >= 10 { hasCarry = true; break }
            }
        }

        if hasCarry {
            return "Du stillede \(a) og \(b) op i kolonner, lagde sammen fra enerne og brugte mente til at flytte tiere videre. Det gav \(result) — helt rigtigt!"
        } else {
            return "Du stillede \(a) og \(b) op i kolonner og lagde dem \(op) kolonne for kolonne. Det gav \(result) — helt rigtigt!"
        }
    }

    private func handleFollowup(_ actionId: String) {
        guard let submissionId = currentSubmissionId else { return }

        // Student message
        let chipLabel = messages.last?.actions.first(where: { $0.id == actionId })?.label ?? actionId
        appendMessage(ChatMessage(
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
        appendMessage(ChatMessage(
            sender: .kvante,
            content: .text("Godt, prøv igen! Scan dit nye svar med + knappen når du er klar 🤖")
        ))
    }

    // MARK: - Persistence

    /// Append en besked til messages[] og tag automatisk currentAssignmentId
    /// hvis beskeden ikke selv har et. Alle eksisterende messages.append-kald
    /// skal gå gennem denne metode (Task 14).
    private func appendMessage(_ msg: ChatMessage) {
        var tagged = msg
        if tagged.assignmentId == nil {
            tagged.assignmentId = currentAssignment.id
        }
        messages.append(tagged)
        syncUnsavedMessages()
    }

    /// Kald dette når en eksisterende besked muterer i-place (fx scanId sat
    /// efter upload er færdig). syncUnsavedMessages tager sig af at plukke de
    /// muterede beskeder op næste gang.
    private func syncUnsavedMessages() {
        if isSyncing {
            pendingSync = true
            return
        }

        // Find unsynced messages og deres DTO-repræsentationer
        let unsynced = messages.filter { !syncedMessageIds.contains($0.id) }
        var pairs: [(id: UUID, dto: ChatMessageCreate)] = []
        for msg in unsynced {
            if let dto = msg.toCreateDTO() {
                pairs.append((msg.id, dto))
            }
        }

        if pairs.isEmpty {
            return  // ingen ændringer — messages med nil DTO forbliver uden for sættet
        }

        let toSave = pairs.map { $0.dto }
        let idsBeingSent = pairs.map { $0.id }
        isSyncing = true

        Task { @MainActor in
            defer {
                self.isSyncing = false
                if self.pendingSync {
                    self.pendingSync = false
                    self.syncUnsavedMessages()
                }
            }
            do {
                try await self.apiClient.saveMessages(sessionId: self.sessionId, messages: toSave)
                self.syncedMessageIds.formUnion(idsBeingSent)
            } catch {
                // Sættet rykker ikke; næste append eller mutation retrier
                print("[ChatViewModel] saveMessages failed: \(error)")
            }
        }
    }

    /// Load eksisterende historik fra backend. Kaldes én gang i init.
    private func loadExistingMessages() async {
        do {
            let dtos = try await apiClient.loadMessages(sessionId: sessionId)
            let byId = Dictionary(uniqueKeysWithValues: allAssignments.map { ($0.id, $0) })
            let loaded = dtos.compactMap { ChatMessage.fromLoadedDTO($0, assignments: byId) }
            self.messages = loaded
            self.syncedMessageIds = Set(loaded.map { $0.id })
        } catch {
            print("[ChatViewModel] loadMessages failed: \(error)")
            // Fail silently — messages forbliver tom, sendWelcome kaldes bagefter
        }
    }

    // MARK: - Loading Helpers

    @discardableResult
    private func addLoading(_ text: String) -> UUID {
        isLoading = true
        let msg = ChatMessage(sender: .kvante, content: .loading(text))
        appendMessage(msg)
        return msg.id
    }

    private func replaceLoading(_ id: UUID, with message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            var replacement = message
            if replacement.assignmentId == nil {
                replacement.assignmentId = currentAssignment.id
            }
            messages[index] = replacement
            syncUnsavedMessages()
        } else {
            appendMessage(message)
        }
        isLoading = false
    }
}
