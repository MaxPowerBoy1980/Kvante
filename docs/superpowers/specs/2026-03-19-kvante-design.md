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
5. **Transparency** — All AI prompts are stored as readable `.txt` files. Teachers and parents can read and modify them.
6. **Privacy** — Backend runs on the home network. Photos are stored locally. The only external call is to the Claude API (documented in a parent-facing settings screen).

## What Kvante Is NOT

- NOT a general-purpose chatbot
- NOT a calculator or answer machine
- NOT a screen-based learning tool

## Two Core Workflows

### Workflow A — Textbook Page Scan (primary entry point)

1. Student photographs their math textbook page with the iPad
2. Kvante parses the page, identifies all assignments, presents them as numbered cards
3. Kvante suggests which assignment to start with (difficulty-based)
4. Student picks an assignment and solves it by hand on paper
5. If stuck: Kvante shows a worked example of a similar (different!) problem
6. Student photographs their handwritten work
7. Kvante analyzes the work and gives constructive, method-focused feedback
8. Student uses structured prompts for follow-up, then moves to the next assignment

### Workflow B — Direct Work Submission

1. Student photographs their handwritten solution for a known assignment
2. Kvante analyzes and gives feedback (same as steps 7–8 above)

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

### Session Model

- A **Session** = one scanned textbook page
- Sessions contain **Assignments** (flat list, independent — no dependency tracking for MVP)
- Assignments contain **Submissions** (photos + analysis + feedback)
- All state persists in SQLite so students can resume

## Tech Stack

### Backend

- **Language:** Python 3.11+
- **Framework:** FastAPI with uvicorn
- **AI:** Claude API via `anthropic` SDK — `claude-sonnet-4-20250514` for vision and text
- **Database:** SQLite via SQLAlchemy
- **Image processing:** Pillow (grayscale, CLAHE contrast enhancement, sharpening)
- **Network discovery:** `zeroconf` for mDNS/Bonjour
- **Config:** `.env` file with `python-dotenv`
- **Auth:** Simple API key per device (hardcoded for demo)

### Frontend (iPad / iOS)

- **Language:** Swift 5.9+
- **UI:** SwiftUI, minimum iPadOS 17
- **Camera:** VisionKit `VNDocumentCameraViewController` (auto-crop, perspective correction)
- **Networking:** URLSession with async/await
- **Storage:** SwiftData for local caching
- **Discovery:** `NWBrowser` for Bonjour
- **Design:** Large, friendly, colorful. Minimum 60×60pt tap targets. "Fisher-Price meets Khan Academy."

## Project Structure

```
kvante/
├── backend/
│   ├── app/
│   │   ├── main.py                    # FastAPI app, CORS, startup
│   │   ├── config.py                  # Settings, API keys, model config
│   │   ├── routers/
│   │   │   ├── pages.py               # Textbook page upload + parsing
│   │   │   ├── assignments.py         # Assignment management
│   │   │   ├── submissions.py         # Work upload + analysis
│   │   │   └── feedback.py            # Structured follow-up interactions
│   │   ├── services/
│   │   │   ├── page_parser.py         # Parse textbook page → assignment list
│   │   │   ├── example_generator.py   # Generate similar worked examples
│   │   │   ├── work_analyzer.py       # Analyze handwritten student work
│   │   │   ├── feedback_generator.py  # Kid-friendly method-focused feedback
│   │   │   └── difficulty.py          # Assignment ordering / difficulty
│   │   ├── models/
│   │   │   ├── page.py                # Scanned textbook page
│   │   │   ├── assignment.py          # Parsed assignment
│   │   │   ├── submission.py          # Student work submission
│   │   │   └── student.py             # Student profile (placeholder — single default student for MVP, multi-student in Phase 3)
│   │   └── prompts/
│   │       ├── parse_page.txt         # Extract assignments from textbook photo
│   │       ├── generate_example.txt   # Create similar worked example
│   │       ├── analyze_work.txt       # Analyze handwritten student work
│   │       ├── give_feedback.txt      # Generate student-facing feedback
│   │       └── explain_method.txt     # Re-explain concept differently
│   ├── tests/
│   │   ├── test_page_parser.py
│   │   ├── test_work_analyzer.py
│   │   └── sample_photos/
│   ├── requirements.txt
│   └── .env.example
├── ios/
│   └── Kvante/
│       ├── KvanteApp.swift
│       ├── Views/
│       │   ├── HomeView.swift
│       │   ├── PageScanView.swift
│       │   ├── AssignmentPickerView.swift
│       │   ├── WorkingView.swift
│       │   ├── ExampleView.swift
│       │   ├── WorkScanView.swift
│       │   ├── FeedbackView.swift
│       │   └── StructuredPromptBar.swift
│       ├── Models/
│       │   ├── Assignment.swift
│       │   ├── Submission.swift
│       │   └── Session.swift
│       ├── Services/
│       │   ├── APIClient.swift
│       │   ├── ImageProcessor.swift
│       │   └── BonjourDiscovery.swift
│       └── Resources/
│           └── Assets.xcassets
└── docs/
    ├── PEDAGOGY.md
    └── PROMPTS.md
```

