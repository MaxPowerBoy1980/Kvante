# Startskærm UX-sprint (B1-B3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three home screen UX issues: remove header welcome text (B1), update triumph/empty card content (B2/B3), update progress chip colors, and conditionally hide header dots.

**Architecture:** Pure SwiftUI view changes across two files (NewHomeView, KvanteHeaderBar) plus a minor color token addition in KvanteTheme. No backend changes. No new files.

**Tech Stack:** SwiftUI, iOS 26.2

**Spec:** `docs/superpowers/specs/2026-04-12-startskærm-ux-sprint-design.md`

---

### Task 1: Add triumph gradient endpoint color

**Files:**
- Modify: `ios/Kvante/Kvante/Theme/KvanteTheme.swift:75`

The spec requires the triumph card gradient to end at `#FFE8D6` (warmer than current `backgroundWarm` = `#FFF7ED`) for sufficient contrast against the page background.

- [ ] **Step 1: Add color token**

In `KvanteTheme.swift`, after line 75 (`backgroundWarm`), add:

```swift
static let triumphGradientEnd = Color(hex: "FFE8D6") // Warmer endpoint for triumph card
```

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Kvante/Theme/KvanteTheme.swift
git commit -m "feat(theme): add triumphGradientEnd color token"
```

---

### Task 2: Update progress chip colors to solid robBlue

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift:407-434`

The spec says done chips should have solid `robBlue` background with white ✓ (currently light opacity fill with colored ✓).

- [ ] **Step 1: Update chipFill for done state**

In `NewHomeView.swift`, replace the `chipFill` method (lines 407-411):

```swift
private func chipFill(isDone: Bool, isCurrent: Bool) -> Color {
    if isDone { return KvanteTheme.Colors.robBlue }
    if isCurrent { return KvanteTheme.Colors.primary.opacity(0.1) }
    return KvanteTheme.Colors.ink.opacity(0.03)
}
```

- [ ] **Step 2: Update chipBorder for done state**

Replace the `chipBorder` method (lines 413-417):

```swift
private func chipBorder(isDone: Bool, isCurrent: Bool) -> Color {
    if isDone { return KvanteTheme.Colors.robBlue }
    if isCurrent { return KvanteTheme.Colors.primary.opacity(0.4) }
    return KvanteTheme.Colors.ink.opacity(0.12)
}
```

- [ ] **Step 3: Update chipLabel for done state — white checkmark**

In the `chipLabel` method (lines 419-434), change the done branch:

```swift
@ViewBuilder
private func chipLabel(index: Int, isDone: Bool, isCurrent: Bool) -> some View {
    if isDone {
        Text("✓")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
    } else if isCurrent {
        Text("\(index + 1)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(KvanteTheme.Colors.primary)
    } else {
        Text("\(index + 1)")
            .font(.system(size: 11))
            .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.3))
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(home): solid robBlue chips with white checkmark for done state"
```

---

### Task 3: Remove KvanteHeaderBar welcome text + conditional home dots

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Components/KvanteHeaderBar.swift:7-10,54-80,106-180`
- Modify: `ios/Kvante/Kvante/ContentView.swift:52-58`

The spec says:
- B1: No "Klar til matematik?" in expanded header — remove entire welcome block
- Header dots: show in tilstand 1+2, hide in tilstand 3

- [ ] **Step 1: Add `showHomeDots` parameter to KvanteHeaderBar**

In `KvanteHeaderBar.swift`, add a new parameter after `homeExpression` (line 10):

```swift
struct KvanteHeaderBar: View {
    var session: SessionViewModel?
    var onNavigateHome: (() -> Void)? = nil
    var homeExpression: KvanteExpression = .neutral
    var showHomeDots: Bool = true
```

- [ ] **Step 2: Conditionally show placeholder dots in collapsed bar**

In the `collapsedBar` (lines 72-80), change the `else` branch:

```swift
} else if showHomeDots {
    ProgressDotsView(
        total: 6,
        completedIds: [],
        currentIndex: -1,
        assignmentIds: [],
        celebratingIndex: nil
    )
}
```

This hides the placeholder dots in tilstand 3 while keeping them in tilstand 1+2.

- [ ] **Step 3: Remove welcome text from expanded panel**

Replace the `else` block in `expandedPanel` (lines 155-168) with an empty group:

```swift
} else {
    // No session — no welcome text (B1: welcome lives in mainCard)
    EmptyView()
}
```

- [ ] **Step 4: Pass `showHomeDots` from ContentView**

In `ContentView.swift`, update the KvanteHeaderBar call (around lines 52-58) to add `showHomeDots`:

```swift
KvanteHeaderBar(
    session: activeSession,
    onNavigateHome: sessionPath.isEmpty ? nil : {
        sessionPath.removeAll()
    },
    homeExpression: sessionPath.isEmpty ? homeExpression : .neutral,
    showHomeDots: sessionPath.isEmpty ? sessionHistory.contains(where: { $0.mode == "weekly" }) : true
)
```

Logic: on home screen, show dots only if there's at least one weekly session (tilstand 1 or 2). In a session, always show dots (they come from `session` anyway).

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Components/KvanteHeaderBar.swift ios/Kvante/Kvante/ContentView.swift
git commit -m "feat(header): remove welcome text, hide dots in tilstand 3 (B1)"
```

