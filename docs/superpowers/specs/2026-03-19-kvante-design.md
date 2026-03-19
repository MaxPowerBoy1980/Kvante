# Kvante — Learning Assistant AI for Primary School Math

**Date:** 2026-03-19
**Status:** MVP / Demo
**Target users:** Primary school students, ages 9–13

## Overview

Kvante is a paper-and-pencil-first math learning assistant. Students solve math problems by hand on paper; the iPad serves as a camera and feedback display. Kvante analyzes photos of textbook pages and handwritten work using Claude Vision, provides method-focused feedback, and generates worked examples of similar (never identical) problems.

The name "Kvante" is Danish/Nordic, inspired by "quantum."

## Core Philosophy

1. **Paper-first** — The iPad is a camera and feedback display. The desk is where learning happens. No digital math input, no on-screen equation editors.
2. **Never give the assigned answer** — Kvante shows worked examples of similar-but-different problems. It hints at methodology. It points out process errors. It never reveals the answer to the actual assignment.
3. **Method over answer** — Feedback addresses methodology and reasoning, not just correctness. "I can see you started well by lining up the place values — now look at what happens when you carry from the tens column."
4. **Constrained interaction** — Students interact through fixed structured prompts rendered as large tappable buttons. No free-text input. This is both age-appropriate UX and a safety boundary.
5. **Transparency** — All AI prompts are stored as readable `.txt` files. Teachers and parents can read and modify them. The prompts ARE the pedagogy.
6. **Privacy** — Backend runs on the home network. Photos are stored locally. The only external call is to the Claude API (documented in a parent-facing settings screen). Production goal: swap to local open-source models to eliminate external calls entirely.

## What Kvante Is NOT

- NOT a general-purpose chatbot. Interaction is limited to structured prompts.
- NOT a calculator or answer machine. It never gives the answer to the assigned problem.
- NOT a screen-based learning tool. The screen is a support layer; the real work is on paper.

---

## Two Core Workflows

### Workflow A — Textbook Page Scan (primary entry point)

1. Student opens their physical math textbook to today's page
2. Student photographs the full page of assignments with the iPad
3. Kvante parses the page, identifies all individual assignments, and presents them as a numbered list
4. Kvante suggests which assignment to start with (based on difficulty progression)
5. Student picks an assignment and begins solving it by hand on paper
6. If stuck before starting: Kvante can show a **visual worked example of a similar (but different!) problem** with step-by-step method explanation. NEVER shows the solution to the actual assignment.
7. Student photographs their handwritten work and submits it
8. Kvante analyzes the work and gives constructive, method-focused feedback
9. Student uses structured prompts for follow-up, then moves to the next assignment

### Workflow B — Direct Work Submission

1. Student is already working on a known assignment
2. Student photographs their handwritten solution
3. Kvante analyzes and gives feedback (same as steps 7–9 above)

---

## Textbook Page Scanning (primary entry point)

Kvante's primary workflow starts with the student photographing a full page from their physical math textbook. Build this as the central entry point — not pre-loaded digital assignments:

1. Student taps "Scan din side" and photographs a full textbook page via VisionKit document scanner
2. Image is sent to backend endpoint `POST /pages/scan`
3. Backend preprocesses the image and sends it to Claude Vision with the `prompts/parse_page.txt` system prompt
4. Claude returns structured JSON with all assignments found on the page:

```json
{
  "session_id": "uuid",
  "assignments": [
    {
      "id": "3a",
      "text": "347 + 286 =",
      "type": "addition",
      "topic": "three-digit addition with carrying",
      "difficulty_estimate": 2,
      "position_on_page": "top-left"
    },
    {
      "id": "3b",
      "text": "1.203 - 847 =",
      "type": "subtraction",
      "topic": "four-digit subtraction with borrowing",
      "difficulty_estimate": 3,
      "position_on_page": "top-right"
    }
  ],
  "page_context": "Chapter 4: Addition and subtraction with large numbers",
  "suggested_order": ["3a", "3b", "3c", "3d"],
  "suggested_start": "3a",
  "reasoning": "3a is the simplest — single carry operation. Good warm-up before the subtraction tasks.",
  "detected_language": "da"
}
```