## API Contracts

### POST `/pages/scan`

Upload a textbook page photo. Returns parsed assignments.

**Request:** multipart/form-data with image file

**Response:**
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
    }
  ],
  "page_context": "Chapter 4: Addition and subtraction with large numbers",
  "suggested_order": ["3a", "3b", "3c", "3d"],
  "suggested_start": "3a",
  "reasoning": "3a is the simplest — single carrying operation.",
  "detected_language": "da"
}
```

### GET `/health`

Health check for Bonjour discovery verification.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

### POST `/sessions/{session_id}/assignments/{assignment_id}/example`

Generate a worked example of a similar problem. Assignment IDs (e.g., "3a") are scoped to a session.

**Response:**
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

### POST `/submissions/`

Upload handwritten work photo for analysis.

**Request:** multipart/form-data with image file + `session_id` + `assignment_id`

**Response:**
```json
{
  "submission_id": "uuid",
  "assignment_id": "3a",
  "session_id": "uuid",
  "student_answer": "633",
  "methodology_sound": true,
  "steps_identified": [
    {"step": 1, "description": "Added ones: 7+6=13, wrote 3, carried 1", "correct": true}
  ],
  "errors": [],
  "correct_elements": ["Carrying technique", "Place value alignment"],
  "methodology_assessment": "Clean, systematic approach.",
  "confidence": 0.95
}
```

Note: The response deliberately omits the correct answer. The `methodology_sound` boolean indicates whether the student's approach and result are correct, used by the frontend to branch between celebratory and corrective feedback tones. The actual correct answer is computed server-side for Claude's analysis but never sent to the client.
```

### POST `/feedback/`

Generate student-facing feedback from analysis.

**Request:** `submission_id` + `language` (da/en)

