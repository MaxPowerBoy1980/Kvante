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
