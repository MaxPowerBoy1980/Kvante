# Kvante iOS App — Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Kvante iPad app — a SwiftUI-based camera and feedback display that connects to the Phase 1 FastAPI backend over local WiFi. Students scan textbook pages, pick assignments, photograph handwritten work, and receive method-focused feedback through structured prompt buttons.

**Architecture:** Single-target SwiftUI iPad app using VisionKit for document scanning, URLSession for async networking, NWBrowser for Bonjour discovery, and SwiftData for local caching. Navigation is a NavigationStack with programmatic path management. No text input anywhere in the student UI.

**Tech Stack:** Swift 5.9+, SwiftUI, iPadOS 17+, VisionKit, Network framework (NWBrowser), URLSession async/await, SwiftData

**Spec:** `docs/superpowers/specs/2026-03-19-kvante-design.md`

**Build note:** This code is written on a Mac Mini without Xcode. Build and run from Xcode on a MacBook. After each task, push to GitHub and pull on MacBook to build.

---

## File Structure

```
ios/
├── Kvante.xcodeproj/           # Created in Xcode (Task 1)
└── Kvante/
    ├── KvanteApp.swift          # App entry point, SwiftData container
    ├── ContentView.swift        # Root navigation controller
    ├── Models/
    │   ├── Assignment.swift     # Assignment data model
    │   ├── Submission.swift     # Submission data model
    │   ├── Session.swift        # Session (one scanned page)
    │   ├── ExampleStep.swift    # Worked example step
    │   └── APIResponses.swift   # All Codable response types from backend
    ├── Services/
    │   ├── APIClient.swift      # URLSession wrapper for all backend calls
    │   └── ServerDiscovery.swift # Bonjour/NWBrowser to find Mac Mini
    ├── Views/
    │   ├── HomeView.swift              # "Scan din side" + session list
    │   ├── DocumentScannerView.swift   # UIViewControllerRepresentable for VisionKit
    │   ├── AssignmentPickerView.swift  # Colored assignment cards
    │   ├── AssignmentCardView.swift    # Single assignment card component
    │   ├── WorkingView.swift           # Active assignment with action buttons
    │   ├── ExampleView.swift           # Step-by-step worked example display
    │   ├── FeedbackView.swift          # AI feedback + structured prompt buttons
    │   ├── LoadingView.swift           # Friendly loading animation
    │   └── PromptButton.swift          # Reusable big tappable button component
    └── Resources/
        ├── Assets.xcassets/
        │   ├── AccentColor.colorset/
        │   ├── AppIcon.appiconset/
        │   └── Colors/               # Custom color palette
        └── Localizable.xcstrings      # Danish/English strings
```

**Key design decisions:**
- `APIResponses.swift` holds all Codable structs matching backend JSON — single source of truth for API contract
- `DocumentScannerView` wraps VisionKit's UIKit scanner in a SwiftUI-compatible view
- `PromptButton` is a reusable component for the 60×60pt minimum tap targets
- `LoadingView` replaces spinners with friendly animated text
- Navigation via `NavigationStack` with `NavigationPath` for programmatic control

---

### Task 1: Xcode Project Setup

This task must be done on the MacBook in Xcode. It cannot be done via CLI.

**Files:**
- Create: Xcode project at `ios/Kvante.xcodeproj`

- [ ] **Step 1: Create Xcode project on MacBook**

