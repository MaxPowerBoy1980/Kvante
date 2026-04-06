# Phase 2: Continuous Chat & Assignment Sets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-assignment chat with one continuous conversation per assignment set, add progress pill with drawer, tiered celebrations, and chat message persistence.

**Architecture:** Extend backend Session model to serve as AssignmentSet (add name, completed_at). Add ChatMessage model for persistence. Refactor iOS ChatViewModel to manage all assignments in a single conversation. Add progress UI and celebration system. Chat messages saved to backend so sessions can be resumed.

**Tech Stack:** FastAPI + SQLAlchemy (backend), SwiftUI + SwiftData (iOS)

**Spec:** `docs/superpowers/specs/2026-04-06-ui-overhaul-weekly-assignments-design.md` — Phase 2 section

---

### File Structure

**Backend — Create:**
- `backend/tests/test_chat_persistence.py` — Tests for new chat endpoints

**Backend — Modify:**
- `backend/app/models/db.py` — Add ChatMessage model, extend Session + Assignment
- `backend/app/models/schemas.py` — Add ChatMessageSchema, SessionDetailResponse
- `backend/app/routers/chat.py` — Add message persistence endpoints
- `backend/app/routers/practice.py` — Return assignment positions
- `backend/app/main.py` — Register updated routes

**iOS — Create:**
- `ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift` — Progress pill + drawer overlay
- `ios/Kvante/Kvante/Views/Chat/CelebrationView.swift` — Tiered celebration cards

**iOS — Modify:**
- `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift` — Major refactor: manage all assignments in one chat
- `ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift` — Simplify: single ChatView, no per-assignment switching
- `ios/Kvante/Kvante/Views/Chat/ChatView.swift` — Add progress pill, integrate celebrations
- `ios/Kvante/Kvante/Views/Chat/ChatInputBar.swift` — Expand + menu with all actions
- `ios/Kvante/Kvante/Models/APIResponses.swift` — Add chat message persistence types
- `ios/Kvante/Kvante/Services/APIClient.swift` — Add chat persistence API calls
- `ios/Kvante/Kvante/Models/ChatMessage.swift` — Add Codable conformance for persistence

---

### Task 1: Backend — Add ChatMessage Model & Extend Session/Assignment

**Files:**
- Modify: `backend/app/models/db.py`

- [ ] **Step 1: Add ChatMessage model and extend existing models**

Add to `backend/app/models/db.py`, after the Submission class:

```python
class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    session_id: Mapped[str] = mapped_column(String, ForeignKey("sessions.id"), nullable=False, index=True)
    assignment_id: Mapped[str | None] = mapped_column(String, ForeignKey("assignments.id"), nullable=True)
    sender: Mapped[str] = mapped_column(String, nullable=False)  # "kvante" | "student"
    content_type: Mapped[str] = mapped_column(String, nullable=False)  # "text", "assignment_intro", "feedback", "example_step", "scanned_image", "tip", "answer_result", "celebration"
    content: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
```

Add fields to Session class:

```python
# Add after existing fields in Session:
    name: Mapped[str] = mapped_column(String, default="")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
```

Add fields to Assignment class:

```python
# Add after existing fields in Assignment:
    position: Mapped[int] = mapped_column(Integer, default=0)
    feedback_summary: Mapped[str | None] = mapped_column(String, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
```

- [ ] **Step 2: Run existing tests to verify no regression**

Run: `cd backend && python -m pytest tests/test_models.py -v`

Expected: All existing model tests pass.

- [ ] **Step 3: Commit**

```bash
git add backend/app/models/db.py
git commit -m "feat: add ChatMessage model, extend Session and Assignment for Phase 2"
```

---

### Task 2: Backend — Chat Persistence Endpoints

**Files:**
- Modify: `backend/app/models/schemas.py`
- Modify: `backend/app/routers/chat.py`
- Create: `backend/tests/test_chat_persistence.py`

- [ ] **Step 1: Add schemas**

Add to `backend/app/models/schemas.py`:

```python
# --- Chat Persistence ---

class ChatMessageCreate(BaseModel):
    sender: str
    content_type: str
    content: dict
    assignment_id: str | None = None


class ChatMessageOut(BaseModel):
    id: str
    session_id: str
    assignment_id: str | None
    sender: str
    content_type: str
    content: dict
    created_at: str


class SaveMessagesRequest(BaseModel):
    session_id: str
    messages: list[ChatMessageCreate]


class SaveMessagesResponse(BaseModel):
    saved_count: int


class LoadMessagesResponse(BaseModel):
    session_id: str
    messages: list[ChatMessageOut]
```

