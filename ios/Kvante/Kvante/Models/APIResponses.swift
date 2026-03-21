import Foundation

// MARK: - Page Scan

struct PageScanResponse: Codable {
    let sessionId: String
    let assignments: [ParsedAssignment]
    let pageContext: String
    let suggestedOrder: [String]
    let suggestedStart: String
    let reasoning: String
    let detectedLanguage: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case assignments
        case pageContext = "page_context"
        case suggestedOrder = "suggested_order"
        case suggestedStart = "suggested_start"
        case reasoning
        case detectedLanguage = "detected_language"
    }
}

struct ParsedAssignment: Codable, Identifiable {
    let id: String
    let localId: String
    let text: String
    let type: String
    let topic: String
    let difficultyEstimate: Int
    let positionOnPage: String

    enum CodingKeys: String, CodingKey {
        case id, text, type, topic
        case localId = "local_id"
        case difficultyEstimate = "difficulty_estimate"
        case positionOnPage = "position_on_page"
    }
}

// MARK: - Example

struct ExampleResponse: Codable {
    let exampleProblem: String
    let steps: [ExampleStep]
    let note: String

    enum CodingKeys: String, CodingKey {
        case exampleProblem = "example_problem"
        case steps, note
    }
}

// MARK: - Submission

struct SubmissionResponse: Codable {
    let submissionId: String
    let assignmentId: String
    let sessionId: String
    let studentAnswer: String
    let methodologySound: Bool
    let stepsIdentified: [AnalysisStep]
    let errors: [String]
    let correctElements: [String]
    let methodologyAssessment: String
    let handwritingNote: String
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case submissionId = "submission_id"
        case assignmentId = "assignment_id"
        case sessionId = "session_id"
        case studentAnswer = "student_answer"
        case methodologySound = "methodology_sound"
        case stepsIdentified = "steps_identified"
        case errors
        case correctElements = "correct_elements"
        case methodologyAssessment = "methodology_assessment"
        case handwritingNote = "handwriting_note"
        case confidence
    }
}

struct AnalysisStep: Codable, Identifiable {
    var id: Int { step }
    let step: Int
    let description: String
    let correct: Bool
}

// MARK: - Feedback

struct FeedbackResponse: Codable {
    let feedbackText: String
    let tone: String
    let structuredPrompts: [StructuredPrompt]

    enum CodingKeys: String, CodingKey {
        case feedbackText = "feedback_text"
        case tone
        case structuredPrompts = "structured_prompts"
    }
}

struct StructuredPrompt: Codable, Identifiable {
    var id: String { promptId }
    let promptId: String
    let label: String

    enum CodingKeys: String, CodingKey {
        case promptId = "id"
        case label
    }
}

// MARK: - Health

struct HealthResponse: Codable {
    let status: String
    let version: String
}

// MARK: - Error

struct APIError: Codable {
    let error: String
    let message: String
    let studentMessage: String
    let detail: String

    enum CodingKeys: String, CodingKey {
        case error, message
        case studentMessage = "student_message"
        case detail
    }
}
