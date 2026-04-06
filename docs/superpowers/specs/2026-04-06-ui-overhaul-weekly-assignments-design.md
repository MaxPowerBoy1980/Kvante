# Kvante UI Overhaul & Weekly Assignment Feature — Design Spec

**Date:** 2026-04-06
**Status:** Approved
**Approach:** Phase A — Visual first, structure second

## Overview

Transform Kvante from a functional dark-themed developer-feeling app into a warm, inviting, Toca Boca-inspired math helper that kids (9-13) want to open. Add weekly assignment sets ("ugematematik") as the primary use case alongside free practice ("øvelser").

### Scope

1. Visual identity overhaul (palette, typography, shape language)
2. Conversational onboarding
3. Warm, personal home screen
4. Continuous chat per assignment set (replaces per-assignment chat)
5. Student-facing assignment set dashboard with images and feedback
6. Tiered celebration system
7. Backend data model for assignment sets and image storage

### Out of Scope (Future)

- Teacher dashboard (web-based, separate project — data model is teacher-ready)
- Long multiplication / new math type visuals
- Geometry tasks
- Custom illustrated Kvante mascot (use 🤖 for now)
- Custom illustrated student avatars (use emoji/SF Symbols for now)

---

## Phase 1: Visual Identity & Onboarding

### Design System

**Color palette:**

| Role | Color | Hex |
|------|-------|-----|
| Background | Warm cream gradient | `#faf6f0` → `#fff8ee` |
| Primary action / student bubbles | Warm orange | `#e85d26` |
| Button pressed shadow | Dark orange | `#c44a1a` |
| Kvante bubbles | White with warm border | `#ffffff`, border `#f0ebe3` |
| Success / completion | Warm green | `#4caf50` → `#2aa68a` |
| Pending / muted | Warm beige | `#f0ebe3`, text `#c4b89e` |
| Primary text | Dark brown-black | `#3d2c1e` |
| Secondary text | Warm brown | `#8b7355` |
| Tips/hints background | Warm yellow | `#fff9f0` |
| Tips/hints border | Golden | `#fde4b8` |
| Tip label text | Dark gold | `#92610a` |
| Øvelser button | Teal | `#2aa68a` |
| Øvelser button shadow | Dark teal | `#1e8a6f` |

**Typography:**
- System font with `.rounded` design throughout
- Bold weights for headings and assignment text
- "Marker Felt" preserved for stacked arithmetic numbers (handwritten feel)
- No pure black text — use `#3d2c1e` everywhere

**Shape language:**
- Border radius: 16-20pt everywhere — no sharp corners
- Buttons: 4pt bottom shadow creating tactile 3D "pressable" effect (Toca Boca style)
- Subtle organic circular background decorations (low opacity)
- Cards: white/near-white with subtle warm border and light shadow

**Avatars:**
- **Kvante:** 🤖 robot emoji (32pt in chat, 56pt on home/onboarding). Placeholder for future custom illustration.
- **Student:** Chosen during onboarding from curated set of 8-10 options. Mix of animals (cat, owl, bear, rabbit, frog) and abstract geometric characters with faces. Displayed at 56pt on home screen, 32pt where needed elsewhere.

### Onboarding Flow

Conversational chat-style onboarding. The entire flow happens inside a chat view using the same visual language as the rest of the app.

**Steps:**

1. App opens → warm cream background → 🤖 avatar appears with bubble: *"Hej! Jeg er Kvante. Jeg hjælper med matematik. Hvad hedder du?"*
2. Student types name in the chat input bar → Kvante responds: *"Hej Lyng! Hvilken klasse går du i?"*
3. Grade selection appears as tappable pills in chat (3. klasse, 4. klasse, 5. klasse, 6. klasse)
4. Student picks → Kvante responds: *"Fedt! Vælg et billede der ligner dig:"*
5. Avatar grid appears in chat (8-10 mixed animals + abstract characters)
6. Student picks → Kvante responds: *"Perfekt! Så er vi klar."* → Transition to home screen