- [ ] **Step 2: Add persistence endpoints to chat router**

Replace `backend/app/routers/chat.py` with:

```python
"""Chat endpoints — free-text chat and message persistence."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session as DBSession

from app.config import settings
from app.database import get_db
from app.models.db import Assignment, ChatMessage, Session
from app.models.schemas import (
    ChatMessageCreate,
    ChatMessageOut,
    LoadMessagesResponse,
    SaveMessagesRequest,
    SaveMessagesResponse,
)
from app.services.ai_client import get_ai_client

import logging

logger = logging.getLogger(__name__)

router = APIRouter()

_system_prompt = None


def get_system_prompt():
    global _system_prompt
    if _system_prompt is None:
        _system_prompt = (settings.prompts_dir / "chat.txt").read_text()
    return _system_prompt


class ChatRequest(BaseModel):
    session_id: str
    assignment_id: str
    message: str
    language: str = "da"


class ChatResponse(BaseModel):
    reply: str


@router.post("/chat/", response_model=ChatResponse)
async def chat(request: ChatRequest, db: DBSession = Depends(get_db)):
    """Handle free-text chat from the student."""
    session = db.query(Session).filter(Session.id == request.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    assignment = (
        db.query(Assignment)
        .filter(Assignment.id == request.assignment_id, Assignment.session_id == request.session_id)
        .first()
    )

    assignment_context = ""
    if assignment:
        assignment_context = f"\nElevens aktuelle opgave: {assignment.text}"
        if assignment.status == "complete":
            assignment_context += " (eleven har løst den korrekt)"

    logger.info("Chat message from student: '%s'", request.message)

    system = get_system_prompt() + assignment_context
    client = get_ai_client()
    reply = client.send_text(system, request.message)

    logger.info("Chat reply: '%s'", reply[:100])
    return ChatResponse(reply=reply)


@router.post("/chat/messages/save", response_model=SaveMessagesResponse)
def save_messages(request: SaveMessagesRequest, db: DBSession = Depends(get_db)):
    """Save chat messages for a session (batch)."""
    session = db.query(Session).filter(Session.id == request.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    for msg in request.messages:
        chat_msg = ChatMessage(
            session_id=request.session_id,
            assignment_id=msg.assignment_id,
            sender=msg.sender,
            content_type=msg.content_type,
            content=msg.content,
        )
        db.add(chat_msg)

    db.commit()
    return SaveMessagesResponse(saved_count=len(request.messages))


@router.get("/chat/messages/{session_id}", response_model=LoadMessagesResponse)
def load_messages(session_id: str, db: DBSession = Depends(get_db)):
    """Load all chat messages for a session, ordered by creation time."""
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at)
        .all()
    )

    return LoadMessagesResponse(
        session_id=session_id,
        messages=[
            ChatMessageOut(
                id=m.id,
                session_id=m.session_id,
                assignment_id=m.assignment_id,
                sender=m.sender,
                content_type=m.content_type,
                content=m.content,
                created_at=m.created_at.isoformat(),
            )
            for m in messages
        ],
    )
```

- [ ] **Step 3: Write tests**

Create `backend/tests/test_chat_persistence.py`:

```python
from app.models.db import Assignment, MathProblem, Session


def _create_session_with_assignments(db, count=3):
    """Helper to create a session with N assignments."""
    session = Session(student_id="default", mode="practice", topic="addition")
    db.add(session)
    db.flush()

    assignments = []
    for i in range(count):
        a = Assignment(
            session_id=session.id,
            local_id=str(i + 1),
            text=f"Regn ud: {10 + i} + {20 + i}",
            type="calculation",
            topic="addition",
            position=i,
        )
        db.add(a)
        assignments.append(a)
    db.commit()
    return session, assignments


def test_save_messages(client, test_db):
    session, assignments = _create_session_with_assignments(test_db)

    response = client.post("/chat/messages/save", json={
        "session_id": session.id,
        "messages": [
            {
                "sender": "kvante",
                "content_type": "assignment_intro",
                "content": {"text": "Regn ud: 10 + 20", "local_id": "1"},
                "assignment_id": assignments[0].id,
            },
            {
                "sender": "student",
                "content_type": "text",
                "content": {"text": "30"},
                "assignment_id": assignments[0].id,
            },
        ],
    })

    assert response.status_code == 200
    data = response.json()
    assert data["saved_count"] == 2


def test_load_messages(client, test_db):
    session, assignments = _create_session_with_assignments(test_db)

    # Save some messages first
    client.post("/chat/messages/save", json={
        "session_id": session.id,
        "messages": [
            {
                "sender": "kvante",
                "content_type": "text",
                "content": {"text": "Hej!"},
            },
            {
                "sender": "student",
                "content_type": "text",
                "content": {"text": "Hej Kvante!"},
            },
        ],
    })

    # Load them back
    response = client.get(f"/chat/messages/{session.id}")
    assert response.status_code == 200
    data = response.json()
    assert data["session_id"] == session.id
    assert len(data["messages"]) == 2
    assert data["messages"][0]["sender"] == "kvante"
    assert data["messages"][0]["content"]["text"] == "Hej!"
    assert data["messages"][1]["sender"] == "student"


def test_load_messages_empty_session(client, test_db):
    session, _ = _create_session_with_assignments(test_db)
    response = client.get(f"/chat/messages/{session.id}")
    assert response.status_code == 200
    assert len(response.json()["messages"]) == 0


def test_load_messages_invalid_session(client, test_db):
    response = client.get("/chat/messages/nonexistent")
    assert response.status_code == 404


def test_save_messages_invalid_session(client, test_db):
    response = client.post("/chat/messages/save", json={
        "session_id": "nonexistent",
        "messages": [{"sender": "kvante", "content_type": "text", "content": {"text": "hi"}}],
    })
    assert response.status_code == 404
```

- [ ] **Step 4: Run tests**