1. Open Xcode
2. File → New → Project
3. Choose "App" under iOS
4. Settings:
   - Product Name: `Kvante`
   - Team: your dev team
   - Organization Identifier: `com.kvante` (or your own)
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
   - Uncheck "Include Tests" (we'll add later if needed)
5. Save into the `ios/` directory of the cloned repo
6. In project settings:
   - Deployment Target: iPadOS 17.0
   - Supported Destinations: iPad only
   - Device Orientation: All (landscape makes sense for math work)
7. Add camera usage description to Info.plist:
   - `NSCameraUsageDescription`: "Kvante needs camera access to scan textbook pages and your handwritten work"
8. Add local network usage description:
   - `NSLocalNetworkUsageDescription`: "Kvante looks for the Kvante server on your local network"
   - `NSBonjourServices`: `["_kvante._tcp"]`

- [ ] **Step 2: Verify it builds and runs**

Build and run on iPad Simulator. You should see the default SwiftUI "Hello, World!" view.

- [ ] **Step 3: Commit and push**

```bash
git add ios/
git commit -m "feat: create Xcode project for Kvante iPad app"
git push
```

---

### Task 2: Data Models and API Response Types

**Files:**
- Create: `ios/Kvante/Models/Assignment.swift`
- Create: `ios/Kvante/Models/Submission.swift`
- Create: `ios/Kvante/Models/Session.swift`
- Create: `ios/Kvante/Models/ExampleStep.swift`
- Create: `ios/Kvante/Models/APIResponses.swift`

- [ ] **Step 1: Create Assignment.swift**

```swift
import Foundation
import SwiftData

@Model
final class Assignment: Identifiable {
    @Attribute(.unique) var id: String
    var sessionId: String
    var text: String
    var type: String
    var topic: String
    var difficultyEstimate: Int
    var positionOnPage: String
    var status: String  // "not_started", "in_progress", "completed"

    init(id: String, sessionId: String, text: String, type: String,
         topic: String, difficultyEstimate: Int, positionOnPage: String,
         status: String = "not_started") {
        self.id = id
        self.sessionId = sessionId
        self.text = text
        self.type = type
        self.topic = topic
        self.difficultyEstimate = difficultyEstimate
        self.positionOnPage = positionOnPage
        self.status = status
    }
}
```

- [ ] **Step 2: Create Submission.swift**

```swift
import Foundation
import SwiftData

@Model
final class Submission: Identifiable {
    @Attribute(.unique) var id: String
    var sessionId: String
    var assignmentId: String
    var attemptNumber: Int
    var methodologySound: Bool
    var feedbackText: String?
    var createdAt: Date

    init(id: String, sessionId: String, assignmentId: String,
         attemptNumber: Int, methodologySound: Bool,
         feedbackText: String? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.assignmentId = assignmentId
        self.attemptNumber = attemptNumber
        self.methodologySound = methodologySound
        self.feedbackText = feedbackText
        self.createdAt = Date()
    }
}
```

- [ ] **Step 3: Create Session.swift**

```swift
import Foundation
import SwiftData

@Model
final class Session: Identifiable {
    @Attribute(.unique) var id: String
    var detectedLanguage: String
    var pageContext: String
    var suggestedStart: String
    var reasoning: String
    var createdAt: Date
    var status: String  // "active", "completed"

    init(id: String, detectedLanguage: String, pageContext: String,
         suggestedStart: String, reasoning: String,
         status: String = "active") {
        self.id = id
        self.detectedLanguage = detectedLanguage
        self.pageContext = pageContext
        self.suggestedStart = suggestedStart
        self.reasoning = reasoning
        self.createdAt = Date()
        self.status = status
    }
}
```

- [ ] **Step 4: Create ExampleStep.swift**

```swift
import Foundation

struct ExampleStep: Identifiable, Codable {
    var id: Int { step }
    let step: Int
    let instruction: String
    let visual: String
    let explanation: String
}
```

- [ ] **Step 5: Create APIResponses.swift**

```swift
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
    let text: String
    let type: String
    let topic: String
    let difficultyEstimate: Int
    let positionOnPage: String

    enum CodingKeys: String, CodingKey {
        case id, text, type, topic
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
```

- [ ] **Step 6: Commit**

```bash
git add ios/Kvante/Models/
git commit -m "feat: add Swift data models and API response types"
```

---

### Task 3: Server Discovery (Bonjour)

**Files:**
- Create: `ios/Kvante/Services/ServerDiscovery.swift`

- [ ] **Step 1: Create ServerDiscovery.swift**

```swift
import Foundation
import Network

@Observable
final class ServerDiscovery {
    var serverURL: URL?
    var isSearching = false
    var errorMessage: String?

    private var browser: NWBrowser?

    func startSearching() {
        isSearching = true
        errorMessage = nil

        let params = NWParameters()
        params.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: "_kvante._tcp", domain: nil), using: params)

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .failed(let error):
                    self?.errorMessage = "Søgning fejlede: \(error.localizedDescription)"
                    self?.isSearching = false
                case .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                if case .service(let name, let type, let domain, _) = result.endpoint {
                    self.resolveService(name: name, type: type, domain: domain)
                    return
                }
            }
        }

        browser?.start(queue: .main)
    }

    func stopSearching() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func resolveService(name: String, type: String, domain: String) {
        let connection = NWConnection(
            to: .service(name: name, type: type, domain: domain, interface: nil),
            using: .tcp
        )
        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    DispatchQueue.main.async {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr):
                            hostStr = "\(addr)"
                        case .ipv6(let addr):
                            hostStr = "[\(addr)]"
                        case .name(let name, _):
                            hostStr = name
                        @unknown default:
                            hostStr = "localhost"
                        }
                        self?.serverURL = URL(string: "http://\(hostStr):\(port)")
                        self?.isSearching = false
                        connection.cancel()
                    }
                }
            }
        }
        connection.start(queue: .main)
    }

    /// Manual fallback for when Bonjour doesn't work
    func setManualURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            serverURL = url
            errorMessage = nil
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Services/ServerDiscovery.swift
git commit -m "feat: add Bonjour server discovery via NWBrowser"
```

---

### Task 4: API Client

**Files:**
- Create: `ios/Kvante/Services/APIClient.swift`

- [ ] **Step 1: Create APIClient.swift**

```swift
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
        var request = URLRequest(url: url, timeoutInterval: timeout)
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
        var request = URLRequest(url: url, timeoutInterval: timeout)
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
        var request = URLRequest(url: url, timeoutInterval: timeout)
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
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Services/APIClient.swift
git commit -m "feat: add API client with all backend endpoints"
```

---

### Task 5: Reusable UI Components

**Files:**
- Create: `ios/Kvante/Views/PromptButton.swift`
- Create: `ios/Kvante/Views/LoadingView.swift`
- Create: `ios/Kvante/Views/DocumentScannerView.swift`

- [ ] **Step 1: Create PromptButton.swift**

```swift
import SwiftUI

struct PromptButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        PromptButton(title: "Vis mig et eksempel", icon: "lightbulb.fill", color: .orange) {}
        PromptButton(title: "Scan mit svar", icon: "camera.fill", color: .blue) {}
        PromptButton(title: "Næste opgave", icon: "arrow.right.circle.fill", color: .green) {}
    }
    .padding()
}
```

- [ ] **Step 2: Create LoadingView.swift**

```swift
import SwiftUI

struct LoadingView: View {
    let message: String
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            // Friendly animated icon
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)

            Text(message + String(repeating: ".", count: dotCount))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .onReceive(timer) { _ in
                    dotCount = (dotCount + 1) % 4
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    LoadingView(message: "Kvante kigger på din side")
}
```

- [ ] **Step 3: Create DocumentScannerView.swift**

```swift
import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (Data) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Take the first page
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            let image = scan.imageOfPage(at: 0)
            if let data = image.jpegData(compressionQuality: 0.85) {
                onScan(data)
            }
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCancel()
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Views/PromptButton.swift ios/Kvante/Views/LoadingView.swift ios/Kvante/Views/DocumentScannerView.swift
git commit -m "feat: add reusable UI components — buttons, loading, scanner"
```

---

### Task 6: Home View

**Files:**
- Create: `ios/Kvante/Views/HomeView.swift`

- [ ] **Step 1: Create HomeView.swift**

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.createdAt, order: .reverse) private var sessions: [Session]

    let serverDiscovery: ServerDiscovery
    let onScanPage: () -> Void

    @State private var showConnectionInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Kvante")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Din matematik-hjælper")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // Connection status
                Button {
                    showConnectionInfo = true
                } label: {
                    Image(systemName: serverDiscovery.serverURL != nil
                        ? "wifi.circle.fill" : "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(serverDiscovery.serverURL != nil ? .green : .red)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()

            // Big scan button
            Button(action: onScanPage) {
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 72))
                    Text("Scan din side")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(width: 320, height: 240)
                .background(.orange, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(serverDiscovery.serverURL == nil)
            .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)

            if serverDiscovery.serverURL == nil {
                Text(serverDiscovery.isSearching
                    ? "Kvante leder efter din server..."
                    : "Ingen server fundet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                if !serverDiscovery.isSearching {
                    Button("Prøv igen") {
                        serverDiscovery.startSearching()
                    }
                    .font(.callout)
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Recent sessions
            if !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seneste sessioner")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sessions.prefix(5)) { session in
                                SessionCard(session: session)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showConnectionInfo) {
            ConnectionInfoSheet(discovery: serverDiscovery)
        }
    }
}

