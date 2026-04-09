# Pakke 5 — Bog-arkivet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a read-only "Matematikbogen" — a swipeable book view showing the student's completed work organized by week, with Kvante as co-author.

**Architecture:** TabView(.page) for book-like swipe navigation. NotebookViewModel loads session history, groups by ISO week, lazy-loads details per week. Backend extends two existing endpoints with answer fields and configurable limit. No new tables or AI logic.

**Tech Stack:** SwiftUI (iOS 26.2), FastAPI + SQLAlchemy (backend), pytest (backend tests)

**Spec:** `docs/superpowers/specs/2026-04-09-pakke-5-notebook-design.md`

---

## File Map

### Backend (modify existing)
| File | Change |
|------|--------|
| `backend/app/models/schemas.py` | Add `correct_answer`, `student_answer` to `ArkAssignment` |
| `backend/app/routers/practice.py` | Add answer fields to session-detail query; add `limit` query param to history endpoint |
| `backend/tests/test_practice_notebook.py` | **New** — tests for the two backend changes |

### iOS (new files)
| File | Responsibility |
|------|---------------|
| `ios/Kvante/Kvante/ViewModels/NotebookViewModel.swift` | Load sessions, group by week, lazy-load details, cache |
| `ios/Kvante/Kvante/Views/Notebook/NotebookView.swift` | TabView(.page) container + back button |
| `ios/Kvante/Kvante/Views/Notebook/NotebookCoverView.swift` | Cover page with Kvante + title + stats |
| `ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift` | Week page with facit cards |
| `ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift` | Detail sheet with scan image + feedback |

### iOS (modify existing)
| File | Change |
|------|--------|
| `ios/Kvante/Kvante/Models/APIResponses.swift` | Add `correctAnswer`, `studentAnswer` to `ArkAssignmentResponse`; add `limit` param support |
| `ios/Kvante/Kvante/Services/APIClient.swift` | Add `limit` parameter to `getSessionHistory()` |
| `ios/Kvante/Kvante/ContentView.swift` | Add `.notebook` case to `SessionRoute`, add `.navigationDestination` |
| `ios/Kvante/Kvante/Views/NewHomeView.swift` | Add notebook card below practice card |

---

## Task 1: Backend — Answer fields on ArkAssignment

Add `correct_answer` and `student_answer` to the `ArkAssignment` schema and populate them in the session-detail endpoint.

**Files:**
- Modify: `backend/app/models/schemas.py:178-197`
- Modify: `backend/app/routers/practice.py:290-320`
- Create: `backend/tests/test_practice_notebook.py`

- [ ] **Step 1: Write failing test for answer fields**

Create `backend/tests/test_practice_notebook.py`:

```python
"""Tests for notebook-related backend changes (Pakke 5)."""
from app.models.db import Assignment, Session, Submission, Student
import json


def _seed_session_with_submission(db):
    """Create a session with one completed assignment and one submission."""
    student = db.query(Student).filter(Student.id == "default").first()
    session = Session(
        id="notebook-test-session",
        student_id=student.id,
        name="Uge 14 — Blandet",
        mode="weekly",
        topic="mixed",
        status="completed",
    )
    db.add(session)
    db.flush()

    assignment = Assignment(
        id="notebook-test-a1",
        session_id=session.id,
        local_id="1",
        text="347 + 285",
        type="addition",
        topic="addition",
        difficulty_estimate=2,
        position=0,
        status="completed",
        correct_answer="632",
    )
    db.add(assignment)
    db.flush()

    submission = Submission(
        id="notebook-test-sub1",
        session_id=session.id,
        assignment_id=assignment.id,
        work_image_path="/fake/path.jpg",
        analysis=json.dumps({
            "student_answer": "632",
            "correct_answer": "632",
            "methodology_sound": True,
            "errors": [],
            "correct_elements": [],
        }),
        feedback_text="Flot opsætning — du huskede mente fra ener til tier.",
        attempt_number=1,
    )
    db.add(submission)
    db.commit()
    return session.id


def test_session_detail_includes_answer_fields(client, test_db):
    """ArkAssignment should include correct_answer and student_answer."""
    session_id = _seed_session_with_submission(test_db)
    resp = client.get(f"/sessions/{session_id}")
    assert resp.status_code == 200
    data = resp.json()
    a = data["assignments"][0]
    assert a["correct_answer"] == "632"
    assert a["student_answer"] == "632"


def test_session_detail_answer_fields_null_without_submission(client, test_db):
    """Assignments without submissions should have null answer fields."""
    student = test_db.query(Student).filter(Student.id == "default").first()
    session = Session(
        id="notebook-no-sub",
        student_id=student.id,
        name="Empty",
        mode="weekly",
        status="active",
    )
    test_db.add(session)
    test_db.flush()

    assignment = Assignment(
        id="notebook-no-sub-a1",
        session_id=session.id,
        local_id="1",
        text="50 + 30",
        type="addition",
        topic="addition",
        difficulty_estimate=1,
        position=0,
        status="not_started",
        correct_answer="80",
    )
    test_db.add(assignment)
    test_db.commit()

    resp = client.get(f"/sessions/{session.id}")
    assert resp.status_code == 200
    a = resp.json()["assignments"][0]
    assert a["correct_answer"] == "80"
    assert a["student_answer"] is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_practice_notebook.py -v`