---

### Task 4: Update triumfCard gradient + "Se hvad du har lavet" link

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift:60-67,214-228`

- [ ] **Step 1: Update triumph card gradient endpoint**

In `triumfCard` (line 218), change `KvanteTheme.Colors.backgroundWarm` to the new warmer token:

```swift
.fill(
    LinearGradient(
        colors: [.white, KvanteTheme.Colors.triumphGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
)
```

- [ ] **Step 2: Update "Se dit arbejde" link text**

In the body (lines 60-67), update the link text:

```swift
if activeWeekly == nil, completedWeekly != nil {
    Button(action: onNotebook) {
        Text("Se hvad du har lavet →")
            .font(.system(size: 13))
            .foregroundStyle(KvanteTheme.Colors.robBlue)
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(home): warmer triumph gradient, update 'Se hvad du har lavet' link (B2)"
```

---

### Task 5: Update emptyCard text content

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift:233-260`

The spec changes the empty state text and adjusts the title opacity.

- [ ] **Step 1: Update emptyCard content**

Replace the `emptyCard` computed property (lines 233-260):

```swift
private var emptyCard: some View {
    VStack(spacing: 12) {
        Image("rob2")
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)

        Text("Ingen nye opgaver endnu")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(KvanteTheme.Colors.textPrimary.opacity(0.5))

        Text("Der er ingen nye opgaver til dig endnu. Tjek igen snart!")
            .font(.system(size: 14))
            .foregroundStyle(KvanteTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                    .stroke(KvanteTheme.Colors.robBlue.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
            )
    )
}
```

Changes from current:
- Title opacity: `ink.opacity(0.7)` → `textPrimary.opacity(0.5)` (more dimmed, per spec)
- Body text: "Kvante venter på at din lærer..." → "Der er ingen nye opgaver til dig endnu. Tjek igen snart!"

- [ ] **Step 2: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(home): update empty state text and opacity (B3)"
```

---

### Task 6: Visual verification

- [ ] **Step 1: Build in Xcode**

Open `ios/Kvante/Kvante.xcodeproj` in Xcode. Build for iPad simulator (or device). Verify no compiler errors.

- [ ] **Step 2: Verify tilstand 1 (active weekly)**

With an active weekly session:
- Main card shows Rob neutral + "Opgave X af Y" + progress chips + "Fortsæt" button
- Done chips are solid `robBlue` with white ✓
- Exercises card visible below
- Header expanded: no welcome text, just empty
- Header collapsed: placeholder dots visible

- [ ] **Step 3: Verify tilstand 2 (triumph)**

With a completed weekly session (no active):
- Main card shows Rob happy (80×80) + ⚡ + "Uge X er i hus!" + warm gradient
- All chips solid `robBlue` with white ✓, tappable → FeedbackSheet
- "Se hvad du har lavet →" link below card in `robBlue`
- Exercises card hidden
- Header: happy expression, placeholder dots visible

- [ ] **Step 4: Verify tilstand 3 (empty)**

With no weekly sessions at all:
- Main card shows Rob neutral + "Ingen nye opgaver endnu" (dimmed) + "Tjek igen snart!"
- Dashed border in `robBlue` 25%
- No button
- Exercises card hidden
- Header collapsed: no placeholder dots
- Header expanded: no welcome text

- [ ] **Step 5: Check dobbelt-Rob**

On all tilstande, observe whether two Rob instances (header + card) feel like too much. If so, consider removing Rob from the header. This is a visual judgment call, not a hard rule.

- [ ] **Step 6: Final commit (if any visual adjustments)**

```bash
git add -A
git commit -m "fix(home): visual adjustments from manual QA"
```
