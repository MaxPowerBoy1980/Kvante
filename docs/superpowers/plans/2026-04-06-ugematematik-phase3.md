# Phase 3: Ugematematik — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the "Ugematematik" button on the home screen — backend generates a mixed weekly assignment set by grade, iOS displays it as a continuous chat session, and completed sets appear in a history list on the home screen.

**Architecture:** New backend endpoint creates a mixed-topic session with 5-8 problems appropriate for the student's grade. iOS adds an `onWeekly` callback to the home screen, which creates/resumes the weekly set. Completed sessions are listed below the cards on the home screen as tappable history items that open a dashboard view.

**Tech Stack:** FastAPI + SQLAlchemy (backend), SwiftUI (iOS)

**Spec:** `docs/superpowers/specs/2026-04-06-ui-overhaul-weekly-assignments-design.md` — Phase 3 section

---

### File Structure

**Backend — Create:**
- `backend/tests/test_weekly.py` — Tests for weekly assignment endpoint

**Backend — Modify:**
- `backend/app/routers/practice.py` — Add weekly assignment endpoint + session history
- `backend/app/models/schemas.py` — Add response schemas

**iOS — Create:**
- `ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift` — Review completed assignment set

**iOS — Modify:**
- `ios/Kvante/Kvante/Views/NewHomeView.swift` — Enable ugematematik, add session history list
- `ios/Kvante/Kvante/ContentView.swift` — Add weekly flow + dashboard navigation
- `ios/Kvante/Kvante/Services/APIClient.swift` — Add weekly + history API calls
- `ios/Kvante/Kvante/Models/APIResponses.swift` — Add response types

---

### Task 1: Backend — Weekly Assignment Endpoint

**Files:**
- Modify: `backend/app/routers/practice.py`
- Modify: `backend/app/models/schemas.py`
- Create: `backend/tests/test_weekly.py`

- [ ] **Step 1: Add schemas**

Append to `backend/app/models/schemas.py`:

```python
# --- Weekly Assignments ---

class WeeklyRequest(BaseModel):
    student_id: str
    grade_level: int = 4
    count: int = 6


class SessionSummary(BaseModel):
    session_id: str
    name: str
    mode: str
    topic: str | None
    status: str
    assignment_count: int
    completed_count: int
    created_at: str
    completed_at: str | None


class SessionHistoryResponse(BaseModel):
    sessions: list[SessionSummary]
```

- [ ] **Step 2: Add weekly endpoint to practice router**

Add to `backend/app/routers/practice.py`, after the existing `create_practice_session` function:

```python
@router.post("/sessions/weekly")
def create_weekly_session(body: WeeklyRequest, db: DBSession = Depends(get_db)):
    """Create a mixed-topic weekly assignment set appropriate for the student's grade."""
    # Pick problems across multiple topics for this grade level
    problems = (
        db.query(MathProblem)
        .filter(MathProblem.grade_level <= body.grade_level)
        .all()
    )

    if not problems:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_problems",
                "message": f"No problems found for grade_level={body.grade_level}",
                "student_message": "Der er ingen opgaver til din klasse endnu.",
            },
        )

    # Group by topic, pick 1-2 from each to get a good mix
    from collections import defaultdict
    by_topic: dict[str, list] = defaultdict(list)
    for p in problems:
        by_topic[p.topic].append(p)

    selected = []
    topics = list(by_topic.keys())
    random.shuffle(topics)

    # Round-robin across topics until we have enough
    idx = 0
    while len(selected) < body.count and topics:
        topic = topics[idx % len(topics)]
        available = [p for p in by_topic[topic] if p not in selected]
        if available:
            selected.append(random.choice(available))
        else:
            topics.remove(topic)
            if not topics:
                break
            idx = idx % len(topics) if topics else 0
            continue
        idx += 1

    if not selected:
        raise HTTPException(status_code=404, detail="Could not select problems")

    import datetime
    week_num = datetime.date.today().isocalendar()[1]

    session = Session(
        student_id=body.student_id,
        mode="weekly",
        name=f"Ugematematik — uge {week_num}",
        detected_language="da",
    )
    db.add(session)
    db.flush()

    assignments = []
    for i, problem in enumerate(selected):
        assignment = Assignment(
            session_id=session.id,
            problem_id=problem.id,
            local_id=str(i + 1),
            text=problem.text,
            type=problem.type,
            topic=problem.topic,
            difficulty_estimate=problem.difficulty,
            correct_answer=problem.correct_answer,
            position=i,
        )
        db.add(assignment)
        assignments.append(assignment)

    db.commit()

    return {
        "session_id": session.id,
        "name": session.name,
        "assignments": [
            {
                "id": a.id,
                "problem_id": a.problem_id,
                "local_id": a.local_id,
                "text": a.text,
                "type": a.type,
                "topic": a.topic,
                "difficulty_estimate": a.difficulty_estimate,
                "position": a.position,
            }
            for a in assignments
        ],
    }
```