5. The iOS app displays assignments as colorful, numbered cards in `AssignmentPickerView`
6. Kvante's suggestion is highlighted: "Jeg foreslår du starter med opgave 3a!" (I suggest starting with 3a!)
7. Student taps a card and enters the working flow

Add `page_parser.py` as a dedicated service under `services/`. Write the `prompts/parse_page.txt` system prompt so it:
- Identifies every individual assignment/exercise on the page
- Ignores non-assignment content (illustrations, page numbers, instructional text, headers)
- Classifies assignment type and estimates difficulty relative to the other assignments on the page
- Suggests a pedagogically sound order (typically easiest first as warm-up, building to harder ones)
- Handles both Danish and English math textbooks
- Returns clean, structured JSON

---

## Example Generator ("Show me an example")

When a student is stuck BEFORE they begin working on an assignment, they can tap "Vis mig et eksempel" (Show me an example). This generates a fully worked example of a SIMILAR but DIFFERENT problem — demonstrating the methodology without revealing the answer.

Build `services/example_generator.py` with endpoint `POST /sessions/{session_id}/assignments/{assignment_id}/example`.

Write the `prompts/generate_example.txt` system prompt so it:
- Receives the assignment's type and topic as context
- Creates a NEW problem with DIFFERENT numbers and slightly different structure
- Solves the example step-by-step with clear methodology explanation at each step
- Uses simple language appropriate for ages 9–13
- Includes a brief "why we do it this way" for each step
- Writes in the student's configured language (Danish or English)
- Makes it OBVIOUS that the example is a different problem than the assigned one, so it cannot be copied as the answer

Return structured content that the iOS app can render as visual step-by-step cards:

```json
{
  "example_problem": "523 + 389 =",
  "steps": [
    {
      "step": 1,
      "instruction": "First, line up the numbers by place value",
      "visual": "  523\n+ 389\n-----",
      "explanation": "We write the numbers so ones are under ones, tens under tens, hundreds under hundreds."
    },
    {
      "step": 2,
      "instruction": "Add the ones column: 3 + 9 = 12",
      "visual": "  523\n+ 389\n-----\n    2  (carry 1)",
      "explanation": "12 is more than 9, so we write 2 and carry 1 to the tens column."
    }
  ],
  "note": "Notice this uses different numbers than your assignment — try the same method with your numbers!"
}
```

**Cardinal rule:** The example must NEVER use the same numbers as the real assignment.

---

## Work Analyzer ("Scan my answer")

When a student photographs their handwritten work, Kvante analyzes their methodology — not just the final answer. Build `services/work_analyzer.py` with endpoint `POST /submissions/`.

The backend receives the photo alongside `session_id` and `assignment_id`, preprocesses the image (critical for pencil-on-paper — see Image Preprocessing section), and sends both the image and the original assignment context to Claude Vision with the `prompts/analyze_work.txt` system prompt.

Write the `prompts/analyze_work.txt` system prompt so it:
- Receives both the original assignment context AND the photo of student work
- Reads the handwritten numbers and operations carefully
- Traces the student's step-by-step methodology
- Distinguishes between: understanding errors (wrong method), procedural errors (right method, execution mistake), and careless errors (clearly knows the method, slipped up)
- Notes what the student did correctly — always find something positive
- Assesses handwriting clarity (relevant for the paper-first philosophy)
- If the photo is unclear or the work is hard to read, says so honestly rather than guessing
- Outputs structured JSON

Response schema:

```json
{
  "submission_id": "uuid",
  "assignment_id": "3a",
  "session_id": "uuid",
  "student_answer": "633",
  "methodology_sound": true,
  "steps_identified": [
    {"step": 1, "description": "Added ones: 7+6=13, wrote 3, carried 1", "correct": true},
    {"step": 2, "description": "Added tens: 4+8+1=13, wrote 3, carried 1", "correct": true},
    {"step": 3, "description": "Added hundreds: 3+2+1=6", "correct": true}
  ],
  "errors": [],
  "correct_elements": ["Carrying technique", "Place value alignment"],
  "methodology_assessment": "Clean, systematic approach. Student clearly understands carrying.",
  "handwriting_note": "Numbers are well-formed and easy to read.",
  "confidence": 0.95
}
```