**Details:**
- Each step animates in as a new chat bubble (same timing as real chat)
- No "next" buttons or separate screen transitions
- Name input uses the same input bar as the rest of the app
- Total time: ~30-60 seconds
- Data saved: name, grade, avatar choice (same fields as today)

---

## Phase 2: Continuous Chat & Assignment Sets

### Home Screen

Simple, personal, two clear paths.

**Layout:**
- Student's avatar (56pt) + **"Hej [name]!"** greeting, left-aligned
- Contextual subtitle: *"Klar til matematik?"* or *"Du har 2 opgaver tilbage"* if mid-set
- Two large tactile buttons (side-by-side):
  - **Ugematematik** (orange `#e85d26`) — enter/resume current weekly set
  - **Øvelser** (teal `#2aa68a`) — enter practice flow (topic → difficulty → session)
- Active assignment set: ugematematik button shows small green progress indicator (e.g. "3/6")
- Weekly progress bar (warm green) below buttons
- Below: history of recent completed sets (simple list, most recent first, tappable to review)

**Behavior:**
- **Ugematematik**: resumes current set's chat, or starts new one if none exists
- **Øvelser**: goes to topic picker (restyled to match new palette)

### Continuous Chat Architecture

One chat per assignment set. Replaces the current per-assignment chat model.

**Flow:**
1. Student enters an assignment set → single chat opens
2. Kvante introduces first assignment as a message: *"Opgave 1: Regn ud 347 + 286"*
3. All interaction in chat — help, examples, scanning answers, feedback
4. Assignment solved → green completion card in chat → Kvante introduces next: *"Godt klaret! Opgave 2: Regn ud 812 − 457"*
5. Student can also skip via + menu
6. Full conversation scrolls naturally — previous assignments visible on scroll-up

**Progress pill (top of chat):**
- Thin bar: "Opgave 3 af 6" + tappable
- Tap → drawer slides down with numbered tiles:
  - Green = completed
  - Orange = current
  - Gray = pending
- Tap completed tile → scrolls to that assignment's position in chat
- Tap pending tile → jumps ahead (Kvante introduces it)
- Tap outside → dismiss drawer

**+ context menu (input bar):**
- Input bar layout: **+** button (left) + text field + send button (right)
- Camera (📷) shortcut directly on input bar (most frequent action)
- Tap **+** → menu slides up above input bar:
  - 📷 **Scan mit svar** — opens camera
  - 💡 **Vis eksempel** — requests worked example
  - 🔄 **Forklar anderledes** — re-explain differently
  - ⏭️ **Spring over** — skip to next assignment
- Menu dismisses after selection or tap outside

**Chat message persistence:**
- Messages are persisted to database so resuming a set restores the full conversation
- Each message linked to its assignment within the set
- Scanned images stored and linked to their assignment

### Celebrations & Delight

Tiered system — celebration matches the moment.

**Tier 1 — Routine correct answer:**
- Green completion card slides in with spring bounce animation (~0.5s)
- Shows: ✓ checkmark, "Rigtigt!", brief method acknowledgment (*"Du brugte opstilling — god metode"*)
- Warm green gradient background

**Tier 2 — Correct after struggle (2+ attempts):**
- Same green card with subtle glow/pulse effect
- More encouraging text: *"Du blev ved — og det lykkedes!"*
- Card lingers slightly longer before "Næste opgave" appears

**Tier 3 — Completing full assignment set:**
- Confetti particle burst (~1.5s)
- Larger celebration card: *"Du klarede hele ugematematikken!"*
- All numbered tiles shown in green
- "Tilbage til forsiden" button

**Wrong answer:**
- No red/failure feel. Warm orange card: *"Ikke helt — prøv igen?"*
- Shows OCR reading for confirmation
- + menu remains available for help

