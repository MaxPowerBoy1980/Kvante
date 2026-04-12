# Startskærm UX-sprint (B1-B3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace generic home screen with three contextual states: mid-week, triumph, and empty — removing double welcome, fixing completed-as-active bug, and defining empty state.

**Architecture:** Pure iOS change. NewHomeView gets a three-state main card driven by `activeWeekly`/`completedWeekly` computed properties filtered on `mode == "weekly"`. FeedbackSheet reused from ark for chip-tap navigation. No backend changes.

**Tech Stack:** SwiftUI, existing SessionViewModel, existing FeedbackSheet, KvanteTheme color tokens

**Spec:** `docs/superpowers/specs/2026-04-12-home-screen-ux-sprint-design.md`

---

### Task 1: Add color tokens to KvanteTheme

**Files:**
- Modify: `ios/Kvante/Kvante/Theme/KvanteTheme.swift:68-71`

- [ ] **Step 1: Add `robBlue` and `backgroundWarm` tokens**

In `KvanteTheme.swift`, add two new color tokens after the existing Kvante character colors (after line 71):

```swift
        // Rob pixelart-derived colors
        static let robBlue = Color(hex: "5B9EB5")       // Rob's head — used for done-chips
        static let backgroundWarm = Color(hex: "FFF7ED") // Warm cream for triumph card gradient
```

- [ ] **Step 2: Build to verify no compile errors**

Run: `xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Theme/KvanteTheme.swift
git commit -m "feat(ios): add robBlue and backgroundWarm color tokens"
```

---

### Task 2: Rewrite NewHomeView with three-state main card

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift` (full rewrite of card section)

This is the main task. Replace the welcome heading + single weekly card with a three-state contextual card.

- [ ] **Step 1: Replace `currentWeekly` with `activeWeekly` and `completedWeekly`**

In `NewHomeView.swift`, replace the `currentWeekly` computed property (lines 33-36) with:

```swift
    /// First incomplete weekly session — drives tilstand 1
    private var activeWeekly: SessionSummary? {
        sessionHistory.first { $0.mode == "weekly" && !$0.isCompleted }
    }

    /// Most recent completed weekly session — drives tilstand 2
    private var completedWeekly: SessionSummary? {
        sessionHistory.first { $0.mode == "weekly" && $0.isCompleted }
    }

    /// Show exercises card only in tilstand 1 (active weekly, not yet solved)
    private var showExercises: Bool {
        activeWeekly != nil
    }