Add the imports at the top of the file:

```python
from app.models.schemas import WeeklyRequest, SessionSummary, SessionHistoryResponse
```

- [ ] **Step 3: Add session history endpoint**

Add to `backend/app/routers/practice.py`:

```python
@router.get("/students/{student_id}/sessions", response_model=SessionHistoryResponse)
def get_session_history(student_id: str, db: DBSession = Depends(get_db)):
    """Get all sessions for a student, newest first."""
    sessions = (
        db.query(Session)
        .filter(Session.student_id == student_id)
        .order_by(Session.created_at.desc())
        .limit(20)
        .all()
    )

    summaries = []
    for s in sessions:
        assignment_count = db.query(Assignment).filter(Assignment.session_id == s.id).count()
        completed_count = (
            db.query(Assignment)
            .filter(Assignment.session_id == s.id, Assignment.status == "complete")
            .count()
        )
        summaries.append(SessionSummary(
            session_id=s.id,
            name=s.name or f"{s.topic or 'Øvelse'}",
            mode=s.mode,
            topic=s.topic,
            status="completed" if s.completed_at else s.status,
            assignment_count=assignment_count,
            completed_count=completed_count,
            created_at=s.created_at.isoformat(),
            completed_at=s.completed_at.isoformat() if s.completed_at else None,
        ))

    return SessionHistoryResponse(sessions=summaries)
```

- [ ] **Step 4: Add session completion endpoint**

Add to `backend/app/routers/practice.py`:

```python
@router.post("/sessions/{session_id}/complete")
def complete_session(session_id: str, db: DBSession = Depends(get_db)):
    """Mark a session as completed."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    from datetime import datetime, timezone
    session.completed_at = datetime.now(timezone.utc)
    session.status = "completed"
    db.commit()

    return {"status": "completed", "session_id": session_id}
```

- [ ] **Step 5: Write tests**

Create `backend/tests/test_weekly.py`:

```python
from app.models.db import MathProblem


def _seed_problems(db, count=10):
    """Seed some problems for testing."""
    topics = ["addition", "subtraktion", "multiplikation"]
    for i in range(count):
        p = MathProblem(
            topic=topics[i % len(topics)],
            subtopic="simpel",
            difficulty=1,
            grade_level=4,
            text=f"Regn ud: {10 + i} + {20 + i}",
            type="calculation",
            correct_answer=str(30 + 2 * i),
        )
        db.add(p)
    db.commit()


def test_create_weekly_session(client, test_db):
    _seed_problems(test_db)
    response = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 5,
    })
    assert response.status_code == 200
    data = response.json()
    assert "session_id" in data
    assert "name" in data
    assert "Ugematematik" in data["name"]
    assert len(data["assignments"]) == 5
    # Verify mixed topics
    topics = {a["topic"] for a in data["assignments"]}
    assert len(topics) > 1


def test_create_weekly_no_problems(client, test_db):
    response = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
    })
    assert response.status_code == 404


def test_session_history(client, test_db):
    _seed_problems(test_db)
    # Create a session first
    client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 3,
    })
    response = client.get("/students/default/sessions")
    assert response.status_code == 200
    data = response.json()
    assert len(data["sessions"]) >= 1
    assert data["sessions"][0]["assignment_count"] == 3
    assert data["sessions"][0]["completed_count"] == 0


def test_complete_session(client, test_db):
    _seed_problems(test_db)
    create = client.post("/sessions/weekly", json={
        "student_id": "default",
        "grade_level": 4,
        "count": 3,
    })
    session_id = create.json()["session_id"]
    response = client.post(f"/sessions/{session_id}/complete")
    assert response.status_code == 200
    assert response.json()["status"] == "completed"


def test_complete_session_not_found(client, test_db):
    response = client.post("/sessions/nonexistent/complete")
    assert response.status_code == 404
```