**Stacked arithmetic animations:**
- Keep existing step-by-step column animation (proven, working)
- Restyle to match new palette (teal highlights → warm orange/green accents)

---

## Phase 3: Ugematematik

### Assignment Set Concept

A named, ordered collection of assignments that a student works through in one continuous chat.

**Types:**
- **Ugematematik** — weekly mixed assignments, served from backend library. In future: teacher-created or auto-generated.
- **Øvelser** — practice sets, student-selected topic + difficulty (existing flow, restyled).

### Backend Data Model Changes

**New: AssignmentSet**
- `id` (UUID, PK)
- `student_id` (FK → Student)
- `name` (e.g. "Ugematematik — uge 14")
- `type` ("ugematematik" | "øvelser")
- `topic` (nullable — null for mixed sets)
- `difficulty` (nullable)
- `status` ("active" | "completed")
- `created_at`, `completed_at`

**Modified: Assignment**
- `assignment_set_id` (FK → AssignmentSet, replaces session_id)
- `position` (integer, ordering within set)
- Add: `scanned_image_path` (student's handwritten answer photo)
- Add: `feedback_summary` (one-line summary for dashboard)
- Add: `completed_at` (timestamp)

**New: ChatMessage**
- `id` (UUID, PK)
- `assignment_set_id` (FK → AssignmentSet)
- `assignment_id` (FK → Assignment, nullable — some messages are set-level)
- `sender` ("kvante" | "student")
- `content_type` (text, assignment_intro, feedback, example_step, scanned_image, tip, completion, etc.)
- `content` (JSON — flexible per content_type)
- `created_at`

**Modified: Submission**
- Link to assignment_set_id instead of session_id
- `scanned_image_path` preserved (original photo stored on disk)

### Student Dashboard

Accessible from home screen by tapping a completed assignment set.

**View:**
- Header: set name + date + completion status ("Ugematematik — uge 14 ✓")
- List of assignments, each showing:
  - Assignment number + text (e.g. "Opgave 1: 347 + 286")
  - Status: green checkmark or orange "skipped"
  - Thumbnail of scanned handwritten answer
  - Number of attempts
  - Kvante's feedback summary (one line)
- Tap assignment to expand: full-size scanned image, complete feedback, method notes

**Data stored per solved assignment (teacher-ready):**
- Assignment text + correct answer
- Student's answer (OCR result)
- Scanned image (original photo on disk)
- Attempt count
- Full feedback text
- Timestamp

### Ugematematik Entry Point

For now, ugematematik sets are served from the backend library:
- Backend endpoint creates a mixed-topic set appropriate for the student's grade
- Includes addition, subtraction (and later: multiplication, division, etc.)
- 5-8 assignments per set

Future: teachers create/assign sets via web dashboard.

---

## Implementation Phasing

### Phase 1: Visual Identity & Onboarding
- Define color constants and shape styles as a SwiftUI theme
- Restyle all existing views to new palette
- Replace onboarding with chat-style flow
- Restyle home screen (two buttons, avatar greeting)
- Restyle topic picker and difficulty picker for øvelser

### Phase 2: Continuous Chat & Assignment Sets
- Backend: create AssignmentSet and ChatMessage models, migrate Session → AssignmentSet
- Backend: chat message persistence endpoints
- iOS: refactor ChatViewModel to manage full assignment set conversation
- iOS: progress pill + drawer overlay
- iOS: + context menu replacing action chips
- iOS: tiered celebration animations (bounce, glow, confetti)
- iOS: chat message persistence and resume

### Phase 3: Ugematematik
- Backend: endpoint to generate mixed weekly assignment sets by grade
- iOS: ugematematik button opens/resumes current weekly set
- iOS: student dashboard view for completed sets
- iOS: home screen history list of completed sets
- Backend: store scanned images linked to assignments
- Backend: feedback summary field on assignments
