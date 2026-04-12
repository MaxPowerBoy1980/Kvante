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
    let pedagogy: String
    let steps: [AnimationStep]
    let note: String

    enum CodingKeys: String, CodingKey {
        case exampleProblem = "example_problem"
        case pedagogy, steps, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exampleProblem = try container.decode(String.self, forKey: .exampleProblem)
        pedagogy = try container.decodeIfPresent(String.self, forKey: .pedagogy) ?? "concrete-first"
        steps = try container.decode([AnimationStep].self, forKey: .steps)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

// MARK: - Submission

struct SubmissionResponse: Codable {
    let submissionId: String
    let assignmentId: String
    let sessionId: String
    let studentAnswer: String
    let correctAnswer: String
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
        case correctAnswer = "correct_answer"
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

// MARK: - Library

struct TopicInfo: Codable, Identifiable {
    var id: String { topic }
    let topic: String
    let name: String
    let icon: String
    let problemCount: Int
    let difficulties: [Int]
    let gradeLevels: [Int]

    enum CodingKeys: String, CodingKey {
        case topic, name, icon, difficulties
        case problemCount = "problem_count"
        case gradeLevels = "grade_levels"
    }
}

struct TopicsResponse: Codable {
    let topics: [TopicInfo]
}

// MARK: - Practice

struct PracticeAssignment: Codable, Identifiable {
    let id: String
    let problemId: String
    let localId: String
    let text: String
    let type: String
    let topic: String
    let difficultyEstimate: Int
    let position: Int?  // Add after difficultyEstimate — optional for backwards compat

    enum CodingKeys: String, CodingKey {
        case id, text, type, topic, position
        case problemId = "problem_id"
        case localId = "local_id"
        case difficultyEstimate = "difficulty_estimate"
    }
}

struct PracticeSessionResponse: Codable {
    let sessionId: String
    let assignments: [PracticeAssignment]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case assignments
    }
}

// MARK: - Scans

struct ScanUploadResponse: Codable {
    let scanId: String

    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"
    }
}

// MARK: - Chat Persistence

/// Typed leaf value for ChatMessage content dicts. Spec'et content schemas
/// bruger kun String, Int og Bool på leaf-niveau — ingen nested objekter eller
/// arrays. Derfor denne kompakte enum i stedet for en generisk AnyCodable.
enum ContentValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let b = try? c.decode(Bool.self)   { self = .bool(b);   return }
        if let i = try? c.decode(Int.self)    { self = .int(i);    return }
        throw DecodingError.typeMismatch(
            ContentValue.self,
            .init(codingPath: decoder.codingPath,
                  debugDescription: "Unsupported content value type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i):    try c.encode(i)
        case .bool(let b):   try c.encode(b)
        }
    }

    // Convenience accessors
    var stringValue: String? { if case .string(let s) = self { return s } else { return nil } }
    var intValue: Int? { if case .int(let i) = self { return i } else { return nil } }
    var boolValue: Bool? { if case .bool(let b) = self { return b } else { return nil } }
}

struct ChatMessageCreate: Codable {
    let sender: String           // "kvante" | "student"
    let contentType: String
    let content: [String: ContentValue]
    let assignmentId: String?

    enum CodingKeys: String, CodingKey {
        case sender
        case contentType = "content_type"
        case content
        case assignmentId = "assignment_id"
    }
}

struct ChatMessageOut: Codable {
    let id: String
    let sessionId: String
    let assignmentId: String?
    let sender: String
    let contentType: String
    let content: [String: ContentValue]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, sender, content
        case sessionId = "session_id"
        case assignmentId = "assignment_id"
        case contentType = "content_type"
        case createdAt = "created_at"
    }
}

struct SaveMessagesRequest: Codable {
    let sessionId: String
    let messages: [ChatMessageCreate]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case messages
    }
}

struct SaveMessagesResponse: Codable {
    let savedCount: Int

    enum CodingKeys: String, CodingKey {
        case savedCount = "saved_count"
    }
}

struct LoadMessagesResponse: Codable {
    let sessionId: String
    let messages: [ChatMessageOut]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case messages
    }
}

// MARK: - Student Registration

struct StudentRegistrationResponse: Codable {
    let studentId: String
    let name: String
    let gradeLevel: Int

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case name
        case gradeLevel = "grade_level"
    }
}

// MARK: - Conversions

extension ParsedAssignment {
    init(from practice: PracticeAssignment) {
        self.init(
            id: practice.id, localId: practice.localId,
            text: practice.text, type: practice.type,
            topic: practice.topic,
            difficultyEstimate: practice.difficultyEstimate,
            positionOnPage: ""
        )
    }
}

// MARK: - Streak

struct StreakInfo: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActiveDate: String?

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActiveDate = "last_active_date"
    }
}

// MARK: - Ark Overlay (Pakke 2a)