- [ ] **Step 6: Run tests**

Run: `cd backend && python -m pytest tests/test_weekly.py -v`

Expected: All 5 tests pass.

- [ ] **Step 7: Commit**

```bash
git add backend/app/routers/practice.py backend/app/models/schemas.py backend/tests/test_weekly.py
git commit -m "feat: weekly assignment endpoint, session history, and completion"
```

---

### Task 2: iOS — API Client + Response Types

**Files:**
- Modify: `ios/Kvante/Kvante/Models/APIResponses.swift`
- Modify: `ios/Kvante/Kvante/Services/APIClient.swift`

- [ ] **Step 1: Add response types**

Append to `ios/Kvante/Kvante/Models/APIResponses.swift`:

```swift
// MARK: - Weekly / Session History

struct WeeklySessionResponse: Codable {
    let sessionId: String
    let name: String
    let assignments: [PracticeAssignment]
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

    var id: String { sessionId }

    var isCompleted: Bool { status == "completed" }

    var displayDate: String {
        // Parse ISO date and format as "6. apr."
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
```

- [ ] **Step 2: Add position to PracticeAssignment**

Find `PracticeAssignment` in the same file and add the missing `position` field:

```swift
struct PracticeAssignment: Codable, Identifiable {
    let id: String
    let problemId: String?
    let localId: String
    let text: String
    let type: String
    let topic: String
    let difficultyEstimate: Int
    let position: Int?  // Add this — nil for backwards compatibility
```

- [ ] **Step 3: Add API methods**

Append to `ios/Kvante/Kvante/Services/APIClient.swift`:

```swift
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
    let (responseData, _) = try await URLSession.shared.data(for: request)
    return try decoder.decode(WeeklySessionResponse.self, from: responseData)
}

func getSessionHistory(studentId: String) async throws -> SessionHistoryResponse {
    let url = baseURL.appendingPathComponent("students/\(studentId)/sessions")
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    let (data, _) = try await URLSession.shared.data(for: request)
    return try decoder.decode(SessionHistoryResponse.self, from: data)
}

func completeSession(sessionId: String) async throws {
    var request = URLRequest(url: baseURL.appendingPathComponent("sessions/\(sessionId)/complete"))
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    let _ = try await URLSession.shared.data(for: request)
}
```

- [ ] **Step 4: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Models/APIResponses.swift ios/Kvante/Kvante/Services/APIClient.swift
git commit -m "feat: add weekly session and session history API calls"
```

---

### Task 3: iOS — Enable Ugematematik + Session History on Home Screen

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift`
- Modify: `ios/Kvante/Kvante/ContentView.swift`

- [ ] **Step 1: Add onWeekly callback to NewHomeView**

In `ios/Kvante/Kvante/Views/NewHomeView.swift`, change the struct properties:

```swift
struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void
    let onWeekly: () -> Void
    let sessionHistory: [SessionSummary]
    let onTapSession: (SessionSummary) -> Void
```

Enable the ugematematik card — change `action: {}` and `disabled: true` to:

```swift
    homeCard(
        iconName: "book.closed",
        iconColor: KvanteTheme.Colors.primary,
        title: "Ugematematik",
        subtitle: "Dine opgaver venter",
        buttonLabel: "Start opgaver",
        buttonStyle: KvanteTheme.TactileButtonStyle.primary,
        action: onWeekly,
        disabled: serverDiscovery.serverURL == nil
    )
```

- [ ] **Step 2: Add session history list below cards**

Add after the server status section, before the last `Spacer()`:

```swift
// Session history
if !sessionHistory.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Seneste")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(KvanteTheme.Colors.ink)
            .padding(.horizontal, 24)
            .padding(.top, 16)

        ForEach(sessionHistory.prefix(5)) { session in
            Button { onTapSession(session) } label: {
                HStack(spacing: 12) {
                    // Status icon
                    Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(session.isCompleted ? KvanteTheme.Colors.success : KvanteTheme.Colors.textMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(KvanteTheme.Colors.ink)
                        Text("\(session.completedCount)/\(session.assignmentCount) opgaver · \(session.displayDate)")
                            .font(.caption)
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 3: Update ContentView with weekly flow and history**

In `ios/Kvante/Kvante/ContentView.swift`, add state:

```swift
@State private var showWeekly = false
@State private var sessionHistory: [SessionSummary] = []
```

Update the `NewHomeView` instantiation to pass the new callbacks:

```swift
NewHomeView(
    profile: p,
    serverDiscovery: serverDiscovery,
    onPractice: { showPractice = true },
    onWeekly: { startWeeklySession() },
    sessionHistory: sessionHistory,
    onTapSession: { session in
        // For now, just show a completed session as a practice session
        // TODO: In future, open SessionDashboardView
    }
)
.task { await loadSessionHistory() }
```

Add the weekly session method:

```swift
private func startWeeklySession() {
    guard let client = apiClient, let p = profile else { return }

    isLoading = true
    loadingMessage = "Kvante laver ugematematik..."

    Task {
        do {
            let studentId = p.backendStudentId ?? "default"
            let weekly = try await client.createWeeklySession(
                studentId: studentId,
                gradeLevel: p.gradeLevel
            )
            practiceSession = PracticeSessionResponse(
                sessionId: weekly.sessionId,
                assignments: weekly.assignments
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private func loadSessionHistory() async {
    guard let client = apiClient, let p = profile else { return }
    let studentId = p.backendStudentId ?? "default"
    if let history = try? await client.getSessionHistory(studentId: studentId) {
        sessionHistory = history.sessions
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift ios/Kvante/Kvante/ContentView.swift
git commit -m "feat: enable ugematematik button, add session history to home screen"
```

---

### Task 4: iOS — Session Dashboard View

**Files:**
- Create: `ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift`

- [ ] **Step 1: Create dashboard view**

Create `ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift`:

```swift
import SwiftUI

struct SessionDashboardView: View {
    let session: SessionSummary
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Hjem")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(KvanteTheme.Colors.inkSubtle)
                    .frame(height: 1),
                alignment: .bottom
            )

            ScrollView {
                VStack(spacing: 20) {
                    // Session header
                    VStack(spacing: 8) {
                        Text(session.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(KvanteTheme.Colors.ink)

                        Text("\(session.completedCount) af \(session.assignmentCount) opgaver løst")
                            .font(.subheadline)
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(KvanteTheme.Colors.ink.opacity(0.1))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(KvanteTheme.Colors.success)
                                    .frame(
                                        width: geo.size.width * CGFloat(session.completedCount) / CGFloat(max(session.assignmentCount, 1)),
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 40)

                        if session.isCompleted {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(KvanteTheme.Colors.success)
                                Text("Gennemført")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(KvanteTheme.Colors.success)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 20)

                    // Date
                    Text(session.displayDate)
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(KvanteTheme.Colors.cream)
        .toolbar(.hidden, for: .navigationBar)
    }
}
```

- [ ] **Step 2: Wire dashboard into ContentView**

In `ContentView.swift`, add state:

```swift
@State private var selectedSession: SessionSummary?
```

Add a new navigation branch after the practice session view, before the topic picker:

```swift
} else if let session = selectedSession {
    SessionDashboardView(
        session: session,
        onBack: { selectedSession = nil }
    )
    .toolbar(.hidden, for: .navigationBar)
```

Update the `onTapSession` closure in `NewHomeView`:

```swift
onTapSession: { session in
    selectedSession = session
}
```

- [ ] **Step 3: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Dashboard/SessionDashboardView.swift ios/Kvante/Kvante/ContentView.swift
git commit -m "feat: session dashboard view for reviewing completed assignment sets"
```

---

## Summary

| Task | Description | Backend/iOS | Files |
|------|-------------|-------------|-------|
| 1 | Weekly endpoint + session history + completion + tests | Backend | `practice.py`, `schemas.py`, test |
| 2 | API client + response types | iOS | `APIClient.swift`, `APIResponses.swift` |
| 3 | Enable ugematematik + history on home screen | iOS | `NewHomeView.swift`, `ContentView.swift` |
| 4 | Session dashboard view | iOS | New `SessionDashboardView.swift`, `ContentView.swift` |

**Dependencies:** Task 1 (backend) is independent. Task 2 depends on Task 1's API contract. Tasks 3-4 depend on Task 2.