Expected: FAIL — `correct_answer` and `student_answer` not in response.

- [ ] **Step 3: Add fields to ArkAssignment schema**

In `backend/app/models/schemas.py`, add two fields to `ArkAssignment` class after `teacher_comment`:

```python
    teacher_comment: str | None = None
    correct_answer: str | None = None
    student_answer: str | None = None
```

- [ ] **Step 4: Populate fields in session-detail endpoint**

In `backend/app/routers/practice.py`, in the `get_session` function, update the loop that builds `ark_assignments`. Find the block that creates `ArkAssignment(...)` (around line 305) and add:

```python
        # Extract student_answer from latest submission's analysis
        student_answer = None
        if subs:
            latest_sub = subs[-1]
            if latest_sub.analysis:
                analysis = latest_sub.analysis
                if isinstance(analysis, str):
                    import json as _json
                    analysis = _json.loads(analysis)
                student_answer = analysis.get("student_answer")

        ark_assignments.append(
            ArkAssignment(
                id=a.id,
                local_id=a.local_id,
                text=a.text,
                type=a.type,
                topic=a.topic,
                difficulty_estimate=a.difficulty_estimate,
                position=a.position,
                ark_status=_compute_ark_status(a, subs),
                latest_scan_id=latest_scan_by_assignment.get(a.id),
                latest_ai_feedback_summary=latest_feedback,
                teacher_comment=None,
                correct_answer=a.correct_answer,
                student_answer=student_answer,
            )
        )
```

Note: `a.correct_answer` comes directly from the Assignment model. `student_answer` is extracted from the latest Submission's analysis JSON. The `analysis` column may be stored as a JSON string or dict depending on SQLAlchemy setup — handle both.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_practice_notebook.py -v`
Expected: Both tests PASS.

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `cd backend && python -m pytest -v`
Expected: All existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add backend/app/models/schemas.py backend/app/routers/practice.py backend/tests/test_practice_notebook.py
git commit -m "feat(backend): add correct_answer and student_answer to ArkAssignment"
```

---

## Task 2: Backend — Configurable limit on session history

Make the 20-session limit configurable via query parameter so the notebook can request all sessions.

**Files:**
- Modify: `backend/app/routers/practice.py:335-365`
- Modify: `backend/tests/test_practice_notebook.py`

- [ ] **Step 1: Write failing test for limit parameter**

Append to `backend/tests/test_practice_notebook.py`:

```python
def _seed_many_sessions(db, count=25):
    """Create multiple sessions for limit testing."""
    student = db.query(Student).filter(Student.id == "default").first()
    for i in range(count):
        session = Session(
            id=f"limit-test-{i}",
            student_id=student.id,
            name=f"Session {i}",
            mode="weekly",
            status="completed",
        )
        db.add(session)
    db.commit()


def test_session_history_default_limit_20(client, test_db):
    """Default limit should return at most 20 sessions."""
    _seed_many_sessions(test_db, 25)
    resp = client.get("/students/default/sessions")
    assert resp.status_code == 200
    assert len(resp.json()["sessions"]) == 20


def test_session_history_limit_zero_returns_all(client, test_db):
    """limit=0 should return all sessions."""
    _seed_many_sessions(test_db, 25)
    resp = client.get("/students/default/sessions?limit=0")
    assert resp.status_code == 200
    assert len(resp.json()["sessions"]) == 25


def test_session_history_custom_limit(client, test_db):
    """Custom limit should be respected."""
    _seed_many_sessions(test_db, 25)
    resp = client.get("/students/default/sessions?limit=5")
    assert resp.status_code == 200
    assert len(resp.json()["sessions"]) == 5
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_practice_notebook.py::test_session_history_limit_zero_returns_all -v`
Expected: FAIL — limit=0 still returns 20.

- [ ] **Step 3: Add limit query parameter to endpoint**

In `backend/app/routers/practice.py`, modify the `get_session_history` function signature and query:

```python
@router.get("/students/{student_id}/sessions", response_model=SessionHistoryResponse)
def get_session_history(
    student_id: str,
    limit: int = 20,
    db: DBSession = Depends(get_db),
):
    """Return session history for a student, most recent first.

    Args:
        limit: Max sessions to return. 0 = all sessions (used by notebook).
    """
    query = (
        db.query(Session)
        .filter(Session.student_id == student_id)
        .order_by(Session.created_at.desc())
    )
    if limit > 0:
        query = query.limit(limit)
    sessions = query.all()