The response deliberately omits the correct answer. The `methodology_sound` boolean indicates whether the student's approach and result are correct, used by the frontend to branch between celebratory and corrective feedback tones. The actual correct answer is computed server-side for Claude's analysis but never sent to the client.

---

## Feedback Generator

Takes the work analysis and produces kid-friendly, method-focused feedback. Build `services/feedback_generator.py` with endpoint `POST /feedback/`.

Request: `submission_id` + `language` (da/en)

Write the `prompts/give_feedback.txt` system prompt so it:
- Uses simple, encouraging language appropriate for ages 9–13
- ALWAYS starts with something positive the student did
- Explains errors through methodology: not "that's wrong" but "When you added the ones column, try counting again carefully — you're so close!"
- ABSOLUTELY NEVER reveals the correct answer. This is the cardinal rule.
- Uses analogies and concrete examples when helpful
- Keeps feedback to 3–4 sentences max — kids lose attention with walls of text
- If everything is correct: celebrates genuinely, notes what was done well methodologically, encourages moving to the next assignment
- Writes in the student's configured language
- Tone: warm, patient, like a favorite tutor. Never condescending. Never robotic.

Response:

```json
{
  "feedback_text": "Flot arbejde! Du har stillet tallene pænt op og husket at gemme mente rigtigt i alle tre trin. Din metode er helt korrekt — du er klar til næste opgave!",
  "tone": "celebratory",
  "structured_prompts": [
    {"id": "explain_different", "label": "Forklar på en anden måde"},
    {"id": "another_example", "label": "Vis mig et andet eksempel"},
    {"id": "what_did_well", "label": "Hvad gjorde jeg godt?"},
    {"id": "try_again", "label": "Jeg vil prøve igen"},
    {"id": "next_assignment", "label": "Næste opgave"}
  ]
}
```

---

## Method Re-Explanation ("Explain in a different way")

Used when student taps "Forklar på en anden måde." Build as part of `POST /feedback/{submission_id}/followup` with `action: "explain_different"`.

Write the `prompts/explain_method.txt` system prompt so it:
- Takes the previous feedback and the assignment context
- Re-explains the concept using a DIFFERENT approach (different analogy, different angle, more concrete)
- If the first explanation was abstract, makes it concrete. If it was concrete, tries visual/spatial.
- Still never gives the answer
- Keeps it short — 2–3 sentences, then asks if that helps

---

## Contextual Interaction Buttons (State Machine)

The button set in `StructuredPromptBar` must change depending on the student's current state. Model this as a state machine in both backend and iOS:

### State: Assignment selected, no work submitted yet

| Button (Danish) | Button (English) | ID | Action |
|---|---|---|---|
| "Vis mig et eksempel" | "Show me an example" | `show_example` | Triggers the example generator |
| "Jeg forstår ikke opgaven" | "I don't understand the task" | `explain_task` | Kvante re-explains what the assignment is asking in simpler terms |
| "Jeg starter nu!" | "I'll start now!" | `start_working` | Transitions to the working state |

### State: Working (assignment started, camera available)

The student is solving on paper. The iPad shows the assignment text and:
- "Vis mig et eksempel" / "Show me an example" → `show_example`
- "Scan mit svar" / "Scan my answer" → opens VisionKit camera for handwritten work
- "Jeg forstår ikke opgaven" / "I don't understand the task" → `explain_task`

### State: Work submitted, feedback received

| Button (Danish) | Button (English) | ID | Action |
|---|---|---|---|
| "Forklar på en anden måde" | "Explain in a different way" | `explain_different` | Re-phrases feedback using a different approach/analogy |
| "Vis mig et andet eksempel" | "Give me another example" | `another_example` | New similar worked example |
| "Jeg sidder fast — vis mig første skridt" | "I'm stuck — show me the first step" | `show_first_step` | Hints at methodology for the first step only |
| "Hvad gjorde jeg godt?" | "What did I do well?" | `what_did_well` | Positive reinforcement on correct methodology |
| "Jeg vil prøve igen" | "I want to try again" | `try_again` | Resets for a new photo of revised work |
| "Næste opgave" | "Next assignment" | `next_assignment` | Returns to assignment picker |

The backend endpoint `POST /feedback/{submission_id}/followup` accepts an `action` enum matching these IDs. The iOS app renders the appropriate button set based on the current state and sends the enum value.