struct GearScore: Codable {
    let correctAnswer: Int
    let visibleMethod: Int
    let notation: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case correctAnswer = "correct_answer"
        case visibleMethod = "visible_method"
        case notation
        case total
    }
}

struct ArkAssignmentResponse: Codable {
    let id: String
    let localId: String
    let text: String
    let type: String
    let topic: String
    let difficultyEstimate: Int
    let position: Int

    let arkStatus: String
    let latestScanId: String?
    let latestAiFeedbackSummary: String?
    let teacherComment: String?
    let correctAnswer: String?
    let studentAnswer: String?
    let gearScore: GearScore?
    let improvementTip: String?

    enum CodingKeys: String, CodingKey {
        case id, text, type, topic, position
        case localId = "local_id"
        case difficultyEstimate = "difficulty_estimate"
        case arkStatus = "ark_status"
        case latestScanId = "latest_scan_id"
        case latestAiFeedbackSummary = "latest_ai_feedback_summary"
        case teacherComment = "teacher_comment"
        case correctAnswer = "correct_answer"
        case studentAnswer = "student_answer"
        case gearScore = "gear_score"
        case improvementTip = "improvement_tip"
    }
}

struct SessionDetailResponse: Codable {
    let sessionId: String
    let sessionName: String
    let currentAssignmentIndex: Int
    let assignments: [ArkAssignmentResponse]
    let streak: StreakInfo?

    enum CodingKeys: String, CodingKey {
        case assignments, streak
        case sessionId = "session_id"
        case sessionName = "session_name"
        case currentAssignmentIndex = "current_assignment_index"
    }
}

// MARK: - Weekly / Session History

struct WeeklySessionResponse: Codable {
    let sessionId: String
    let name: String
    let assignments: [PracticeAssignment]

    enum CodingKeys: String, CodingKey {
        case name, assignments
        case sessionId = "session_id"
    }
}

struct SessionSummary: Codable, Identifiable {
    let sessionId: String
    let name: String
    let mode: String
    let topic: String?
    let status: String
    let assignmentCount: Int
    let completedCount: Int
    let createdAt: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case name, mode, topic, status
        case sessionId = "session_id"
        case assignmentCount = "assignment_count"
        case completedCount = "completed_count"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    var id: String { sessionId }
    var isCompleted: Bool { status == "completed" }

    var displayDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        if let date = formatter.date(from: createdAt) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "da_DK")
            df.dateFormat = "d. MMM"
            return df.string(from: date)
        }
        return ""
    }
}

struct SessionHistoryResponse: Codable {
    let sessions: [SessionSummary]
}

/// Extended session summary with inline assignments (used by notebook).
struct SessionSummaryWithAssignments: Codable, Identifiable {
    let sessionId: String
    let name: String
    let mode: String
    let topic: String?
    let status: String
    let assignmentCount: Int
    let completedCount: Int
    let createdAt: String
    let completedAt: String?
    let assignments: [ArkAssignmentResponse]
    let currentAssignmentIndex: Int

    enum CodingKeys: String, CodingKey {
        case name, mode, topic, status, assignments
        case sessionId = "session_id"
        case assignmentCount = "assignment_count"
        case completedCount = "completed_count"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case currentAssignmentIndex = "current_assignment_index"
    }

    var id: String { sessionId }
}

/// Response for session history with inline assignments.
struct SessionHistoryWithAssignmentsResponse: Codable {
    let sessions: [SessionSummaryWithAssignments]
}

// MARK: - Bulk Scan (Pakke 4)

struct BulkSubmitResult: Codable, Identifiable {
    let assignmentId: String
    let assignmentText: String
    let studentAnswer: String?
    let status: String  // correct, incorrect, uncertain, not_found
    let errorType: String?
    let errorDescription: String?
    let confidence: Double
    let pageIndex: Int?
    let submissionId: String?
    let boundingBox: [Double]?
    let gearScore: GearScore?
    let improvementTip: String?

    var id: String { assignmentId }

    enum CodingKeys: String, CodingKey {
        case assignmentText = "assignment_text"
        case assignmentId = "assignment_id"
        case studentAnswer = "student_answer"
        case status
        case errorType = "error_type"
        case errorDescription = "error_description"
        case confidence
        case pageIndex = "page_index"
        case submissionId = "submission_id"
        case boundingBox = "bounding_box"
        case gearScore = "gear_score"
        case improvementTip = "improvement_tip"
    }
}

struct BulkSubmitSummary: Codable {
    let total: Int
    let correct: Int
    let incorrect: Int
    let uncertain: Int
    let notFound: Int

    enum CodingKeys: String, CodingKey {
        case total, correct, incorrect, uncertain
        case notFound = "not_found"
    }
}

struct BulkSubmitResponse: Codable {
    let sessionId: String
    let results: [BulkSubmitResult]
    let summary: BulkSubmitSummary
    let scanIds: [String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case results, summary
        case scanIds = "scan_ids"
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