```

The rest of the function stays the same.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_practice_notebook.py -v`
Expected: All 5 tests PASS.

- [ ] **Step 5: Run full test suite**

Run: `cd backend && python -m pytest -v`
Expected: All tests pass (existing tests use default limit=20, unchanged).

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/practice.py backend/tests/test_practice_notebook.py
git commit -m "feat(backend): configurable limit on session history endpoint"
```

---

## Task 3: iOS — Update API models and client

Add the new fields to iOS data models and the limit parameter to the API client.

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift:331-354`
- Modify: `ios/Kvante/Kvante/Services/APIClient.swift:329-336`

- [ ] **Step 1: Add answer fields to ArkAssignmentResponse**

In `ios/Kvante/Kvante/Models/APIResponses.swift`, add two fields to the `ArkAssignmentResponse` struct after `teacherComment`:

```swift
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
    }
}
```

- [ ] **Step 2: Add limit parameter to getSessionHistory()**

In `ios/Kvante/Kvante/Services/APIClient.swift`, modify `getSessionHistory()`:

```swift
func getSessionHistory(studentId: String, limit: Int = 20) async throws -> SessionHistoryResponse {
    var components = URLComponents(url: baseURL.appendingPathComponent("students/\(studentId)/sessions"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 15
    let (data, response) = try await session.data(for: request)
    try checkResponse(response, data: data)
    return try decoder.decode(SessionHistoryResponse.self, from: data)
}
```

- [ ] **Step 3: Build to verify compilation**

Build the iOS project in Xcode or via command line to verify no type errors. Existing callers of `getSessionHistory(studentId:)` use the default `limit: 20` so they remain unchanged.

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Models/APIResponses.swift ios/Kvante/Kvante/Services/APIClient.swift
git commit -m "feat(ios): add answer fields to ArkAssignment, limit param to session history"
```

---

## Task 4: iOS — NotebookViewModel

The data layer: load all sessions, group by ISO week, lazy-load session details with caching.

**Files:**
- Create: `ios/Kvante/Kvante/ViewModels/NotebookViewModel.swift`

- [ ] **Step 1: Create NotebookViewModel**

Create `ios/Kvante/Kvante/ViewModels/NotebookViewModel.swift`:

```swift
import SwiftUI

/// Data model for one week in the notebook.
struct NotebookWeek: Identifiable {
    /// Unique ID combining year and week number.
    var id: String { "\(year)-W\(weekNumber)" }
    let weekNumber: Int
    let year: Int
    let dateRange: String
    let weeklySessionIds: [String]
    let practiceSessionIds: [String]
    var solvedCount: Int
    var totalCount: Int
}

/// A loaded assignment ready for display in a facit card.
struct NotebookAssignment: Identifiable {
    let id: String
    let text: String
    let arkStatus: String
    let correctAnswer: String?
    let studentAnswer: String?
    let feedbackSummary: String?
    let scanId: String?
    let position: Int
    let weekNumber: Int
}

/// Manages notebook data: loads sessions, groups by week, caches detail responses.
@Observable
final class NotebookViewModel {
    var weeks: [NotebookWeek] = []
    var totalSolved: Int = 0
    var totalCorrect: Int = 0
    var totalIncorrect: Int = 0
    var totalWeeks: Int { weeks.count }
    var isLoading = false

    /// Cache of loaded session details keyed by session ID.
    private var detailCache: [String: SessionDetailResponse] = [:]

    private let apiClient: APIClient
    private let studentId: String

    init(apiClient: APIClient, studentId: String) {
        self.apiClient = apiClient
        self.studentId = studentId
    }

    // MARK: - Load session list and group by week

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        guard let history = try? await apiClient.getSessionHistory(studentId: studentId, limit: 0) else {
            return
        }

        let calendar = Calendar(identifier: .iso8601)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        // Group sessions by ISO week
        var weekMap: [String: (weekNumber: Int, year: Int, weekly: [SessionSummary], practice: [SessionSummary])] = [:]

        for session in history.sessions {
            guard let date = isoFormatter.date(from: session.createdAt) else { continue }
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let year = comps.yearForWeekOfYear, let week = comps.weekOfYear else { continue }
            let key = "\(year)-W\(week)"

            if weekMap[key] == nil {
                weekMap[key] = (weekNumber: week, year: year, weekly: [], practice: [])
            }

            if session.mode == "practice" {
                weekMap[key]!.practice.append(session)
            } else {
                weekMap[key]!.weekly.append(session)
            }
        }

        // Build sorted weeks (newest first)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "da_DK")
        dateFormatter.dateFormat = "d. MMM"

