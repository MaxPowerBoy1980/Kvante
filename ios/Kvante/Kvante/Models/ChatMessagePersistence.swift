// ios/Kvante/Kvante/Models/ChatMessagePersistence.swift
import Foundation

extension ChatSender {
    var rawPersistenceString: String {
        switch self {
        case .kvante:  return "kvante"
        case .student: return "student"
        }
    }

    static func fromPersistenceString(_ s: String) -> ChatSender? {
        switch s {
        case "kvante":  return .kvante
        case "student": return .student
        default:        return nil
        }
    }
}

extension CelebrationTier {
    var rawPersistenceString: String {
        switch self {
        case .routine:     return "routine"
        case .persevered:  return "persevered"
        case .setComplete: return "set_complete"
        }
    }

    static func fromPersistenceString(_ s: String) -> CelebrationTier? {
        switch s {
        case "routine":     return .routine
        case "persevered":  return .persevered
        case "set_complete": return .setComplete
        default:            return nil
        }
    }
}

extension ChatMessage {
    /// Konverterer beskeden til en backend-DTO. Returnerer nil for cases vi
    /// ikke persisterer (loading, ocrConfirm, example, exampleStep) eller for
    /// scannedImage der endnu ikke har en scan_id.
    func toCreateDTO() -> ChatMessageCreate? {
        let senderStr = sender.rawPersistenceString

        switch content {
        case .text(let s):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "text",
                content: ["text": .string(s)],
                assignmentId: assignmentId
            )

        case .assignmentIntro(let parsed):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "assignment_intro",
                content: [
                    "assignment_id":        .string(parsed.id),
                    "local_id":             .string(parsed.localId),
                    "text":                 .string(parsed.text),
                    "type":                 .string(parsed.type),
                    "topic":                .string(parsed.topic),
                    "difficulty_estimate":  .int(parsed.difficultyEstimate),
                ],
                assignmentId: parsed.id
            )

        case .scannedImage(_, let scanId):
            guard let scanId else { return nil }
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "scanned_image",
                content: ["scan_id": .string(scanId)],
                assignmentId: assignmentId
            )

        case .feedback(let fb):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "feedback",
                content: [
                    "feedback_text": .string(fb.feedbackText),
                    "tone":          .string(fb.tone),
                ],
                assignmentId: assignmentId
            )

        case .answerResult(let r):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "answer_result",
                content: [
                    "correct":         .bool(r.isCorrect),
                    "student_answer":  .string(r.studentAnswer),
                    "expected_answer": .string(r.correctAnswer),
                    "message":         .string(r.message),
                ],
                assignmentId: assignmentId
            )

        case .tip(let s):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "tip",
                content: ["text": .string(s)],
                assignmentId: assignmentId
            )

        case .celebration(let tier):
            return ChatMessageCreate(
                sender: senderStr,
                contentType: "celebration",
                content: ["tier": .string(tier.rawPersistenceString)],
                assignmentId: assignmentId
            )

        // Ikke persisteret — transient UI
        case .loading, .ocrConfirm, .example, .exampleStep:
            return nil
        }
    }
}

extension ChatMessage {
    /// Rekonstruerer en ChatMessage fra backend-DTO. Returnerer nil hvis
    /// content_type er ukendt eller påkrævede felter mangler — disse
    /// beskeder springes over i reload.
    static func fromLoadedDTO(
        _ dto: ChatMessageOut,
        assignments: [String: ParsedAssignment]
    ) -> ChatMessage? {
        guard let sender = ChatSender.fromPersistenceString(dto.sender) else { return nil }

        let content: ChatMessageContent
        switch dto.contentType {
        case "text":
            guard let text = dto.content["text"]?.stringValue else { return nil }
            content = .text(text)

        case "assignment_intro":
            guard let assignmentId = dto.content["assignment_id"]?.stringValue,
                  let localId = dto.content["local_id"]?.stringValue,
                  let text = dto.content["text"]?.stringValue,
                  let type = dto.content["type"]?.stringValue,
                  let topic = dto.content["topic"]?.stringValue,
                  let difficulty = dto.content["difficulty_estimate"]?.intValue
            else { return nil }
            // Prefer eksisterende assignment fra dictionary hvis det findes
            // (har mere komplet position_on_page-data end det persisterede)
            let parsed = assignments[assignmentId] ?? ParsedAssignment(
                id: assignmentId,
                localId: localId,
                text: text,
                type: type,
                topic: topic,
                difficultyEstimate: difficulty,
                positionOnPage: ""
            )
            content = .assignmentIntro(parsed)

        case "scanned_image":
            guard let scanId = dto.content["scan_id"]?.stringValue else { return nil }
            content = .scannedImage(nil, scanId: scanId)

        case "feedback":
            guard let feedbackText = dto.content["feedback_text"]?.stringValue else { return nil }
            let tone = dto.content["tone"]?.stringValue ?? "warm"
            let fb = FeedbackResponse(
                feedbackText: feedbackText,
                tone: tone,
                structuredPrompts: []  // ikke persisteret, genopbygges ikke
            )
            content = .feedback(fb)

        case "answer_result":
            guard let correct = dto.content["correct"]?.boolValue,
                  let studentAnswer = dto.content["student_answer"]?.stringValue,
                  let expectedAnswer = dto.content["expected_answer"]?.stringValue
            else { return nil }
            let message = dto.content["message"]?.stringValue ?? ""
            content = .answerResult(AnswerResult(
                studentAnswer: studentAnswer,
                correctAnswer: expectedAnswer,
                isCorrect: correct,
                message: message,
                source: "",
                ocrDebug: ""
            ))

        case "tip":
            guard let text = dto.content["text"]?.stringValue else { return nil }
            content = .tip(text)

        case "celebration":
            guard let tierStr = dto.content["tier"]?.stringValue,
                  let tier = CelebrationTier.fromPersistenceString(tierStr)
            else { return nil }
            content = .celebration(tier)

        default:
            return nil  // Ukendt content_type — skip
        }

        // Generér en frisk UUID ved reload. Backend-id'et er ikke relevant for
        // iOS-side identity; kun rækkefølgen er autoritativ.
        return ChatMessage(
            id: UUID(),
            sender: sender,
            content: content,
            timestamp: Date(),  // backend created_at er kun til ordering
            actions: [],
            assignmentId: dto.assignmentId
        )
    }
}
