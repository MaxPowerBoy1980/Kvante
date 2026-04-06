import Foundation

enum ChatSender {
    case kvante
    case student
}

enum CelebrationTier {
    case routine
    case persevered
    case setComplete
}

enum ChatMessageContent {
    case text(String)
    case example(ExampleResponse)
    case exampleStep(AnimationStep, Int, Int, GridState?)  // step, stepNumber, totalSteps, gridState
    case scannedImage(Data)
    case feedback(FeedbackResponse)
    case ocrConfirm(OcrConfirmation)
    case answerResult(AnswerResult)
    case loading(String)
    case assignmentIntro(ParsedAssignment)
    case tip(String)
    case celebration(CelebrationTier)
}

struct OcrConfirmation {
    let readText: String
    let imageData: Data
    let source: String
}

struct AnswerResult {
    let studentAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
    let message: String
    var source: String = ""    // "Apple OCR" or "Gemini Vision"
    var ocrDebug: String = ""  // What Apple OCR read: "17 + 52 = 69"
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: ChatSender
    let content: ChatMessageContent
    let timestamp = Date()
    var actions: [ActionChipModel] = []
}

struct ActionChipModel: Identifiable {
    let id: String
    let label: String
    let icon: String
    let isPrimary: Bool

    static func fromPrompt(_ prompt: StructuredPrompt) -> ActionChipModel {
        let icon: String
        switch prompt.promptId {
        case "explain_different": icon = "arrow.triangle.2.circlepath"
        case "another_example": icon = "lightbulb.fill"
        case "show_first_step": icon = "1.circle.fill"
        case "what_did_well": icon = "hand.thumbsup.fill"
        case "try_again": icon = "arrow.counterclockwise"
        case "next_assignment": icon = "arrow.right.circle.fill"
        default: icon = "questionmark.circle"
        }
        return ActionChipModel(
            id: prompt.promptId,
            label: prompt.label,
            icon: icon,
            isPrimary: prompt.promptId == "next_assignment"
        )
    }
}