**Response:**
```json
{
  "feedback_text": "Flot arbejde! Du har stillet tallene pænt op...",
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

### POST `/feedback/{submission_id}/followup`

Handle structured follow-up prompts.

**Request:** `prompt_id` (one of the structured prompt IDs)

**Response:** Same shape as feedback response, with updated text and prompts.

### Error Responses

All endpoints return errors in a standard envelope:

```json
{
  "error": "unreadable_photo",
  "message": "Could not read the handwritten work clearly enough to analyze.",
  "student_message": "Jeg kan ikke helt læse dit svar — kan du prøve at tage et tydeligere billede?",
  "detail": "Confidence below threshold (0.3)"
}
```

**HTTP status codes:**
- `400` — Invalid request (missing fields, unsupported image format)
- `404` — Session or assignment not found
- `422` — Image received but unprocessable (too blurry, no assignments found, unreadable handwriting)
- `500` — Internal error (Claude API timeout, unexpected failure)
- `503` — Claude API unavailable

The `student_message` field (present on 422 errors) contains a kid-friendly message the iOS app can display directly. The `error` field is a stable machine-readable code for programmatic handling.

## Structured Prompts

Context-dependent buttons — no free text input.

### Before starting (assignment selected, no work submitted)

| Button | ID | Action |
|---|---|---|
| "Vis mig et eksempel" | `show_example` | Trigger worked example of similar problem |
| "Jeg forstår ikke opgaven" | `explain_task` | Re-explain what the assignment asks |
| "Jeg starter nu!" | `start_working` | Transition to working state |

### After submitting work

| Button | ID | Action |
|---|---|---|
| "Forklar på en anden måde" | `explain_different` | Re-phrase feedback differently |
| "Vis mig et andet eksempel" | `another_example` | Another similar worked example |
| "Hvad gjorde jeg godt?" | `what_did_well` | Positive reinforcement |
| "Jeg vil prøve igen" | `try_again` | Reset for new photo |
| "Næste opgave" | `next_assignment` | Return to assignment picker |

### Focus enforcement

Structured prompt labels are localized based on the session's detected language. The `id` field is the stable API contract; `label` is display text.

Off-topic input (if voice is added later) is redirected: "That's an interesting thought! But right now, let's focus on your math. Which of these would help you?" — then re-present structured options.

## "Never Give The Answer" Enforcement

Enforced at two levels:

1. **Prompt-level:** Every system prompt explicitly instructs Claude never to reveal the assigned answer
2. **Example generator:** Produces problems with deliberately different numbers/structure

For MVP, prompt-level enforcement is sufficient. Production could add output validation as a safety net.

## Image Handling

### Upload constraints
- **Accepted formats:** JPEG (preferred), HEIC, PNG
- **Maximum upload size:** 10 MB
- **Resizing:** Server-side. iPad sends full-resolution photos; backend handles all preprocessing.

### Preprocessing: printed textbook pages
- Resize to max 1568px longest side
- Light contrast enhancement

### Preprocessing: handwritten pencil work (critical path)
- Convert to grayscale
- Apply adaptive histogram equalization (CLAHE) for pencil-on-paper contrast
- Light sharpening
- Resize to max 1568px longest side
- Must be tested with REAL pencil-on-paper photos

## Multi-Part Assignment Handling (MVP)

For MVP, all sub-parts (3a, 3b, 3c, etc.) are treated as flat, independent items. No dependency tracking between sub-parts. This simplifies the page parser output and assignment picker.

Dependency-aware ordering (e.g., "use your answer from 3a to solve 3b") is deferred to a future phase.

## Network & Discovery

- FastAPI binds to `0.0.0.0`
- iPad discovers backend via Bonjour/mDNS (zero-config for kids)
- Python: `zeroconf` package for service registration
- iOS: `NWBrowser` for service discovery
- Fallback: manual IP entry in a parent/teacher settings screen

## Implementation Phases

### Phase 1: Backend — Page Parsing + Work Analysis

1. FastAPI project with all routers and services stubbed
2. Write all system prompts (most critical deliverable)
3. `page_parser.py` — photograph real Danish textbook pages, verify JSON output
4. `work_analyzer.py` — photograph real pencil-on-paper work, verify analysis
5. `example_generator.py` — verify different problems with clear methodology
6. `feedback_generator.py` — verify warm tone, method focus, never reveals answers
7. Wire up routers with request/response schemas
8. Test full flow end-to-end

### Phase 2: iOS App (MVP)

1. Home screen with "Scan din side" button
2. Page scan flow with VisionKit
3. Assignment picker with colored cards and Kvante suggestion
4. Working view with structured prompt buttons
5. Work scan and feedback display
6. Bonjour discovery
7. Danish-first UI with localization support

### Phase 3: Polish & Expand (future)

- Voice input (Whisper STT → intent classification)
- Progress tracking and accuracy trends
- Teacher/parent dashboard (web UI)
- Multi-student profiles
- Difficulty adaptation
- More math topics (geometry, fractions, word problems)
- Offline mode with submission queuing
- Local open-source models to eliminate external API calls

## Key Technical Notes

- **Claude model:** `claude-sonnet-4-20250514` for all vision and text tasks
- **Response time:** Claude calls ~2–5s; page parsing ~5–8s. Always show friendly loading animations.
- **Cost:** Negligible at demo scale. Log token usage per call.
- **CORS:** Configure FastAPI middleware for iOS app requests.
- **Error handling:** If Claude can't read a photo, tell the student honestly: "I'm having trouble reading your writing — can you try taking a clearer photo?"
- **Language:** Danish default, English switchable. All student-facing text localizable. Textbook language is auto-detected during page scan. Detected language is used as default for feedback; overridable via `language` parameter on feedback endpoints.
- **CORS origin:** `*` for MVP (local network only). Tighten for production.
- **iOS timeouts:** 30-second timeout for Claude API calls. No automatic retry. Show a "Try again" button on timeout.

## System Prompts

The prompts are the heart of Kvante. They define the pedagogical approach.

### `parse_page.txt`
- Examine textbook page photo
- Identify every assignment/exercise
- Extract text/numbers, classify type, estimate difficulty
- Suggest pedagogically sound order (easiest first as warm-up)
- Handle Danish and English textbooks
- Ignore non-assignment content (illustrations, page numbers)
- Return structured JSON

### `generate_example.txt`
- Create a DIFFERENT problem of similar difficulty
- Solve step-by-step with methodology explanations
- Use DIFFERENT numbers (make this obvious)
- Simple language for ages 9–13
- Include "why we do it this way" for each step

### `analyze_work.txt`
- Read handwritten numbers and operations
- Trace step-by-step methodology
- Distinguish error types: understanding, procedural, careless
- Note what was done correctly
- Assess handwriting clarity
- Output structured JSON
- If photo unclear, say so honestly

### `give_feedback.txt`
- Simple, encouraging language for ages 9–13
- ALWAYS start with something positive
- Explain errors through methodology, not "that's wrong"
- NEVER reveal the correct answer (cardinal rule)
- 3–4 sentences max
- Tone: warm, patient, like a favorite tutor

### `explain_method.txt`
- Re-explain using a DIFFERENT approach
- If first explanation was abstract, make it concrete (and vice versa)
- Never give the answer
- 2–3 sentences, then ask if that helps