Structured prompt labels are localized based on the session's detected language. The `id` field is the stable API contract; `label` is display text.

### Focus enforcement

If a student somehow sends off-topic input (possible if voice input is added later): "That's an interesting thought! But right now, let's focus on your math. Which of these would help you?" — then re-present the structured options. Never engage with off-topic conversation.

---

## "Never Give The Answer" Enforcement

This is an absolute rule. Enforced at two levels:

1. **Prompt-level:** Every system prompt explicitly instructs Claude never to reveal the assigned answer. This instruction appears prominently in every prompt file.
2. **Example generator:** Produces problems with deliberately different numbers/structure so there is no ambiguity.

For MVP, prompt-level enforcement is sufficient. Production could add output validation as a safety net (scan Claude's response for the correct answer string before sending to client).

---

## Image Preprocessing for Pencil-on-Paper

Pencil on paper is low-contrast. This is where the demo breaks down if not handled properly. Build a preprocessing pipeline in `services/image_preprocessor.py`:

### Upload constraints
- **Accepted formats:** JPEG (preferred), HEIC, PNG
- **Maximum upload size:** 10 MB
- **Resizing:** Server-side. iPad sends full-resolution photos; backend handles all preprocessing.

### Preprocessing pipeline

1. Resize to max 1568px on the longest side (Claude Vision's optimal quality limit)
2. Convert to grayscale
3. Apply CLAHE (Contrast Limited Adaptive Histogram Equalization) to boost faint pencil strokes
4. Light sharpening (unsharp mask)
5. Store the original image in the database; only send the preprocessed version to Claude

Use Pillow as the primary library. Fall back to OpenCV (`opencv-python-headless`) if CLAHE results require it.

### Printed textbook pages (lighter preprocessing)
- Resize to max 1568px longest side
- Light contrast enhancement (no CLAHE needed — printed text is high-contrast)

### Handwritten pencil work (aggressive preprocessing — critical path)
- Full pipeline: grayscale → CLAHE → sharpen → resize
- Must be tested with REAL pencil-on-paper photos
- Not printed, typed, or digitally drawn numbers — the difference is significant

**Critical:** Test with REAL photos of pencil-on-paper from actual student homework. This is where demos break.

---

## Session Model

A "session" = one scanned textbook page. Model this explicitly in the database:

```python
class Session(Base):
    id: str                    # UUID
    student_id: str            # FK to student
    page_image_path: str       # Original photo of the textbook page
    parsed_assignments: JSON   # JSON output from page_parser
    detected_language: str     # "da" or "en", auto-detected from textbook
    created_at: datetime
    status: str                # "active" | "completed"

class Assignment(Base):
    id: str                    # UUID (server-generated)
    session_id: str            # FK to session
    local_id: str              # "3a", "3b" etc. from parsed_assignments
    text: str                  # Assignment text
    type: str                  # "addition", "subtraction", etc.
    topic: str                 # "three-digit addition with carrying"
    difficulty_estimate: int   # Relative to other assignments on the page
    status: str                # "not_started" | "in_progress" | "completed"

class Submission(Base):
    id: str                    # UUID
    session_id: str            # FK to session
    assignment_id: str         # FK to assignment
    work_image_path: str       # Photo of student's handwritten work
    preprocessed_image_path: str  # Preprocessed version sent to Claude
    analysis: JSON             # Structured analysis from work_analyzer
    feedback_text: str         # Generated feedback
    attempt_number: int        # 1, 2, 3... (for the "try again" flow)
    created_at: datetime

class Student(Base):
    # Placeholder for MVP — single default student
    # Multi-student profiles in Phase 3
    id: str                    # UUID
    name: str
    language: str              # "da" or "en"
    created_at: datetime
```

Sessions persist in SQLite so the student can leave the app and return to their assignments later. The home screen shows active/recent sessions.

---

## Network Discovery (Bonjour/mDNS)

Children should not have to type IP addresses. Implement zero-config network discovery:

**Backend (Python):** Register a Bonjour service on startup using the `zeroconf` package:
```python
# Register as "_kvante._tcp.local." on port 8000
from zeroconf import ServiceInfo, Zeroconf
import socket

info = ServiceInfo(
    "_kvante._tcp.local.",
    "Kvante Math Assistant._kvante._tcp.local.",
    addresses=[socket.inet_aton("0.0.0.0")],
    port=8000,
)
zeroconf = Zeroconf()
zeroconf.register_service(info)
```

**iOS (Swift):** Use `NWBrowser` to automatically discover the Kvante server on the local network:
```swift
let browser = NWBrowser(for: .bonjour(type: "_kvante._tcp", domain: nil), using: .tcp)
browser.stateUpdateHandler = { state in /* handle state changes */ }
browser.browseResultsChangedHandler = { results, changes in
    // Extract endpoint from results
}
browser.start(queue: .main)
```

If no server is found, show a friendly message: "Kvante leder efter din server..." (Kvante is looking for your server...) with a retry button. No manual IP entry in the student-facing UI. Manual IP entry available in a parent/teacher settings screen as fallback.

The iPad verifies connectivity after discovery by calling `GET /health`:
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

---

## Error Handling

### Standard error response envelope

All endpoints return errors in a consistent shape:

```json
{
  "error": "unreadable_photo",
  "message": "Could not read the handwritten work clearly enough to analyze.",
  "student_message": "Jeg kan ikke helt læse dit svar — kan du prøve at tage et tydeligere billede?",
  "detail": "Confidence below threshold (0.3)"
}
```

- `error` — stable machine-readable code for programmatic handling
- `message` — developer-facing description
- `student_message` — kid-friendly message the iOS app can display directly (present on 422 errors)
- `detail` — optional technical detail for debugging

### HTTP status codes

- `400` — Invalid request (missing fields, unsupported image format)
- `404` — Session or assignment not found
- `422` — Image received but unprocessable (too blurry, no assignments found, unreadable handwriting)
- `500` — Internal error (Claude API timeout, unexpected failure)
- `503` — Claude API unavailable

### Unclear photo handling

Kvante must NEVER guess when the image is unclear. Add to all analysis system prompts:

- If the image is too blurry, too dark, or the handwriting is illegible: return `"confidence": 0` and `"error": "unclear_image"`
- Backend maps this to a friendly message: "Jeg kan ikke helt læse dit arbejde — kan du prøve at tage et tydeligere billede? Sørg for godt lys og hold iPad'en rolig." (I'm having trouble reading your work — could you try taking a clearer photo? Make sure you have good lighting and hold the iPad steady.)
- iOS displays this message with a "Tag et nyt billede" (Take a new photo) button directly

Add a `confidence_threshold` in config (default: `0.6`) — anything below triggers the "unclear image" flow instead of attempting to give feedback on uncertain data.

---

## Architecture

### Two-Tier System

- **Backend (Mac Mini, macOS):** FastAPI server handling all AI logic, prompt management, and data persistence
- **Frontend (iPad):** SwiftUI app providing camera, display, and structured interaction

Communication over local WiFi, discovered via Bonjour/mDNS. The only external dependency is the Claude API.

### Data Flow

```
iPad Camera → JPEG → Backend API → Pillow preprocessing → Claude Vision API
                                                              ↓
iPad Display ← JSON response ← Feedback/Example generator ← Structured analysis
```

---

## Tech Stack

### Backend

- **Language:** Python 3.11+
- **Framework:** FastAPI with uvicorn
- **AI:** Claude API via `anthropic` SDK — `claude-sonnet-4-20250514` for vision analysis (textbook pages, handwriting) and feedback generation
- **Database:** SQLite via SQLAlchemy (simple, file-based, easy to back up)
- **Image processing:** Pillow for preprocessing; `opencv-python-headless` as fallback for CLAHE
- **Network discovery:** `zeroconf` for mDNS/Bonjour service registration
- **Config:** `.env` file with `python-dotenv`. Store `ANTHROPIC_API_KEY` in `.env`.
- **Auth:** Simple API key per device (hardcoded in config for demo, proper JWT later)

### Frontend (iPad / iOS)

- **Language:** Swift 5.9+
- **UI:** SwiftUI, minimum iPadOS 17
- **Camera:** VisionKit `VNDocumentCameraViewController` (auto-crop, perspective correction for free — works for both textbook pages and handwritten paper)
- **Networking:** URLSession with async/await
- **Storage:** SwiftData for caching parsed assignments and feedback history
- **Discovery:** `NWBrowser` for Bonjour service discovery
- **Design:** Large, friendly, colorful UI. Big tappable buttons. No keyboard/text input for students. Minimum 60×60pt tap targets. Think "Fisher-Price meets Khan Academy." Kid-tested, not developer-tested.

---

## Project Structure

```
kvante/
├── backend/
│   ├── app/
│   │   ├── main.py                    # FastAPI app, CORS, startup checks
│   │   ├── config.py                  # Settings, API keys, model config, confidence_threshold
│   │   ├── routers/
│   │   │   ├── pages.py               # Textbook page upload + parsing
│   │   │   ├── assignments.py         # Individual assignment management
│   │   │   ├── submissions.py         # Handwritten work upload + analysis
│   │   │   └── feedback.py            # Structured follow-up interactions
│   │   ├── services/
│   │   │   ├── page_parser.py         # Parse textbook page photo → list of assignments
│   │   │   ├── example_generator.py   # Generate similar worked examples (not the answer!)
│   │   │   ├── work_analyzer.py       # Analyze handwritten student work
│   │   │   ├── feedback_generator.py  # Produce kid-friendly method-focused feedback
│   │   │   ├── image_preprocessor.py  # Pillow/OpenCV preprocessing pipeline
│   │   │   └── difficulty.py          # Assignment ordering / difficulty estimation (Claude-generated during page parsing)
│   │   ├── models/
│   │   │   ├── page.py                # Scanned textbook page
│   │   │   ├── assignment.py          # Individual parsed assignment
│   │   │   ├── submission.py          # Student work submission
│   │   │   └── student.py             # Student profile (placeholder — single default student for MVP, multi-student in Phase 3)
│   │   └── prompts/
│   │       ├── parse_page.txt         # System prompt: extract assignments from textbook photo
│   │       ├── generate_example.txt   # System prompt: create a similar worked example
│   │       ├── analyze_work.txt       # System prompt: analyze handwritten student work
│   │       ├── give_feedback.txt      # System prompt: generate student-facing feedback
│   │       └── explain_method.txt     # System prompt: re-explain a concept differently
│   ├── tests/
│   │   ├── test_page_parser.py
│   │   ├── test_work_analyzer.py
│   │   └── sample_photos/             # Real photos of textbook pages and handwritten work
│   ├── requirements.txt
│   └── .env.example
├── ios/
│   └── Kvante/
│       ├── KvanteApp.swift
│       ├── Views/
│       │   ├── HomeView.swift              # "Scan din side" big button + active sessions
│       │   ├── PageScanView.swift           # Camera for textbook page
│       │   ├── AssignmentPickerView.swift    # Parsed assignments as tappable cards
│       │   ├── WorkingView.swift            # Active assignment: shows task, "I'm stuck", "Scan my work"
│       │   ├── ExampleView.swift            # Visual worked example of a SIMILAR problem
│       │   ├── WorkScanView.swift           # Camera for handwritten solution
│       │   ├── FeedbackView.swift           # AI feedback display
│       │   └── StructuredPromptBar.swift    # The constrained interaction buttons (state machine)
│       ├── Models/
│       │   ├── Assignment.swift
│       │   ├── Submission.swift
│       │   └── Session.swift                # A "session" = one textbook page worth of work
│       ├── Services/
│       │   ├── APIClient.swift
│       │   ├── ImageProcessor.swift
│       │   └── BonjourDiscovery.swift       # Auto-find the Mac Mini on local network
│       └── Resources/
│           └── Assets.xcassets               # App icon, colors, illustrations
└── docs/
    ├── PEDAGOGY.md              # Design principles for the feedback system
    └── PROMPTS.md               # Documentation of all system prompts and their rationale
```

---

## API Contracts

### GET `/health`

Health check for Bonjour discovery verification.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

### POST `/pages/scan`

Upload a textbook page photo. Returns parsed assignments and creates a new session.

**Request:** multipart/form-data with image file

**Response:** See Textbook Page Scanning section above for full schema.

### POST `/sessions/{session_id}/assignments/{assignment_id}/example`

Generate a worked example of a similar problem. Assignment IDs are scoped to a session.

**Response:** See Example Generator section above for full schema.

### POST `/submissions/`

Upload handwritten work photo for analysis.

**Request:** multipart/form-data with image file + `session_id` + `assignment_id`

**Response:** See Work Analyzer section above for full schema.

### POST `/feedback/`

Generate student-facing feedback from analysis.

**Request:** `submission_id` + `language` (da/en)

**Response:** See Feedback Generator section above for full schema.

### POST `/feedback/{submission_id}/followup`

Handle structured follow-up prompts.

**Request:** `action` enum — one of: `explain_different`, `another_example`, `show_first_step`, `what_did_well`, `try_again`

**Response:** Same shape as feedback response, with updated text and prompts appropriate to the new state.

### Error Responses

See Error Handling section above for standard envelope and status codes.

---

## Multi-Part Assignment Handling (MVP)

For MVP, all sub-parts (3a, 3b, 3c, etc.) are treated as flat, independent items. No dependency tracking between sub-parts. This simplifies the page parser output and assignment picker.

Dependency-aware ordering (e.g., "use your answer from 3a to solve 3b") is deferred to a future phase.

---

## System Prompts — Detailed Requirements

The prompts are the heart of Kvante. They define the pedagogical approach. All prompts are stored as readable `.txt` files in `backend/app/prompts/`. Teachers and parents can read and modify them. No black-box behavior.

### `parse_page.txt`

Instruct Claude to:
- Examine the photo of a textbook page
- Identify every individual assignment/exercise on the page
- Extract the text/numbers of each assignment
- Classify type (addition, subtraction, multiplication, division, fractions, geometry, word problem, etc.)
- Estimate difficulty relative to the other assignments on the page
- Suggest a pedagogically sound order (typically: easiest first as warm-up, building to harder ones)
- Handle messy real-world pages: illustrations, instructions text, page numbers — ignore non-assignment content
- Handle both Danish and English textbooks
- Auto-detect textbook language
- Return clean structured JSON matching the schema in the Textbook Page Scanning section

### `generate_example.txt`

Instruct Claude to:
- Given an assignment type and topic, create a DIFFERENT problem of similar difficulty
- Solve the example problem step-by-step, explaining the methodology at each step
- Use simple language appropriate for ages 9–13
- Make the explanation visual and concrete (e.g., "First, let's line up our numbers by place value...")
- The example must use DIFFERENT numbers than the real assignment — make this obvious
- Include a brief "why we do it this way" for each step
- Write in the student's language (Danish or English)
- Return structured JSON matching the schema in the Example Generator section

### `analyze_work.txt`

Instruct Claude to:
- Receive both the original assignment context AND the photo of student work
- Read the handwritten numbers and operations carefully
- Trace the student's step-by-step methodology
- Identify where errors occur in the PROCESS, not just the final answer
- Distinguish between: understanding errors (wrong method), procedural errors (right method, execution mistake), and careless errors (clearly knows the method, slipped up)
- Note what the student did correctly — always find something positive
- Assess handwriting clarity (relevant for the paper-first philosophy)
- Output structured JSON matching the schema in the Work Analyzer section
- If the photo is unclear or the work is hard to read, return `confidence: 0` and `error: "unclear_image"` rather than guessing

### `give_feedback.txt`

Instruct Claude to:
- Use simple, encouraging language appropriate for ages 9–13
- ALWAYS start with something positive the student did
- Explain errors through methodology: not "8+7 is not 14" but "When you added the ones column, try counting again carefully — you're so close!"
- ABSOLUTELY NEVER reveal the correct answer. This is the cardinal rule.
- Use analogies and concrete examples when helpful
- Keep feedback to 3–4 sentences max — kids lose attention with walls of text
- If everything is correct: celebrate genuinely, note what was done well methodologically, encourage moving to the next assignment
- Write in the student's configured language
- Tone: warm, patient, like a favorite tutor. Never condescending. Never robotic.

### `explain_method.txt`

Used when student taps "Forklar på en anden måde." Instruct Claude to:
- Take the previous feedback and the assignment context
- Re-explain the concept using a DIFFERENT approach (different analogy, different angle, more concrete)
- If the first explanation was abstract, make it concrete. If it was concrete, try visual/spatial.
- Still never give the answer
- Keep it short — 2–3 sentences, then ask if that helps

---

## iOS App — Detailed View Specifications

### Home Screen (`HomeView`)

One big friendly button: "Scan din side" (Scan your page). Below it: list of active/recent sessions showing date and assignment completion progress.

### Page Scan Flow

1. Tap "Scan din side" → opens VisionKit document scanner
2. Student photographs the textbook page
3. Loading animation: "Kvante kigger på din side..." (Kvante is looking at your page...)
4. `AssignmentPickerView` appears: parsed assignments as colorful numbered cards
5. Kvante's suggestion is highlighted: "Jeg foreslår du starter med opgave 3a!"
6. Student taps an assignment card → enters `WorkingView`

### Working Flow

1. `WorkingView` shows the assignment text at top
2. Three big buttons:
   - "Vis mig et eksempel" (Show me an example) → visual worked example
   - "Jeg forstår ikke opgaven" (I don't understand the task) → re-explanation
   - "Scan mit svar" (Scan my answer) → opens VisionKit camera for handwritten work
3. After scanning work: loading animation "Kvante kigger på dit svar..." (Kvante is looking at your answer...), then `FeedbackView`
4. `FeedbackView`: AI feedback in large friendly text + structured prompt buttons for follow-up
5. "Næste opgave" (Next assignment) button to return to the assignment picker

### Key UI Requirements

- No text input fields anywhere in the student UI
- Minimum tap target 60×60pt (kid-friendly)
- Bright, warm color palette. Not clinical.
- Loading states are friendly animations, not spinners
- Danish as default language, easy to switch to English
- All student-facing strings localizable

---

## Key Technical Notes

- **Claude Vision API:** Use the Messages API with `image` content blocks (base64-encoded). Both textbook pages (printed text) and handwritten work (pencil on paper) are sent as images. Preprocess handwritten work more aggressively (contrast enhancement) than printed pages.
- **Claude model:** `claude-sonnet-4-20250514` for all vision and text tasks. Sonnet is the right price/performance balance for demo scale.
- **Response time:** Claude API calls are ~2–5 seconds. Page parsing may take ~5–8 seconds for a full page. Always show friendly loading animations.
- **iOS timeouts:** 30-second timeout for Claude API calls. No automatic retry. Show a "Prøv igen" (Try again) button on timeout.
- **Cost:** At demo scale (a few hundred submissions/day) the Claude API cost is negligible. Log token usage per call for awareness.
- **CORS:** Configure FastAPI CORS middleware. Origin: `*` for MVP (local network only). Tighten for production.
- **Language:** Danish default, English switchable. Textbook language is auto-detected during page scan. Detected language is used as default for feedback; overridable via `language` parameter on feedback endpoints.

---

## Implementation Phases

### Phase 1: Backend — Page Parsing + Work Analysis (start here)

1. Set up the FastAPI project with all routers and services stubbed out
2. Write the system prompts first — they define the product. These are the most critical deliverable.
3. Get `page_parser.py` working: photograph a real Danish math textbook page, send it to Claude, verify the JSON output is accurate
4. Get `work_analyzer.py` working: photograph real pencil-on-paper student work, verify analysis quality
5. Get `example_generator.py` working: verify it creates DIFFERENT problems (not the assigned one) with clear methodology
6. Get `feedback_generator.py` working: verify tone is warm, method-focused, and never reveals answers
7. Wire up all routers with proper request/response schemas
8. Test the full flow: page scan → pick assignment → get example → submit work → receive feedback

The most critical thing is prompt quality. Everything else is plumbing. Iterate on the prompts with real photos from actual math textbooks and homework.

### Phase 2: iOS App (MVP)

1. Home screen with "Scan din side" button + active sessions list
2. Page scan flow with VisionKit document scanner
3. Assignment picker with colored cards and Kvante suggestion
4. Working view with structured prompt buttons (state machine)
5. Work scan via VisionKit and feedback display
6. Bonjour discovery with `NWBrowser`
7. Danish-first UI with localization support

### Phase 3: Polish & Expand (future)

- Voice input (Whisper STT → intent classification into structured options)
- Progress tracking: which assignments completed, accuracy trends
- Teacher/parent dashboard (simple web UI): view submissions, feedback history, progress
- Multi-student support with profiles
- Assignment difficulty adaptation based on student performance
- Support for more math topics (geometry, fractions, word problems)
- Offline mode: queue submissions for when backend is reachable
- Local open-source models to eliminate external API calls