struct SessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.pageContext.isEmpty ? "Session" : session.pageContext)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            Text(session.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160, height: 80, alignment: .topLeading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ConnectionInfoSheet: View {
    let discovery: ServerDiscovery
    @Environment(\.dismiss) private var dismiss
    @State private var manualIP = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Server status") {
                    if let url = discovery.serverURL {
                        Label("Forbundet: \(url.absoluteString)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Ikke forbundet", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Manuel forbindelse") {
                    TextField("http://192.168.1.60:8000", text: $manualIP)
                        .keyboardType(.URL)
                    Button("Forbind") {
                        discovery.setManualURL(manualIP)
                        dismiss()
                    }
                    .disabled(manualIP.isEmpty)
                }
            }
            .navigationTitle("Forbindelse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Luk") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Views/HomeView.swift
git commit -m "feat: add HomeView with scan button and session list"
```

---

### Task 7: Assignment Picker View

**Files:**
- Create: `ios/Kvante/Views/AssignmentCardView.swift`
- Create: `ios/Kvante/Views/AssignmentPickerView.swift`

- [ ] **Step 1: Create AssignmentCardView.swift**

```swift
import SwiftUI

struct AssignmentCardView: View {
    let assignment: ParsedAssignment
    let isRecommended: Bool
    let onTap: () -> Void

    private let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .teal]

    private var cardColor: Color {
        let hash = abs(assignment.id.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(assignment.id.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    if isRecommended {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    // Difficulty dots
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Circle()
                                .fill(i <= assignment.difficultyEstimate
                                    ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Text(assignment.text)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(3)

                Text(assignment.topic)
                    .font(.caption)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if isRecommended {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.yellow, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Create AssignmentPickerView.swift**

```swift
import SwiftUI

struct AssignmentPickerView: View {
    let pageResponse: PageScanResponse
    let onSelectAssignment: (ParsedAssignment) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Page context
                if !pageResponse.pageContext.isEmpty {
                    Text(pageResponse.pageContext)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Kvante's suggestion
                if !pageResponse.suggestedStart.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.orange)
                        Text("Jeg foreslår du starter med opgave \(pageResponse.suggestedStart)!")
                            .font(.headline)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // Assignment cards grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(pageResponse.assignments) { assignment in
                        AssignmentCardView(
                            assignment: assignment,
                            isRecommended: assignment.id == pageResponse.suggestedStart
                        ) {
                            onSelectAssignment(assignment)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Vælg en opgave")
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Views/AssignmentCardView.swift ios/Kvante/Views/AssignmentPickerView.swift
git commit -m "feat: add assignment picker with colored cards and recommendation"
```

---

### Task 8: Working View and Example View

**Files:**
- Create: `ios/Kvante/Views/WorkingView.swift`
- Create: `ios/Kvante/Views/ExampleView.swift`

- [ ] **Step 1: Create WorkingView.swift**

```swift
import SwiftUI

struct WorkingView: View {
    let assignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient

    @State private var showScanner = false
    @State private var showExample = false
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var exampleResponse: ExampleResponse?
    @State private var submissionResponse: SubmissionResponse?
    @State private var feedbackResponse: FeedbackResponse?
    @State private var errorMessage: String?
    @State private var explainText: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: loadingMessage)
            } else if let feedback = feedbackResponse, let submission = submissionResponse {
                FeedbackView(
                    feedback: feedback,
                    submission: submission,
                    assignment: assignment,
                    sessionId: sessionId,
                    apiClient: apiClient
                )
            } else {
                workingContent
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onScan: { imageData in
                    showScanner = false
                    submitWork(imageData: imageData)
                },
                onCancel: { showScanner = false }
            )
        }
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    ExampleView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
                        }
                }
            }
        }
        .alert("Fejl", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationTitle("Opgave \(assignment.id)")
    }

    private var workingContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Assignment text
                Text(assignment.text)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                // Explain text if requested
                if let explain = explainText {
                    Text(explain)
                        .font(.body)
                        .padding(16)
                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // Action buttons
                VStack(spacing: 12) {
                    PromptButton(
                        title: "Vis mig et eksempel",
                        icon: "lightbulb.fill",
                        color: .orange
                    ) { getExample() }

                    PromptButton(
                        title: "Jeg forstår ikke opgaven",
                        icon: "questionmark.circle.fill",
                        color: .purple
                    ) { explainAssignment() }

                    PromptButton(
                        title: "Scan mit svar",
                        icon: "camera.fill",
                        color: .blue
                    ) { showScanner = true }
                }
                .padding(.horizontal, 20)
            }
            .padding(24)
        }
    }

    private func getExample() {
        isLoading = true
        loadingMessage = "Kvante laver et eksempel"
        Task {
            do {
                let example = try await apiClient.getExample(
                    sessionId: sessionId, assignmentId: assignment.id)
                exampleResponse = example
                showExample = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func explainAssignment() {
        isLoading = true
        loadingMessage = "Kvante tænker"
        Task {
            do {
                let response = try await apiClient.explainTask(
                    sessionId: sessionId, assignmentId: assignment.id)
                explainText = response.feedbackText
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func submitWork(imageData: Data) {
        isLoading = true
        loadingMessage = "Kvante kigger på dit svar"
        Task {
            do {
                let submission = try await apiClient.submitWork(
                    sessionId: sessionId,
                    assignmentId: assignment.id,
                    imageData: imageData
                )
                submissionResponse = submission
                let feedback = try await apiClient.getFeedback(
                    submissionId: submission.submissionId)
                feedbackResponse = feedback
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

- [ ] **Step 2: Create ExampleView.swift**

```swift
import SwiftUI

struct ExampleView: View {
    let example: ExampleResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Example problem header
                Text(example.exampleProblem)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

                // Steps
                ForEach(example.steps) { step in
                    VStack(alignment: .leading, spacing: 12) {
                        // Step number
                        HStack {
                            Text("Trin \(step.step)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.orange, in: Capsule())
                            Text(step.instruction)
                                .font(.headline)
                        }

                        // Visual (monospaced for alignment)
                        Text(step.visual)
                            .font(.system(size: 24, design: .monospaced))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                        // Explanation
                        Text(step.explanation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                // Note
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text(example.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
        .navigationTitle("Eksempel")
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Views/WorkingView.swift ios/Kvante/Views/ExampleView.swift
git commit -m "feat: add WorkingView and ExampleView with step-by-step display"
```

---

### Task 9: Feedback View

**Files:**
- Create: `ios/Kvante/Views/FeedbackView.swift`

- [ ] **Step 1: Create FeedbackView.swift**

```swift
import SwiftUI

struct FeedbackView: View {
    let feedback: FeedbackResponse
    let submission: SubmissionResponse
    let assignment: ParsedAssignment
    let sessionId: String
    let apiClient: APIClient

    @State private var currentFeedback: FeedbackResponse
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showExample = false
    @State private var exampleResponse: ExampleResponse?

    init(feedback: FeedbackResponse, submission: SubmissionResponse,
         assignment: ParsedAssignment, sessionId: String, apiClient: APIClient) {
        self.feedback = feedback
        self.submission = submission
        self.assignment = assignment
        self.sessionId = sessionId
        self.apiClient = apiClient
        self._currentFeedback = State(initialValue: feedback)
    }

    private var toneColor: Color {
        switch currentFeedback.tone {
        case "celebratory": return .green
        case "encouraging": return .orange
        case "supportive": return .blue
        default: return .blue
        }
    }

    private var toneIcon: String {
        switch currentFeedback.tone {
        case "celebratory": return "star.fill"
        case "encouraging": return "hand.thumbsup.fill"
        case "supportive": return "heart.fill"
        default: return "message.fill"
        }
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Kvante tænker")
            } else {
                feedbackContent
            }
        }
        .sheet(isPresented: $showExample) {
            if let example = exampleResponse {
                NavigationStack {
                    ExampleView(example: example)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Luk") { showExample = false }
                            }
                        }
                }
            }
        }
        .alert("Fejl", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var feedbackContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Feedback text
                VStack(spacing: 16) {
                    Image(systemName: toneIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(toneColor)

                    Text(currentFeedback.feedbackText)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(toneColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))

                // Structured prompt buttons
                VStack(spacing: 12) {
                    ForEach(currentFeedback.structuredPrompts) { prompt in
                        promptButton(for: prompt)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func promptButton(for prompt: StructuredPrompt) -> some View {
        let (icon, color) = promptStyle(for: prompt.promptId)
        PromptButton(title: prompt.label, icon: icon, color: color) {
            handlePrompt(prompt.promptId)
        }
    }

    private func promptStyle(for id: String) -> (icon: String, color: Color) {
        switch id {
        case "explain_different": return ("arrow.triangle.2.circlepath", .purple)
        case "another_example": return ("lightbulb.fill", .orange)
        case "show_first_step": return ("1.circle.fill", .blue)
        case "what_did_well": return ("hand.thumbsup.fill", .green)
        case "try_again": return ("arrow.counterclockwise", .teal)
        case "next_assignment": return ("arrow.right.circle.fill", .green)
        default: return ("questionmark.circle", .gray)
        }
    }

    private func handlePrompt(_ actionId: String) {
        // next_assignment is client-side navigation — handled by parent
        if actionId == "next_assignment" {
            // Pop back to assignment picker (handled via NavigationStack)
            return
        }

        if actionId == "another_example" {
            getAnotherExample()
            return
        }

        if actionId == "try_again" {
            // Pop back to WorkingView to scan again
            return
        }

        // All other actions go through followup endpoint
        isLoading = true
        Task {
            do {
                let response = try await apiClient.sendFollowup(
                    submissionId: submission.submissionId,
                    action: actionId
                )
                currentFeedback = response
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func getAnotherExample() {
        isLoading = true
        Task {
            do {
                let example = try await apiClient.getExample(
                    sessionId: sessionId,
                    assignmentId: assignment.id
                )
                exampleResponse = example
                showExample = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Views/FeedbackView.swift
git commit -m "feat: add FeedbackView with structured prompt buttons"
```

---

### Task 10: App Entry Point and Navigation

**Files:**
- Create: `ios/Kvante/KvanteApp.swift`
- Create: `ios/Kvante/ContentView.swift`

- [ ] **Step 1: Create KvanteApp.swift**

```swift
import SwiftUI
import SwiftData

@main
struct KvanteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Session.self, Assignment.self, Submission.self])
    }
}
```

- [ ] **Step 2: Create ContentView.swift**

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var serverDiscovery = ServerDiscovery()
    @State private var showScanner = false
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var errorMessage: String?

    // Navigation state
    @State private var pageResponse: PageScanResponse?
    @State private var selectedAssignment: ParsedAssignment?

    private var apiClient: APIClient? {
        guard let url = serverDiscovery.serverURL else { return nil }
        return APIClient(baseURL: url)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView(message: loadingMessage)
                } else if let assignment = selectedAssignment,
                          let page = pageResponse,
                          let client = apiClient {
                    WorkingView(
                        assignment: assignment,
                        sessionId: page.sessionId,
                        apiClient: client
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                selectedAssignment = nil
                            } label: {
                                Label("Tilbage", systemImage: "chevron.left")
                            }
                        }
                    }
                } else if let page = pageResponse {
                    AssignmentPickerView(pageResponse: page) { assignment in
                        selectedAssignment = assignment
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                pageResponse = nil
                                selectedAssignment = nil
                            } label: {
                                Label("Hjem", systemImage: "house.fill")
                            }
                        }
                    }
                } else {
                    HomeView(
                        serverDiscovery: serverDiscovery,
                        onScanPage: { showScanner = true }
                    )
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(
                onScan: { imageData in
                    showScanner = false
                    scanPage(imageData: imageData)
                },
                onCancel: { showScanner = false }
            )
        }
        .alert("Fejl", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            serverDiscovery.startSearching()
        }
    }

    private func scanPage(imageData: Data) {
        guard let client = apiClient else {
            errorMessage = "Ingen forbindelse til serveren"
            return
        }

        isLoading = true
        loadingMessage = "Kvante kigger på din side"

        Task {
            do {
                let response = try await client.scanPage(imageData: imageData)
                pageResponse = response

                // Cache session locally
                let session = Session(
                    id: response.sessionId,
                    detectedLanguage: response.detectedLanguage,
                    pageContext: response.pageContext,
                    suggestedStart: response.suggestedStart,
                    reasoning: response.reasoning
                )
                modelContext.insert(session)
                try? modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, Assignment.self, Submission.self],
                        inMemory: true)
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/KvanteApp.swift ios/Kvante/ContentView.swift
git commit -m "feat: add app entry point and navigation flow"
```

---

### Task 11: Final Assembly and Build Verification

This task is done on the MacBook in Xcode.

- [ ] **Step 1: Pull latest code**

```bash
cd Kvante && git pull
```

- [ ] **Step 2: Open project in Xcode**

Open `ios/Kvante.xcodeproj`. Add all Swift source files to the Xcode project if they weren't automatically included.

Verify the file structure in Xcode matches:
- `KvanteApp.swift`
- `ContentView.swift`
- `Models/` (5 files)
- `Services/` (2 files)
- `Views/` (9 files)

- [ ] **Step 3: Fix any build errors**

Common issues to expect:
- Missing `import` statements
- Swift 6 concurrency warnings (add `@MainActor` or `@Sendable` as needed)
- SwiftData model issues (may need `@Attribute` adjustments)
- VisionKit availability checks (wrap in `#if canImport(VisionKit)` if needed)

- [ ] **Step 4: Run on iPad Simulator or device**

1. Select an iPad simulator (iPad Pro 11-inch recommended)
2. Build and Run (Cmd+R)
3. Verify: Home screen shows with "Scan din side" button
4. Verify: Connection indicator shows red (no backend in simulator)

- [ ] **Step 5: Test with real backend**

1. Start backend on Mac Mini: `cd backend && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000`
2. Run app on physical iPad connected to same WiFi
3. Verify: Bonjour discovers the server (green indicator)
4. Test full flow: scan page → pick assignment → get example → scan work → feedback

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve build errors for Xcode"
git push
```