Run: `cd backend && python -m pytest tests/test_chat_persistence.py -v`

Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/models/schemas.py backend/app/routers/chat.py backend/tests/test_chat_persistence.py
git commit -m "feat: chat message persistence — save and load endpoints with tests"
```

---

### Task 3: Backend — Add Position to Practice Session Response

**Files:**
- Modify: `backend/app/routers/practice.py`

- [ ] **Step 1: Return position in practice response**

In `backend/app/routers/practice.py`, update the assignment creation loop to set `position`:

```python
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
```

And add `position` to the response dict:

```python
    return {
        "session_id": session.id,
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

- [ ] **Step 2: Run existing practice tests**

Run: `cd backend && python -m pytest tests/ -v -k practice`

Expected: Existing tests still pass.

- [ ] **Step 3: Commit**

```bash
git add backend/app/routers/practice.py
git commit -m "feat: include assignment position in practice session response"
```

---

### Task 4: iOS — Refactor ChatViewModel for Continuous Chat

This is the core architectural change. The ChatViewModel currently manages one assignment. It needs to manage ALL assignments in a session as one continuous conversation.

**Files:**
- Modify: `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

- [ ] **Step 1: Change initializer to accept all assignments**

Replace the single-assignment init with a multi-assignment one. Read the current file first, then change:

Old init pattern:
```swift
init(assignment: ParsedAssignment, sessionId: String, apiClient: APIClient)
```

New init:
```swift
init(assignments: [ParsedAssignment], sessionId: String, apiClient: APIClient)
```

Add state properties:
```swift
var allAssignments: [ParsedAssignment]
var currentAssignmentIndex: Int = 0
var completedAssignmentIds: Set<String> = []
var attemptCounts: [String: Int] = [:]  // assignmentId -> attempt count

var currentAssignment: ParsedAssignment {
    allAssignments[currentAssignmentIndex]
}

var totalAssignments: Int { allAssignments.count }
var completedCount: Int { completedAssignmentIds.count }
var isSetComplete: Bool { completedAssignmentIds.count == allAssignments.count }
var onSetComplete: (() -> Void)?
```

- [ ] **Step 2: Update sendWelcome() to introduce first assignment**

```swift
func sendWelcome() {
    let assignment = currentAssignment
    let intro = ChatMessage(
        sender: .kvante,
        content: .assignmentIntro(assignment)
    )
    messages.append(intro)

    let welcome = ChatMessage(
        sender: .kvante,
        content: .text("Her er din første opgave. Brug + knappen for at scanne dit svar eller bede om hjælp.")
    )
    messages.append(welcome)
}
```

- [ ] **Step 3: Add advanceToNextAssignment()**

When an assignment is completed, this method introduces the next one in the same chat:

```swift
func advanceToNextAssignment() {
    completedAssignmentIds.insert(currentAssignment.id)

    if isSetComplete {
        // Final celebration
        let celebration = ChatMessage(
            sender: .kvante,
            content: .text("Du klarede alle \(totalAssignments) opgaver!")
        )
        messages.append(celebration)
        onSetComplete?()
        return
    }

    // Move to next
    currentAssignmentIndex += 1

    // Introduce next assignment in chat
    let intro = ChatMessage(
        sender: .kvante,
        content: .assignmentIntro(currentAssignment)
    )
    messages.append(intro)
}
```

- [ ] **Step 4: Update answer handling to call advanceToNextAssignment**

Where the existing code calls `onNextAssignment?()` after a correct answer, change it to call `advanceToNextAssignment()` instead. The "next_assignment" chip action should also call `advanceToNextAssignment()`.

Update `handleChip()`:
```swift
case "next_assignment":
    advanceToNextAssignment()
```

- [ ] **Step 5: Track attempts per assignment**

In the submission handling code, increment attempt count:
```swift
let assignmentId = currentAssignment.id
attemptCounts[assignmentId, default: 0] += 1
```

This is needed for tiered celebrations (Task 7).

- [ ] **Step 6: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat: refactor ChatViewModel for multi-assignment continuous chat"
```

---

### Task 5: iOS — Refactor PracticeSessionView for Continuous Chat

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift`

- [ ] **Step 1: Simplify PracticeSessionView**

The view no longer manages per-assignment switching. It creates one ChatViewModel with all assignments and renders one ChatView.

Replace the entire body with:

```swift
struct PracticeSessionView: View {
    let sessionId: String
    let assignments: [PracticeAssignment]
    let apiClient: APIClient
    var onBack: (() -> Void)?

    @State private var chatViewModel: ChatViewModel?
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 0) {
            if isComplete {
                completionView
            } else if let vm = chatViewModel {
                ChatView(viewModel: vm, onBack: onBack)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { setupSession() }
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.success)
            }

            Text("Flot klaret!")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("Du har gennemført alle \(assignments.count) opgaver")
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            Button(action: { onBack?() }) {
                Text("Tilbage til forsiden")
                    .font(KvanteTheme.Fonts.buttonLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KvanteTheme.Colors.cream)
    }

    private func setupSession() {
        let parsed = assignments.map { ParsedAssignment(from: $0) }
        let vm = ChatViewModel(
            assignments: parsed,
            sessionId: sessionId,
            apiClient: apiClient
        )
        vm.onSetComplete = { isComplete = true }
        chatViewModel = vm
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift
git commit -m "feat: simplify PracticeSessionView — single continuous ChatView"
```

---

### Task 6: iOS — Progress Pill + Drawer

**Files:**
- Create: `ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatView.swift`

- [ ] **Step 1: Create ProgressPillView**

Create `ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift`:

```swift
import SwiftUI

struct ProgressPillView: View {
    let currentIndex: Int
    let totalCount: Int
    let completedIds: Set<String>
    let assignments: [ParsedAssignment]
    let onTapAssignment: (Int) -> Void

    @State private var showDrawer = false

    var body: some View {
        VStack(spacing: 0) {
            // Pill bar
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showDrawer.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Opgave \(currentIndex + 1) af \(totalCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.ink)

                    Spacer()

                    Text("\(completedIds.count) løst")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.success)

                    Image(systemName: showDrawer ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)

            // Drawer
            if showDrawer {
                drawerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var drawerContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(assignments.enumerated()), id: \.element.id) { index, assignment in
                    Button {
                        onTapAssignment(index)
                        withAnimation { showDrawer = false }
                    } label: {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 40, height: 40)
                            .foregroundStyle(tileTextColor(index: index))
                            .background(
                                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                    .fill(tileColor(index: index))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                    .stroke(tileBorderColor(index: index), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func tileColor(index: Int) -> Color {
        if completedIds.contains(assignments[index].id) {
            return KvanteTheme.Colors.success
        } else if index == currentIndex {
            return KvanteTheme.Colors.primary
        } else {
            return KvanteTheme.Colors.cream
        }
    }

    private func tileTextColor(index: Int) -> Color {
        if completedIds.contains(assignments[index].id) || index == currentIndex {
            return .white
        } else {
            return KvanteTheme.Colors.textMuted
        }
    }

    private func tileBorderColor(index: Int) -> Color {
        if completedIds.contains(assignments[index].id) || index == currentIndex {
            return .clear
        } else {
            return KvanteTheme.Colors.inkSubtle
        }
    }
}
```

- [ ] **Step 2: Add progress pill to ChatView**

In `ChatView.swift`, add the progress pill between the header and the scroll view. Insert after `chatHeader`:

```swift
// Progress pill (only in practice sessions with multiple assignments)
if let allAssignments = viewModel.allAssignments, allAssignments.count > 1 {
    ProgressPillView(
        currentIndex: viewModel.currentAssignmentIndex,
        totalCount: viewModel.totalAssignments,
        completedIds: viewModel.completedAssignmentIds,
        assignments: allAssignments,
        onTapAssignment: { index in
            viewModel.jumpToAssignment(index)
        }
    )
}
```

Note: `allAssignments` should be exposed as optional on ChatViewModel (nil if single-assignment mode, present if multi-assignment).

- [ ] **Step 3: Add jumpToAssignment to ChatViewModel**

```swift
func jumpToAssignment(_ index: Int) {
    guard index >= 0 && index < allAssignments.count else { return }
    currentAssignmentIndex = index
    // If not yet introduced, introduce it
    let assignment = allAssignments[index]
    let alreadyIntroduced = messages.contains { msg in
        if case .assignmentIntro(let a) = msg.content {
            return a.id == assignment.id
        }
        return false
    }
    if !alreadyIntroduced {
        let intro = ChatMessage(sender: .kvante, content: .assignmentIntro(assignment))
        messages.append(intro)
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/ProgressPillView.swift ios/Kvante/Kvante/Views/Chat/ChatView.swift ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat: progress pill with assignment drawer overlay"
```

---

### Task 7: iOS — Expand + Context Menu

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatInputBar.swift`

- [ ] **Step 1: Add all actions to + menu**

Update the Menu in ChatInputBar to include all four actions. Add two new callbacks:

```swift
struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCamera: () -> Void
    let onHelp: () -> Void
    let onExplainDifferent: (() -> Void)?
    let onSkip: (() -> Void)?
```

Update the Menu content:

```swift
Menu {
    Button { onCamera() } label: {
        Label("Scan mit svar", systemImage: "camera")
    }
    Button { onHelp() } label: {
        Label("Vis eksempel", systemImage: "lightbulb")
    }
    if let explain = onExplainDifferent {
        Button { explain() } label: {
            Label("Forklar anderledes", systemImage: "arrow.triangle.2.circlepath")
        }
    }
    if let skip = onSkip {
        Button { skip() } label: {
            Label("Spring over", systemImage: "forward")
        }
    }
} label: {
    Image(systemName: "plus")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(KvanteTheme.Colors.textMuted)
        .frame(width: 44, height: 44)
}
```

- [ ] **Step 2: Wire new callbacks in ChatView**

Update the ChatInputBar instantiation in `ChatView.swift`:

```swift
ChatInputBar(
    text: $viewModel.inputText,
    onSend: { viewModel.sendMessage() },
    onCamera: { viewModel.showScanner = true },
    onHelp: { viewModel.requestHelp() },
    onExplainDifferent: { viewModel.requestExplainDifferent() },
    onSkip: { viewModel.advanceToNextAssignment() }
)
```

- [ ] **Step 3: Add requestExplainDifferent to ChatViewModel**

```swift
func requestExplainDifferent() {
    guard let submissionId = currentSubmissionId else {
        let msg = ChatMessage(sender: .kvante, content: .text("Prøv først at løse opgaven, så kan jeg forklare på en anden måde."))
        messages.append(msg)
        return
    }
    let loadingId = addLoading("Kvante tænker...")
    Task {
        let response = try? await apiClient.sendFollowup(submissionId: submissionId, action: "explain_different")
        await MainActor.run {
            if let response {
                replaceLoading(loadingId, with: ChatMessage(sender: .kvante, content: .feedback(response)))
            } else {
                replaceLoading(loadingId, with: ChatMessage(sender: .kvante, content: .text("Beklager, jeg kunne ikke forklare på en anden måde lige nu.")))
            }
        }
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/ChatInputBar.swift ios/Kvante/Kvante/Views/Chat/ChatView.swift ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat: expand + context menu with all actions"
```

---

### Task 8: iOS — Tiered Celebrations

**Files:**
- Create: `ios/Kvante/Kvante/Views/Chat/CelebrationView.swift`
- Modify: `ios/Kvante/Kvante/Models/ChatMessage.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift`

- [ ] **Step 1: Add celebration content type**

In `ChatMessage.swift`, add a new case to `ChatMessageContent`:

```swift
case celebration(CelebrationTier)
```

Add the tier enum:

```swift
enum CelebrationTier {
    case routine      // simple correct answer
    case persevered   // correct after 2+ attempts
    case setComplete  // finished all assignments
}
```

- [ ] **Step 2: Create CelebrationView**

Create `ios/Kvante/Kvante/Views/Chat/CelebrationView.swift`:

```swift
import SwiftUI

struct CelebrationView: View {
    let tier: CelebrationTier
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            // Checkmark circle
            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.1))
                    .frame(width: tierSize, height: tierSize)
                Image(systemName: "checkmark")
                    .font(.system(size: tierSize * 0.4, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.success)
            }
            .scaleEffect(animateScale ? 1.0 : 0.5)
            .opacity(animateScale ? 1.0 : 0)

            Text(tierTitle)
                .font(.system(size: tierFontSize, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.success)

            if !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundStyle(KvanteTheme.Colors.ink)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                .fill(KvanteTheme.Colors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                        .stroke(KvanteTheme.Colors.success, lineWidth: 2)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animateScale = true
            }
        }
    }

    @State private var animateScale = false

    private var tierSize: CGFloat {
        switch tier {
        case .routine: return 48
        case .persevered: return 56
        case .setComplete: return 72
        }
    }

    private var tierFontSize: CGFloat {
        switch tier {
        case .routine: return 20
        case .persevered: return 22
        case .setComplete: return 28
        }
    }

    private var tierTitle: String {
        switch tier {
        case .routine: return "Rigtigt!"
        case .persevered: return "Du blev ved — og det lykkedes!"
        case .setComplete: return "Du klarede dem alle!"
        }
    }
}
```

- [ ] **Step 3: Add celebration case to ChatBubble**

In `ChatBubble.swift`, add to the `bubbleContent` switch:

```swift
case .celebration(let tier):
    CelebrationView(tier: tier, message: celebrationMessage(tier))
```

Add helper:

```swift
private func celebrationMessage(_ tier: CelebrationTier) -> String {
    switch tier {
    case .routine: return ""
    case .persevered: return "Godt gået at du ikke gav op."
    case .setComplete: return ""
    }
}
```

- [ ] **Step 4: Use celebrations in ChatViewModel**

When a correct answer is detected, determine the tier and add a celebration message:

```swift
// After detecting correct answer:
let attempts = attemptCounts[currentAssignment.id, default: 1]
let tier: CelebrationTier = attempts >= 2 ? .persevered : .routine
let celebration = ChatMessage(sender: .kvante, content: .celebration(tier))
messages.append(celebration)
```

For set completion in `advanceToNextAssignment()`:

```swift
if isSetComplete {
    let celebration = ChatMessage(sender: .kvante, content: .celebration(.setComplete))
    messages.append(celebration)
    onSetComplete?()
    return
}
```

- [ ] **Step 5: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build 2>&1 | grep -E "BUILD|error:" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/CelebrationView.swift ios/Kvante/Kvante/Models/ChatMessage.swift ios/Kvante/Kvante/Views/Chat/ChatBubble.swift ios/Kvante/Kvante/ViewModels/ChatViewModel.swift
git commit -m "feat: tiered celebration system — routine, persevered, set complete"
```

---

## Summary

| Task | Description | Backend/iOS | Files |
|------|-------------|-------------|-------|
| 1 | ChatMessage model + Session/Assignment extensions | Backend | `db.py` |
| 2 | Chat persistence endpoints + tests | Backend | `chat.py`, `schemas.py`, test |
| 3 | Assignment position in practice response | Backend | `practice.py` |
| 4 | Refactor ChatViewModel for continuous chat | iOS | `ChatViewModel.swift` |
| 5 | Simplify PracticeSessionView | iOS | `PracticeSessionView.swift` |
| 6 | Progress pill + drawer | iOS | New `ProgressPillView.swift`, `ChatView.swift` |
| 7 | Expand + context menu | iOS | `ChatInputBar.swift`, `ChatView.swift` |
| 8 | Tiered celebrations | iOS | New `CelebrationView.swift`, `ChatBubble.swift`, `ChatMessage.swift` |

**Dependencies:** Tasks 1-3 (backend) are independent. Task 4 must come before 5. Tasks 6-8 depend on 4-5 but are independent of each other.
