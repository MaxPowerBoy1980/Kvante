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

    // MARK: - Submit Work

    func submitWork(sessionId: String, assignmentId: String, imageData: Data) async throws -> SubmissionResponse {
        let url = baseURL.appendingPathComponent("submissions/")
        var request = URLRequest(url: url, timeoutInterval: timeout)
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