        var allWeeks: [NotebookWeek] = []
        for (_, value) in weekMap {
            let allSessions = value.weekly + value.practice
            let dateRange = Self.computeDateRange(
                year: value.year,
                week: value.weekNumber,
                calendar: calendar,
                formatter: dateFormatter
            )
            let solved = allSessions.reduce(0) { $0 + $1.completedCount }
            let total = allSessions.reduce(0) { $0 + $1.assignmentCount }

            allWeeks.append(NotebookWeek(
                weekNumber: value.weekNumber,
                year: value.year,
                dateRange: dateRange,
                weeklySessionIds: value.weekly.map(\.sessionId),
                practiceSessionIds: value.practice.map(\.sessionId),
                solvedCount: solved,
                totalCount: total
            ))
        }

        allWeeks.sort { a, b in
            if a.year != b.year { return a.year > b.year }
            return a.weekNumber > b.weekNumber
        }

        weeks = allWeeks
        totalSolved = history.sessions.reduce(0) { $0 + $1.completedCount }
        let totalAssignments = history.sessions.reduce(0) { $0 + $1.assignmentCount }
        totalIncorrect = totalSolved  // Will be refined when details load — for now approximate
        totalCorrect = totalSolved
        // Correct/incorrect breakdown requires detail data; cover shows totalSolved for now
    }

    // MARK: - Lazy-load session details for a week

    /// Returns assignments for a week, loading details on demand.
    func assignments(for week: NotebookWeek) async -> (weekly: [NotebookAssignment], practice: [NotebookAssignment]) {
        let weeklyAssignments = await loadAssignments(sessionIds: week.weeklySessionIds, weekNumber: week.weekNumber)
        let practiceAssignments = await loadAssignments(sessionIds: week.practiceSessionIds, weekNumber: week.weekNumber)
        return (weekly: weeklyAssignments, practice: practiceAssignments)
    }

    private func loadAssignments(sessionIds: [String], weekNumber: Int) async -> [NotebookAssignment] {
        var result: [NotebookAssignment] = []
        for sessionId in sessionIds {
            let detail = await loadDetail(sessionId: sessionId)
            guard let detail else { continue }
            for a in detail.assignments {
                result.append(NotebookAssignment(
                    id: a.id,
                    text: a.text,
                    arkStatus: a.arkStatus,
                    correctAnswer: a.correctAnswer,
                    studentAnswer: a.studentAnswer,
                    feedbackSummary: a.latestAiFeedbackSummary,
                    scanId: a.latestScanId,
                    position: a.position,
                    weekNumber: weekNumber
                ))
            }
        }
        return result.sorted { $0.position < $1.position }
    }

    private func loadDetail(sessionId: String) async -> SessionDetailResponse? {
        if let cached = detailCache[sessionId] {
            return cached
        }
        guard let detail = try? await apiClient.getSession(sessionId: sessionId) else {
            return nil
        }
        detailCache[sessionId] = detail
        return detail
    }

    // MARK: - Helpers

    private static func computeDateRange(year: Int, week: Int, calendar: Calendar, formatter: DateFormatter) -> String {
        var comps = DateComponents()
        comps.yearForWeekOfYear = year
        comps.weekOfYear = week
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return "" }
        guard let friday = calendar.date(byAdding: .day, value: 4, to: monday) else { return "" }
        return "\(formatter.string(from: monday)) – \(formatter.string(from: friday))"
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Build the iOS project. The ViewModel doesn't depend on any views yet, only on `APIClient`, `SessionSummary`, `SessionDetailResponse`, and `ArkAssignmentResponse` — all from Task 3.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/ViewModels/NotebookViewModel.swift
git commit -m "feat(ios): add NotebookViewModel with week grouping and lazy detail loading"
```

---

## Task 5: iOS — AssignmentDetailSheet

The detail sheet shown when tapping a facit card. Built first so it can be referenced by the week view.

**Files:**
- Create: `ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift`

- [ ] **Step 1: Create AssignmentDetailSheet**

Create directory and file `ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift`:

```swift
import SwiftUI

/// Detail sheet for a single assignment in the notebook.
/// Shows assignment text, student/correct answers, scan image, and Kvante feedback.
struct AssignmentDetailSheet: View {
    let assignment: NotebookAssignment
    let apiClient: APIClient