```

- [ ] **Step 2: Replace body with three-state layout**

Replace the entire `body` computed property (lines 38-90) with:

```swift
    var body: some View {
        ZStack {
            KvanteTheme.Colors.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    mainCard

                    // "Se dit arbejde" link — only in tilstand 2 (triumf)
                    if activeWeekly == nil, completedWeekly != nil {
                        Button(action: onNotebook) {
                            Text("Se dit arbejde denne uge →")
                                .font(.system(size: 13))
                                .foregroundStyle(KvanteTheme.Colors.robBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    if showExercises {
                        practiceCard
                    }

                    notebookCard

                    // Server status
                    if serverDiscovery.serverURL == nil {
                        Text(serverDiscovery.isSearching
                            ? "Leder efter serveren..."
                            : "Ingen server fundet")
                            .font(.caption)
                            .foregroundStyle(KvanteTheme.Colors.textMuted)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
    }
```

- [ ] **Step 3: Add `mainCard` three-state ViewBuilder**

Add this computed property after `body`:

```swift
    // MARK: - Main Card (three states)

    @ViewBuilder
    private var mainCard: some View {
        if let active = activeWeekly {
            activeWeeklyCard(active)
        } else if let completed = completedWeekly {
            triumfCard(completed)
        } else {
            emptyCard
        }
    }
```

- [ ] **Step 4: Add `activeWeeklyCard` (tilstand 1)**

Replace the old `weeklyCard` (lines 94-148) with:

```swift
    // MARK: - Tilstand 1: Midt i ugen

    private func activeWeeklyCard(_ weekly: SessionSummary) -> some View {
        VStack(spacing: 14) {
            Image("rob2")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text("Opgave \(weekly.completedCount + 1) af \(weekly.assignmentCount)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("\(weekly.name)")
                .font(.system(size: 13))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            // Progress chips
            progressChips(
                total: weekly.assignmentCount,
                completed: weekly.completedCount,
                sessionId: weekly.sessionId
            )

            Button(action: { onTapSession(weekly) }) {
                Text("Fortsæt opgave \(weekly.completedCount + 1)")
                    .font(KvanteTheme.Fonts.buttonLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
            .disabled(serverDiscovery.serverURL == nil)
            .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
    }
```

- [ ] **Step 5: Add `triumfCard` (tilstand 2)**

```swift
    // MARK: - Tilstand 2: Alt er løst (triumf)

    private func triumfCard(_ weekly: SessionSummary) -> some View {
        VStack(spacing: 10) {
            Image("rob2_happy")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            // Lyn-zigzag (statisk i denne sprint)
            Text("⚡⚡⚡")
                .font(.system(size: 18))
                .foregroundStyle(KvanteTheme.Colors.primary)

            Text("Uge \(weekNumber(from: weekly)) er i hus!")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text("\(weekly.assignmentCount) af \(weekly.assignmentCount) opgaver — flot arbejde")
                .font(.system(size: 13))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)

            // All done chips
            progressChips(
                total: weekly.assignmentCount,
                completed: weekly.assignmentCount,
                sessionId: weekly.sessionId
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .fill(
                    LinearGradient(
                        colors: [.white, KvanteTheme.Colors.backgroundWarm],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                        .stroke(KvanteTheme.Colors.primary.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
    }
```

- [ ] **Step 6: Add `emptyCard` (tilstand 3)**

```swift
    // MARK: - Tilstand 3: Ingen aktiv uge

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image("rob2")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text("Ingen nye opgaver endnu")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.7))

            Text("Kvante venter på at din lærer lægger ugens opgaver ind. Tjek igen senere.")
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

- [ ] **Step 7: Add `progressChips` and helper**

```swift
    // MARK: - Progress Chips

    private func progressChips(total: Int, completed: Int, sessionId: String) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                let isDone = i < completed
                let isCurrent = i == completed && completed < total

                RoundedRectangle(cornerRadius: 6)
                    .fill(chipFill(isDone: isDone, isCurrent: isCurrent))
                    .frame(height: 28)
                    .frame(maxWidth: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(chipBorder(isDone: isDone, isCurrent: isCurrent),
                                    lineWidth: isCurrent ? 2 : 1.5)
                    )
                    .overlay(chipLabel(index: i, isDone: isDone, isCurrent: isCurrent))
                    .onTapGesture {
                        if isDone {
                            loadFeedbackForChip(sessionId: sessionId, chipIndex: i)
                        }
                    }
            }
        }
    }

    private func chipFill(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return KvanteTheme.Colors.robBlue.opacity(0.15) }
        if isCurrent { return KvanteTheme.Colors.primary.opacity(0.1) }
        return KvanteTheme.Colors.ink.opacity(0.03)
    }

    private func chipBorder(isDone: Bool, isCurrent: Bool) -> Color {
        if isDone { return KvanteTheme.Colors.robBlue.opacity(0.3) }
        if isCurrent { return KvanteTheme.Colors.primary.opacity(0.4) }
        return KvanteTheme.Colors.ink.opacity(0.12)
    }

    @ViewBuilder
    private func chipLabel(index: Int, isDone: Bool, isCurrent: Bool) -> some View {
        if isDone {
            Text("✓")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.robBlue)
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

    /// Extract week number from session name (e.g. "Uge 15 — Addition" → "15")
    private func weekNumber(from session: SessionSummary) -> String {
        let name = session.name
        if let range = name.range(of: #"Uge (\d+)"#, options: .regularExpression) {
            let match = name[range]
            return match.replacingOccurrences(of: "Uge ", with: "")
        }
        return name
    }
```

- [ ] **Step 8: Delete old mini-ark helpers**

Remove the old helper functions that are no longer used (lines 268-305 in the original):

- `miniArkColor(index:completed:)`
- `miniArkBorder(index:completed:)`
- `miniArkBorderWidth(index:completed:)`
- `miniArkLabel(index:completed:)`

- [ ] **Step 9: Build to verify**

Run: `xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

Note: the `loadFeedbackForChip` function is referenced but not yet implemented — it will be added in Task 3. If the build fails on this, add a temporary stub:

```swift
    private func loadFeedbackForChip(sessionId: String, chipIndex: Int) {
        // TODO: Task 3 implements this
    }
```

- [ ] **Step 10: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(ios): three-state contextual home card (B1/B2/B3)

Remove 'Hej [navn]' welcome heading — card IS the welcome.
Tilstand 1: active weekly with specific CTA.
Tilstand 2: triumph with Rob happy, no CTA, exercises hidden.
Tilstand 3: empty state with dashed border, explanatory text.
Progress chips use robBlue instead of green."
```

---

### Task 3: Add progress-chip tap → FeedbackSheet

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift` (add state + loading + sheet)

- [ ] **Step 1: Add state for FeedbackSheet presentation**

At the top of `NewHomeView`, add state properties:

```swift
    @State private var chipFeedbackSession: SessionViewModel?
    @State private var chipFeedbackItem: ArkFeedbackItem?
    @State private var isLoadingChipFeedback = false
```

- [ ] **Step 2: Implement `loadFeedbackForChip`**

Replace the stub (or add if not present) with the real implementation:

```swift
    // MARK: - Chip Tap → FeedbackSheet

    private func loadFeedbackForChip(sessionId: String, chipIndex: Int) {
        guard let serverURL = serverDiscovery.serverURL else { return }
        isLoadingChipFeedback = true
        Task {
            do {
                let client = APIClient(baseURL: serverURL)
                let response = try await client.getSession(sessionId: sessionId)
                let session = SessionViewModel(from: response)
                chipFeedbackSession = session
                let assignment = session.assignments[chipIndex]
                chipFeedbackItem = ArkFeedbackItem(
                    id: assignment.id,
                    assignment: assignment,
                    index: chipIndex
                )
            } catch {
                print("Failed to load chip feedback: \(error)")
            }
            isLoadingChipFeedback = false
        }
    }
```

- [ ] **Step 3: Add `.sheet` modifier to body**

In the `body`, add a `.sheet(item:)` modifier to the outermost `ZStack`:

```swift
        .sheet(item: $chipFeedbackItem) { item in
            if let session = chipFeedbackSession,
               let serverURL = serverDiscovery.serverURL {
                let assignmentId = item.assignment.id
                FeedbackSheet(
                    assignmentId: assignmentId,
                    assignmentText: item.assignment.text,
                    assignmentIndex: item.index,
                    status: {
                        let s = session.statusByAssignment[assignmentId] ?? .notStarted
                        switch s {
                        case .done: return "done"
                        case .inProgress: return "in_progress"
                        case .notStarted: return "not_started"
                        }
                    }(),
                    errorType: session.errorType[assignmentId],
                    studentAnswer: session.studentAnswer[assignmentId],
                    scanId: session.latestScanId[assignmentId],
                    cropRegion: session.boundingBoxByAssignment[assignmentId],
                    gearScore: session.gearScoreByAssignment[assignmentId],
                    improvementTip: session.improvementTipByAssignment[assignmentId],
                    feedbackSummary: session.feedbackSummary[assignmentId],
                    submissionId: session.submissionIdByAssignment[assignmentId],
                    isHistorical: true,
                    apiClient: APIClient(baseURL: serverURL)
                )
            }
        }
```

Note: `isHistorical: true` because these are completed assignments viewed from the home screen — no retry/example buttons.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(ios): tap completed progress chip → FeedbackSheet

Load session detail on chip tap, present FeedbackSheet as
historical view. Reuses ArkFeedbackItem and existing FeedbackSheet."
```

---

### Task 4: Update KvanteHeaderBar + ContentView

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Components/KvanteHeaderBar.swift`
- Modify: `ios/Kvante/Kvante/ContentView.swift:81-91`

- [ ] **Step 1: Add `homeExpression` parameter to KvanteHeaderBar**

In `KvanteHeaderBar.swift`, add a new property after the existing ones (around line 10):

```swift
    var homeExpression: KvanteFaceExpression = .neutral
```

Then in the collapsed bar where `KvanteFace` is rendered (around line 40), when `session` is nil, use `homeExpression` instead of hardcoded `.neutral`:

Find the line:
```swift
            KvanteFace(expression: expression)
```

This already uses the `expression` state variable. The celebration handler sets it temporarily. For the home state, modify the `.onAppear` or initial value. Find where `expression` is initialized:

```swift
    @State private var expression: KvanteFaceExpression = .neutral
```

Add an `.onChange` modifier after the existing `.onReceive` for celebration:

```swift
        .onChange(of: session?.isSetComplete) { _, isComplete in
            if session == nil {
                // On home screen — use homeExpression
                expression = homeExpression
            }
        }
        .onAppear {
            if session == nil {
                expression = homeExpression
            }
        }
```

- [ ] **Step 2: Update ContentView to pass homeExpression**

In `ContentView.swift`, update the `KvanteHeaderBar` initialization (lines 42-47).

The header needs to know whether we're in triumph state. Add a computed property:

```swift
    private var homeExpression: KvanteFaceExpression {
        let weeklySessions = sessionHistory.filter { $0.mode == "weekly" }
        let hasActive = weeklySessions.contains { !$0.isCompleted }
        let hasCompleted = weeklySessions.contains { $0.isCompleted }
        if !hasActive && hasCompleted {
            return .happy  // Tilstand 2: triumf
        }
        return .neutral  // Tilstand 1 or 3
    }
```

Then update the header:

```swift
            KvanteHeaderBar(
                session: activeSession,
                homeExpression: sessionPath.isEmpty ? homeExpression : .neutral,
                onNavigateHome: sessionPath.isEmpty ? nil : {
                    sessionPath.removeAll()
                }
            )
```

- [ ] **Step 3: Clean up unused `onWeekly` parameter**

In `NewHomeView.swift`, the `onWeekly` property is no longer called from the card. Remove it:

```swift
    // DELETE this line:
    let onWeekly: () -> Void
```

In `ContentView.swift`, remove `onWeekly` from NewHomeView initialization:

```swift
                        NewHomeView(
                            profile: p,
                            serverDiscovery: serverDiscovery,
                            onPractice: { showPractice = true },
                            onNotebook: { sessionPath = [.notebook] },
                            sessionHistory: sessionHistory,
                            onTapSession: { summary in
                                resumeSession(summary)
                            }
                        )
```

Note: `startWeeklySession()` remains in ContentView for potential future use — just not called from the home card.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Components/KvanteHeaderBar.swift \
        ios/Kvante/Kvante/ContentView.swift \
        ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat(ios): header expression matches home state, remove onWeekly

KvanteHeaderBar shows happy face in triumph state.
Remove unused onWeekly callback from NewHomeView."
```

---

### Task 5: Build and manual verification

**Files:** None (verification only)

- [ ] **Step 1: Full build**

```bash
xcodebuild -project ios/Kvante/Kvante.xcodeproj -scheme Kvante -destination 'platform=iOS Simulator,name=iPad (10th generation)' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **` with zero errors.

- [ ] **Step 2: Verify tilstand 1 (midt i uge)**

Launch app in simulator. With an active incomplete weekly session:
- Rob neutral (64×64) centered in card
- "Opgave N af M" title
- Session name as subtitle
- Progress chips: done chips in robBlue, current chip in orange, pending chips in grey
- "Fortsæt opgave N" orange CTA button
- Exercises card visible below
- Notebook card visible below
- No "Hej [navn]" heading anywhere

- [ ] **Step 3: Verify tilstand 2 (triumf)**

Complete all assignments in a session, return to home:
- Rob happy (80×80) centered in card — larger than normal
- ⚡⚡⚡ in orange below Rob
- "Uge N er i hus!" title
- "M af M opgaver — flot arbejde" subtitle
- All chips in robBlue with ✓
- NO CTA button
- "Se dit arbejde denne uge →" text link in robBlue below card
- Exercises card is HIDDEN
- Notebook card visible
- Header shows happy Rob expression

- [ ] **Step 4: Verify tilstand 3 (ingen uge)**

With no weekly sessions (or all removed):
- Rob neutral (64×64) centered in card
- Dashed border on card (robBlue 25%)
- "Ingen nye opgaver endnu" in muted text
- Explanatory text about teacher
- NO button
- Exercises card is HIDDEN
- Notebook card visible
- Header shows no progress dots, streak still visible

- [ ] **Step 5: Verify chip tap → FeedbackSheet**

In tilstand 1 or 2, tap a completed ✓ chip:
- FeedbackSheet appears as modal sheet
- Shows correct assignment data (text, scan image, gear score, feedback)
- Dismiss sheet → back on home screen (not navigated away)

- [ ] **Step 6: Note any issues**

If issues found, fix and recommit before marking complete.

---

## Edge Cases

**First-time student (zero sessions):** Tilstand 3 shows "Ingen nye opgaver endnu" with no action button. The spec explicitly says no button. If this creates a dead end for new students who need to create their first weekly session, address by auto-creating a session during onboarding or adding a secondary "Start" button — but that's a follow-up, not this sprint.

**Practice-only student:** Student with only practice sessions (no weekly) sees tilstand 3. This is correct — the weekly card shows weekly session state only.

**Multiple completed sessions:** `completedWeekly` returns the first completed weekly session from `sessionHistory` (sorted newest-first by the backend). Shows the most recent triumph.
