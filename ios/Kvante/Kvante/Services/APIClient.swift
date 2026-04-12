import Foundation
import UIKit

actor APIClient {
    let baseURL: URL
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    private let timeout: TimeInterval = 30
    private let aiTimeout: TimeInterval = 90

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // MARK: - Health

    func checkHealth() async throws -> HealthResponse {
        let url = baseURL.appendingPathComponent("health")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(HealthResponse.self, from: data)
    }

    // MARK: - Page Scan

    func scanPage(imageData: Data) async throws -> PageScanResponse {
        let url = baseURL.appendingPathComponent("pages/scan")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"page.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(PageScanResponse.self, from: data)
    }

    // MARK: - Example

    func getExample(sessionId: String, assignmentId: String) async throws -> ExampleResponse {
        let url = baseURL
            .appendingPathComponent("sessions/\(sessionId)/assignments/\(assignmentId)/example")
        var request = URLRequest(url: url, timeoutInterval: aiTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(ExampleResponse.self, from: data)
    }

    // MARK: - Explain Task

    func explainTask(sessionId: String, assignmentId: String) async throws -> FeedbackResponse {
        let url = baseURL
            .appendingPathComponent("sessions/\(sessionId)/assignments/\(assignmentId)/explain")
        var request = URLRequest(url: url, timeoutInterval: aiTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(FeedbackResponse.self, from: data)
    }

    // MARK: - Chat

    func sendChat(sessionId: String, assignmentId: String, message: String) async throws -> String {
        let url = baseURL.appendingPathComponent("chat/")
        var request = URLRequest(url: url, timeoutInterval: aiTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "session_id": sessionId,
            "assignment_id": assignmentId,
            "message": message
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        let result = try decoder.decode([String: String].self, from: data)
        return result["reply"] ?? ""
    }

    // MARK: - Submit Work

    func submitWork(sessionId: String, assignmentId: String, imageData: Data) async throws -> SubmissionResponse {
        let url = baseURL.appendingPathComponent("submissions/")
        var request = URLRequest(url: url, timeoutInterval: aiTimeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // session_id field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n")
        body.append(sessionId)
        body.append("\r\n")
        // assignment_id field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"assignment_id\"\r\n\r\n")
        body.append(assignmentId)
        body.append("\r\n")
        // image file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"work.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(SubmissionResponse.self, from: data)
    }

    // MARK: - Scan Upload

    func uploadScan(imageData: Data) async throws -> ScanUploadResponse {
        let url = baseURL.appendingPathComponent("scans/upload")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(ScanUploadResponse.self, from: data)
    }

    func scanImageURL(scanId: String) -> URL {
        baseURL.appendingPathComponent("scans/\(scanId)/image")
    }

    func cropImageURL(scanId: String, region: CropRegion, padding: Double = 0.08) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("scans/\(scanId)/crop"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "x", value: String(format: "%.4f", region.x)),
            URLQueryItem(name: "y", value: String(format: "%.4f", region.y)),
            URLQueryItem(name: "w", value: String(format: "%.4f", region.width)),
            URLQueryItem(name: "h", value: String(format: "%.4f", region.height)),
            URLQueryItem(name: "padding", value: String(format: "%.2f", padding)),
        ]
        return components.url!
    }

    // MARK: - Chat Persistence

    func saveMessages(sessionId: String, messages: [ChatMessageCreate]) async throws {
        let url = baseURL.appendingPathComponent("chat/messages/save")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SaveMessagesRequest(sessionId: sessionId, messages: messages)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        _ = try decoder.decode(SaveMessagesResponse.self, from: data)
    }

    func loadMessages(sessionId: String) async throws -> [ChatMessageOut] {
        let url = baseURL.appendingPathComponent("chat/messages/\(sessionId)")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        let payload = try decoder.decode(LoadMessagesResponse.self, from: data)
        return payload.messages
    }

    // MARK: - Feedback

    func getFeedback(submissionId: String, language: String = "da") async throws -> FeedbackResponse {
        let url = baseURL.appendingPathComponent("feedback/")
        var request = URLRequest(url: url, timeoutInterval: aiTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["submission_id": submissionId, "language": language]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(FeedbackResponse.self, from: data)
    }

    // MARK: - Followup

    func sendFollowup(submissionId: String, action: String) async throws -> FeedbackResponse {
        let url = baseURL.appendingPathComponent("feedback/\(submissionId)/followup")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["action": action]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(FeedbackResponse.self, from: data)
    }

    // MARK: - Submit Answer (text only, no image analysis needed)

    func submitAnswer(sessionId: String, assignmentId: String, answerText: String, fullOcrText: String, imageData: Data) async throws -> SubmissionResponse {
        let url = baseURL.appendingPathComponent("submissions/")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // session_id
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"session_id\"\r\n\r\n")
        body.append(sessionId)
        body.append("\r\n")
        // assignment_id
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"assignment_id\"\r\n\r\n")
        body.append(assignmentId)
        body.append("\r\n")
        // answer_text (extracted answer)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"answer_text\"\r\n\r\n")
        body.append(answerText)
        body.append("\r\n")
        // full_ocr_text (everything the student wrote)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"full_ocr_text\"\r\n\r\n")
        body.append(fullOcrText)
        body.append("\r\n")
        // image (saved for reference and LLM feedback)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"work.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(SubmissionResponse.self, from: data)
    }

    // MARK: - Library

    func getTopics() async throws -> TopicsResponse {
        let url = baseURL.appendingPathComponent("library/topics")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(TopicsResponse.self, from: data)
    }

    // MARK: - Student Registration

    func registerStudent(name: String, gradeLevel: Int) async throws -> StudentRegistrationResponse {
        let url = baseURL.appendingPathComponent("students/register")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["name": name, "grade_level": gradeLevel]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(StudentRegistrationResponse.self, from: data)
    }

    // MARK: - Practice Session

    func createPracticeSession(studentId: String, topic: String, difficulty: Int, count: Int = 5) async throws -> PracticeSessionResponse {
        let url = baseURL.appendingPathComponent("sessions/practice")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "student_id": studentId,
            "topic": topic,
            "difficulty": difficulty,
            "count": count,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(PracticeSessionResponse.self, from: data)
    }

    // MARK: - Weekly Assignments

    func createWeeklySession(studentId: String, gradeLevel: Int, count: Int = 6) async throws -> WeeklySessionResponse {
        let body: [String: Any] = [
            "student_id": studentId,
            "grade_level": gradeLevel,
            "count": count,
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: baseURL.appendingPathComponent("sessions/weekly"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 30
        let (responseData, response) = try await session.data(for: request)
        try checkResponse(response, data: responseData)
        return try decoder.decode(WeeklySessionResponse.self, from: responseData)
    }

    func getSessionHistory(studentId: String, limit: Int = 20) async throws -> SessionHistoryResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("students/\(studentId)/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(SessionHistoryResponse.self, from: data)
    }

    func getSessionHistoryWithAssignments(studentId: String) async throws -> SessionHistoryWithAssignmentsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("students/\(studentId)/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "0"),
            URLQueryItem(name: "include", value: "assignments"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(SessionHistoryWithAssignmentsResponse.self, from: data)
    }

    /// Fetch an existing session and its assignments with ark-overlay fields.
    /// Used to enter/re-enter a session from the history list.
    func getSession(sessionId: String) async throws -> SessionDetailResponse {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(SessionDetailResponse.self, from: data)
    }

    func completeSession(sessionId: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("sessions/\(sessionId)/complete"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }

    // MARK: - Bulk Scan

    func bulkSubmit(sessionId: String, images: [Data]) async throws -> BulkSubmitResponse {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)/bulk-submit")
        var request = URLRequest(url: url, timeoutInterval: 60)  // 60s for multi-image AI
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (i, imageData) in images.enumerated() {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"images\"; filename=\"page\(i).jpg\"\r\n")
            body.append("Content-Type: image/jpeg\r\n\r\n")
            body.append(imageData)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try decoder.decode(BulkSubmitResponse.self, from: data)
    }

    // MARK: - Dev Screenshot

    #if DEBUG
    /// Upload a screenshot with an optional note to the dev endpoint.
    /// Used by the in-app shake-to-submit feature for sending visual feedback to Claude.
    func submitDevScreenshot(imageData: Data, note: String) async throws {
        let url = baseURL.appendingPathComponent("dev/screenshots")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"shot.png\"\r\n")
        body.append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"note\"\r\n\r\n")
        body.append(note)
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }

    /// Upload a TODO (required note, optional image) to /dev/todos.
    /// Used by the new Kvante-capture-knap for note-first TODO inbox.
    func submitDevTodo(note: String, imageData: Data?) async throws {
        let url = baseURL.appendingPathComponent("dev/todos")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // note field (required)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"note\"\r\n\r\n")
        body.append(note)
        body.append("\r\n")

        // image field (optional)
        if let imageData {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"shot.png\"\r\n")
            body.append("Content-Type: image/png\r\n\r\n")
            body.append(imageData)
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }
    #endif

    // MARK: - Error Handling

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? decoder.decode(APIError.self, from: data) {
                throw KvanteError.server(apiError.studentMessage.isEmpty
                    ? apiError.message : apiError.studentMessage)
            }
            // Try parsing FastAPI's detail format
            if let detail = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detailDict = detail["detail"] as? [String: Any],
               let studentMsg = detailDict["student_message"] as? String {
                throw KvanteError.server(studentMsg)
            }
            throw KvanteError.server("Noget gik galt (fejlkode \(http.statusCode))")
        }
    }
}

enum KvanteError: LocalizedError {
    case server(String)
    case noConnection

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .noConnection: return "Kan ikke finde Kvante-serveren"
        }
    }
}

// MARK: - Data extension for multipart

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