    @State private var scanImage: UIImage?
    @State private var isLoadingScan = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Label
                Text("Opgave \(assignment.position + 1) · Uge \(assignment.weekNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(KvanteTheme.Colors.textMuted)

                // Assignment text
                Text(assignment.text)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                // Result section
                resultSection

                // Scan image
                scanSection

                // Kvante feedback
                if let feedback = assignment.feedbackSummary, !feedback.isEmpty {
                    feedbackSection(feedback)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(KvanteTheme.Colors.cream)
        .task {
            await loadScanImage()
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        switch assignment.arkStatus {
        case "done":
            if let studentAnswer = assignment.studentAnswer,
               let correctAnswer = assignment.correctAnswer {
                if studentAnswer == correctAnswer {
                    // Correct
                    HStack(spacing: 4) {
                        Text("Dit svar:")
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        Text("\(studentAnswer) ✓")
                            .foregroundStyle(KvanteTheme.Colors.success)
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 20))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Opgave: \(assignment.text). Dit svar: \(studentAnswer). Rigtigt.")
                } else {
                    // Incorrect
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("Dit svar")
                                .font(.system(size: 11))
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                            Text(studentAnswer)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(KvanteTheme.Colors.primary)
                        }
                        VStack(spacing: 4) {
                            Text("Rigtigt svar")
                                .font(.system(size: 11))
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                            Text("\(correctAnswer) ✓")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(KvanteTheme.Colors.success)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Opgave: \(assignment.text). Dit svar: \(studentAnswer). Forkert. Rigtigt svar: \(correctAnswer).")
                }
            } else if let studentAnswer = assignment.studentAnswer {
                // Has student answer but no correct answer in DB
                HStack(spacing: 4) {
                    Text("Dit svar:")
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    Text(studentAnswer)
                        .fontWeight(.bold)
                }
                .font(.system(size: 20))
            }
        default:
            Text("Ikke besvaret")
                .font(.system(size: 16))
                .foregroundStyle(KvanteTheme.Colors.textMuted)
                .accessibilityLabel("Opgave: \(assignment.text). Ikke besvaret.")
        }
    }

    // MARK: - Scan image

    @ViewBuilder
    private var scanSection: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
            )
            .overlay {
                if let image = scanImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Dit håndskrevne arbejde")
                } else if isLoadingScan {
                    ProgressView()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundStyle(KvanteTheme.Colors.textMuted.opacity(0.5))
                        Text("Ingen scanning")
                            .font(.system(size: 12))
                            .foregroundStyle(KvanteTheme.Colors.textMuted)
                    }
                }
            }
            .frame(minHeight: 200)
    }

    // MARK: - Feedback

    private func feedbackSection(_ feedback: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Mini Kvante
            KvanteFace(expression: .happy)
                .frame(width: 20, height: 20)

            Text(feedback)
                .font(.system(size: 13))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineSpacing(4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KvanteTheme.Colors.teal.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kvante siger: \(feedback)")
    }

    // MARK: - Load scan

    private func loadScanImage() async {
        guard let scanId = assignment.scanId else { return }
        isLoadingScan = true
        defer { isLoadingScan = false }
        // Use larger maxPixelSize for detail sheet (full-width display)
        scanImage = try? await ScanImageCache.shared.image(for: scanId, apiClient: apiClient, maxPixelSize: 800)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

The view depends on `NotebookAssignment` (Task 4), `KvanteFace`, `KvanteTheme`, `ScanImageCache`, and `APIClient` — all should exist.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Notebook/AssignmentDetailSheet.swift
git commit -m "feat(ios): add AssignmentDetailSheet for notebook detail view"
```

---

## Task 6: iOS — NotebookWeekView

The week page showing facit cards with header, weekly assignments, and optional practice section.

**Files:**
- Create: `ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift`

- [ ] **Step 1: Create NotebookWeekView**

Create `ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift`:

```swift
import SwiftUI

/// One week page in the notebook. Shows facit cards for all assignments.
struct NotebookWeekView: View {
    let week: NotebookWeek
    let viewModel: NotebookViewModel
    let apiClient: APIClient
    let pageLabel: String  // e.g. "Uge 14 af 22" or empty for dots

    @State private var weeklyAssignments: [NotebookAssignment] = []
    @State private var practiceAssignments: [NotebookAssignment] = []
    @State private var isLoading = true
    @State private var selectedAssignment: NotebookAssignment?

    var body: some View {
        ZStack {
            // Paper background with book spine
            paperBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    weekHeader
                        .padding(.horizontal, 24)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        // Weekly assignments
                        ForEach(weeklyAssignments) { assignment in
                            FacitCard(assignment: assignment)
                                .onTapGesture { selectedAssignment = assignment }
                                .padding(.horizontal, 24)
                        }

                        // Practice section
                        if !practiceAssignments.isEmpty {
                            Text("Ekstra øvelser")
                                .font(.system(size: 11, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(KvanteTheme.Colors.textMuted)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            ForEach(practiceAssignments) { assignment in
                                FacitCard(assignment: assignment)
                                    .onTapGesture { selectedAssignment = assignment }
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Uge \(week.weekNumber). \(week.solvedCount) af \(week.totalCount) opgaver løst.")
        .task {
            let result = await viewModel.assignments(for: week)
            weeklyAssignments = result.weekly
            practiceAssignments = result.practice
            isLoading = false
        }
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentDetailSheet(assignment: assignment, apiClient: apiClient)
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Uge \(week.weekNumber)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)
                Spacer()
                Text(week.dateRange)
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
            }
            Text("\(week.solvedCount) af \(week.totalCount) opgaver løst")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KvanteTheme.Colors.teal)
        }
    }

    // MARK: - Paper background

    private var paperBackground: some View {
        ZStack {
            KvanteTheme.Colors.cream
            Canvas { context, size in
                var rng = SeededRandomNumberGenerator(seed: 42)
                let dotCount = Int(size.width * size.height / 200)
                for _ in 0..<dotCount {
                    let x = CGFloat.random(in: 0..<size.width, using: &rng)
                    let y = CGFloat.random(in: 0..<size.height, using: &rng)
                    let gray = CGFloat.random(in: 0.3...0.7, using: &rng)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(Color(white: gray))
                    )
                }
            }
            .opacity(0.04)
            .blendMode(.multiply)
            .allowsHitTesting(false)

            // Book spine on left edge
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(hex: "e8ddd0"), KvanteTheme.Colors.cream],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Facit Card

/// A compact card showing assignment result: text, answer badge, feedback line.
private struct FacitCard: View {
    let assignment: NotebookAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(assignment.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                Spacer()

                answerBadge
            }

            if let feedback = assignment.feedbackSummary, !feedback.isEmpty {
                Text(feedback)
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var answerBadge: some View {
        switch assignment.arkStatus {
        case "done":
            if let studentAnswer = assignment.studentAnswer,
               let correctAnswer = assignment.correctAnswer,
               studentAnswer != correctAnswer {
                // Incorrect
                Text("✗ \(studentAnswer)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(KvanteTheme.Colors.primary, in: Capsule())
            } else if let answer = assignment.studentAnswer ?? assignment.correctAnswer {
                // Correct
                Text("✓ \(answer)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(KvanteTheme.Colors.success, in: Capsule())
            }
        default:
            Text("—")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(KvanteTheme.Colors.textMuted, in: Capsule())
        }
    }

    private var accessibilityText: String {
        switch assignment.arkStatus {
        case "done":
            if let studentAnswer = assignment.studentAnswer,
               let correctAnswer = assignment.correctAnswer,
               studentAnswer != correctAnswer {
                return "Opgave: \(assignment.text). Dit svar: \(studentAnswer). Forkert. Rigtigt svar: \(correctAnswer)."
            } else if let answer = assignment.studentAnswer {
                return "Opgave: \(assignment.text). Dit svar: \(answer). Rigtigt."
            }
            return "Opgave: \(assignment.text)."
        default:
            return "Opgave: \(assignment.text). Ikke besvaret."
        }
    }
}

// MARK: - SeededRNG (reused from AssignmentSheetView pattern)

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Color hex initializer

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
```

Note: `SeededRandomNumberGenerator` is duplicated from `AssignmentSheetView.swift` because it's a `private` struct there. If it has been made internal/public, use the existing one instead. Similarly, `Color(hex:)` — check if it already exists in `KvanteTheme` and use that instead of this private extension.

- [ ] **Step 2: Build to verify compilation**

Verify the view compiles. It depends on `NotebookWeek`, `NotebookAssignment`, `NotebookViewModel` (Task 4), `AssignmentDetailSheet` (Task 5), `KvanteFace`, `KvanteTheme`, `ScanImageCache`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Notebook/NotebookWeekView.swift
git commit -m "feat(ios): add NotebookWeekView with facit cards and paper texture"
```

---

## Task 7: iOS — NotebookCoverView

The book cover with Kvante, title, student name, and stats.

**Files:**
- Create: `ios/Kvante/Kvante/Views/Notebook/NotebookCoverView.swift`

- [ ] **Step 1: Create NotebookCoverView**

Create `ios/Kvante/Kvante/Views/Notebook/NotebookCoverView.swift`:

```swift
import SwiftUI

/// The book cover — first page in the notebook TabView.
struct NotebookCoverView: View {
    let studentName: String
    let totalSolved: Int
    let totalWeeks: Int

    var body: some View {
        ZStack {
            // Paper background
            KvanteTheme.Colors.cream.ignoresSafeArea()

            // Book spine on left edge
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(red: 0.91, green: 0.87, blue: 0.82), KvanteTheme.Colors.cream],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Kvante figure with pencil
                ZStack {
                    KvanteFace(expression: totalSolved > 0 ? .happy : .neutral)
                        .frame(width: 90, height: 90)

                    // Pencil next to Kvante
                    pencilShape
                        .offset(x: 50, y: 20)
                }
                .padding(.bottom, 20)

                // Title
                Text("Matematikbogen")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                // Subtitle — co-authors
                Text("\(studentName) & Kvante")
                    .font(.system(size: 15))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.6))
                    .padding(.top, 4)

                // Decorative dots (from Kvante's chest panel)
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i == 2 ? KvanteTheme.Colors.primary : Color(red: 0.16, green: 0.35, blue: 0.54))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 24)

                // Stats badge
                Text("\(totalSolved) opgaver løst")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(KvanteTheme.Colors.teal, in: Capsule())
                    .padding(.top, 24)

                Spacer()

                // Swipe hint
                if totalWeeks > 0 {
                    Text("swipe for at bladre ›")
                        .font(.system(size: 12))
                        .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.3))
                        .padding(.bottom, 24)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Matematikbogen. \(studentName) og Kvante. \(totalSolved) opgaver løst")
    }

    // MARK: - Pencil shape

    /// Simple pencil drawn with SwiftUI shapes — orange body, brown tip, beige eraser.
    private var pencilShape: some View {
        VStack(spacing: 0) {
            // Eraser
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.96, green: 0.90, blue: 0.82))
                .frame(width: 6, height: 6)
            // Body
            Rectangle()
                .fill(KvanteTheme.Colors.primary)
                .frame(width: 6, height: 22)
            // Tip
            Triangle()
                .fill(Color(red: 0.24, green: 0.17, blue: 0.12))
                .frame(width: 6, height: 6)
        }
        .rotationEffect(.degrees(-25))
    }
}

/// Simple triangle shape for pencil tip.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
```

Note: The pencil is drawn with simple SwiftUI shapes (rectangles + triangle) rather than an SVG asset — this is actually simpler than importing/managing an SVG for something this small, and it already uses the theme colors directly. If you prefer an SVG, replace `pencilShape` with an `Image("pencil-icon")` from the asset catalog.

- [ ] **Step 2: Build to verify compilation**

Verify it compiles. Depends on `KvanteFace`, `KvanteTheme`.

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Notebook/NotebookCoverView.swift
git commit -m "feat(ios): add NotebookCoverView with Kvante, title, and stats"
```

---

## Task 8: iOS — NotebookView (TabView container)

The main container wrapping cover + week pages in a swipeable TabView.

**Files:**
- Create: `ios/Kvante/Kvante/Views/Notebook/NotebookView.swift`

- [ ] **Step 1: Create NotebookView**

Create `ios/Kvante/Kvante/Views/Notebook/NotebookView.swift`:

```swift
import SwiftUI

/// The main notebook view — a page-style TabView with cover + week pages.
struct NotebookView: View {
    let viewModel: NotebookViewModel
    let apiClient: APIClient
    let studentName: String
    let onBack: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Hjem")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                TabView(selection: $currentPage) {
                    // Page 0: Cover
                    NotebookCoverView(
                        studentName: studentName,
                        totalSolved: viewModel.totalSolved,
                        totalWeeks: viewModel.totalWeeks
                    )
                    .tag(0)

                    // Pages 1..N: Week pages (newest first)
                    ForEach(Array(viewModel.weeks.enumerated()), id: \.element.id) { index, week in
                        NotebookWeekView(
                            week: week,
                            viewModel: viewModel,
                            apiClient: apiClient,
                            pageLabel: pageLabel(index: index + 1)
                        )
                        .tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator
                pageIndicator
                    .padding(.bottom, 8)
            }
        }
        .background(KvanteTheme.Colors.cream.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadSessions()
        }
    }

    // MARK: - Page indicator

    @ViewBuilder
    private var pageIndicator: some View {
        let totalPages = viewModel.weeks.count + 1  // cover + weeks

        if totalPages <= 10 {
            // Dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? KvanteTheme.Colors.primary : KvanteTheme.Colors.ink.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityLabel("Side \(currentPage + 1) af \(totalPages)")
        } else {
            // Text label for many pages
            if currentPage == 0 {
                Text("Omslag")
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.4))
            } else {
                let week = viewModel.weeks[currentPage - 1]
                Text("Uge \(week.weekNumber) af \(viewModel.weeks.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.4))
            }
        }
    }

    private func pageLabel(index: Int) -> String {
        let totalPages = viewModel.weeks.count + 1
        return totalPages > 10 ? "Uge \(viewModel.weeks[index - 1].weekNumber) af \(viewModel.weeks.count)" : ""
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Depends on `NotebookCoverView` (Task 7), `NotebookWeekView` (Task 6), `NotebookViewModel` (Task 4).

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Notebook/NotebookView.swift
git commit -m "feat(ios): add NotebookView TabView container with page indicator"
```

---

## Task 9: iOS — Navigation routing and Home card

Wire the notebook into the app: add route, add navigation destination, add home card.

**Files:**
- Modify: `ios/Kvante/Kvante/ContentView.swift:4-9` (SessionRoute enum)
- Modify: `ios/Kvante/Kvante/ContentView.swift:85-118` (navigationDestination)
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift:47-49` (add notebook card)

- [ ] **Step 1: Add .notebook route to SessionRoute**

In `ios/Kvante/Kvante/ContentView.swift`, add the new case to the enum:

```swift
enum SessionRoute: Hashable {
    case ark
    case chat
    case notebook
}
```

- [ ] **Step 2: Add navigation destination for .notebook**

In the same file, in the `.navigationDestination(for: SessionRoute.self)` switch block, add the `.notebook` case:

```swift
    case .notebook:
        if let client = apiClient, let p = profile {
            let studentId = p.backendStudentId ?? "default"
            let vm = NotebookViewModel(apiClient: client, studentId: studentId)
            NotebookView(
                viewModel: vm,
                apiClient: client,
                studentName: p.name,
                onBack: { sessionPath.removeAll() }
            )
        }
```

- [ ] **Step 3: Add notebook card to NewHomeView**

First, add the `onNotebook` callback to `NewHomeView`. Find the existing callback properties (like `onPractice`, `onWeekly`) and add:

```swift
    var onNotebook: () -> Void
```

Then add the notebook card below the practice card in the view body. Find where `practiceCard` is placed (around the line `practiceCard.padding(.horizontal, 24)`) and add immediately after:

```swift
                // Notebook
                notebookCard
                    .padding(.horizontal, 24)
```

Add the `notebookCard` computed property to `NewHomeView` (following the pattern of `practiceCard`):

```swift
    private var notebookCard: some View {
        Button(action: onNotebook) {
            HStack(spacing: 14) {
                // Mini book cover
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(KvanteTheme.Colors.cream)
                        .frame(width: 42, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1)
                        )
                    // Mini book spine
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color(red: 0.91, green: 0.87, blue: 0.82), KvanteTheme.Colors.cream],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 5)
                        Spacer()
                    }
                    .frame(width: 42, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Mini Kvante
                    KvanteFace(expression: .happy)
                        .frame(width: 18, height: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Din matematikbog")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KvanteTheme.Colors.ink)
                    Text("\(profile.name) & Kvante — \(notebookSolvedCount) opgaver løst")
                        .font(.system(size: 12))
                        .foregroundStyle(KvanteTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                            .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(serverDiscovery.serverURL == nil)
        .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
        .accessibilityLabel("Din matematikbog. \(notebookSolvedCount) opgaver løst")
    }
```

Add the solved count state. In `NewHomeView`, add a property:

```swift
    @State private var notebookSolvedCount: Int = 0
```

Populate it when session history loads. Find the existing `loadSessionHistory()` call or `.task` block and add after session history is loaded:

```swift
    notebookSolvedCount = sessionHistory.reduce(0) { $0 + $1.completedCount }
```

- [ ] **Step 4: Wire onNotebook in ContentView**

In `ContentView.swift`, find where `NewHomeView` is instantiated and add the `onNotebook` callback:

```swift
    onNotebook: {
        sessionPath = [.notebook]
    }
```

- [ ] **Step 5: Build and run in simulator**

Build and run. Verify:
1. Home shows the notebook card below practice card
2. Tapping it navigates to the notebook cover
3. Swiping shows week pages (if test data exists)
4. Tapping a facit card opens the detail sheet
5. Back button returns to home

- [ ] **Step 6: Commit**

```bash
git add ios/Kvante/Kvante/ContentView.swift ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(ios): wire notebook into navigation and add home card"
```

---

## Task 10: Deploy and end-to-end verification

Deploy backend changes to Mac Mini and test the full flow.

**Files:** No code changes — deployment and testing only.

- [ ] **Step 1: Commit any outstanding changes**

Ensure all changes are committed on the current branch.

- [ ] **Step 2: Deploy backend to Mac Mini**

```bash
./scripts/deploy.sh
```

The script pushes, SSH-pulls on Mac Mini, and health-checks. uvicorn `--reload` picks up the Python changes automatically.

- [ ] **Step 3: Verify backend changes via curl**

Test the limit parameter:
```bash
curl -s http://192.168.1.60:8000/students/default/sessions?limit=0 | python3 -m json.tool | head -20
```

Test answer fields in session detail (use a real session ID from the response above):
```bash
curl -s http://192.168.1.60:8000/sessions/<session-id> | python3 -m json.tool | grep -A2 "correct_answer"
```

- [ ] **Step 4: Run iOS app on simulator or device**

Open `ios/Kvante/Kvante.xcodeproj` in Xcode, build and run on iPad simulator. Walk through the full flow:
1. Home → tap "Din matematikbog"
2. See cover with Kvante and student name
3. Swipe to see week pages
4. Verify facit cards show correct/incorrect badges
5. Tap a card to see detail sheet with scan image and feedback
6. Navigate back to home

- [ ] **Step 5: Commit any fixes discovered during testing**

If any issues found, fix and commit separately.
