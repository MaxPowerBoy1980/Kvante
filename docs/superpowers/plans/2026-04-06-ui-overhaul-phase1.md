# Phase 1: Visual Identity & Onboarding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Kvante from a dark developer-themed app into a warm, Toca Boca-inspired math helper with a conversational onboarding flow.

**Architecture:** Create a centralized `KvanteTheme` with all colors, fonts, and shape constants. Replace all hardcoded styling across every view. Replace the 3-screen onboarding with a chat-style conversational flow. Restyle home screen with avatar greeting and two action buttons.

**Tech Stack:** SwiftUI, SwiftData, iOS 26.2

**Spec:** `docs/superpowers/specs/2026-04-06-ui-overhaul-weekly-assignments-design.md`

---

### File Structure

**Create:**
- `ios/Kvante/Kvante/Theme/KvanteTheme.swift` — All color, font, and shape constants
- `ios/Kvante/Kvante/Views/Onboarding/ChatOnboardingView.swift` — Conversational onboarding

**Modify:**
- `ios/Kvante/Kvante/Models/StudentProfile.swift` — Avatar stores emoji string instead of SF Symbol
- `ios/Kvante/Kvante/ContentView.swift` — Use new onboarding, update home screen wiring
- `ios/Kvante/Kvante/Views/NewHomeView.swift` — Complete restyle: avatar greeting, two buttons, warm palette
- `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift` — Replace all hardcoded colors with theme
- `ios/Kvante/Kvante/Views/Chat/ChatInputBar.swift` — Replace colors with theme
- `ios/Kvante/Kvante/Views/Chat/ChatView.swift` — Background color, navigation title styling
- `ios/Kvante/Kvante/Views/Chat/ActionChip.swift` — Replace colors with theme
- `ios/Kvante/Kvante/Views/Chat/OcrConfirmView.swift` — Replace colors with theme
- `ios/Kvante/Kvante/Views/Practice/TopicPickerView.swift` — Use theme colors for topic cards
- `ios/Kvante/Kvante/Views/Practice/DifficultyPickerView.swift` — Use theme colors
- `ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift` — Progress bar and completion view

**Delete:**
- `ios/Kvante/Kvante/Views/Onboarding/OnboardingView.swift` — Replaced by ChatOnboardingView

---

### Task 1: Create KvanteTheme Design System

**Files:**
- Create: `ios/Kvante/Kvante/Theme/KvanteTheme.swift`

- [ ] **Step 1: Create the Theme directory**

Run: `mkdir -p ios/Kvante/Kvante/Theme`

- [ ] **Step 2: Create KvanteTheme.swift with all design tokens**

Create `ios/Kvante/Kvante/Theme/KvanteTheme.swift`:

```swift
import SwiftUI

enum KvanteTheme {
    // MARK: - Colors

    enum Colors {
        // Background
        static let backgroundStart = Color(hex: "faf6f0")
        static let backgroundEnd = Color(hex: "fff8ee")
        static var background: LinearGradient {
            LinearGradient(
                colors: [backgroundStart, backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        // Primary action / student bubbles
        static let primary = Color(hex: "e85d26")
        static let primaryShadow = Color(hex: "c44a1a")

        // Kvante bubbles
        static let kvanteBubble = Color.white
        static let kvanteBubbleBorder = Color(hex: "f0ebe3")

        // Student bubbles
        static let studentBubble = Color(hex: "e85d26")

        // Success / completion
        static let success = Color(hex: "4caf50")
        static let successSecondary = Color(hex: "2aa68a")
        static var successGradient: LinearGradient {
            LinearGradient(
                colors: [success, successSecondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        // Øvelser button
        static let teal = Color(hex: "2aa68a")
        static let tealShadow = Color(hex: "1e8a6f")

        // Pending / muted
        static let muted = Color(hex: "f0ebe3")
        static let mutedText = Color(hex: "c4b89e")

        // Text
        static let textPrimary = Color(hex: "3d2c1e")
        static let textSecondary = Color(hex: "8b7355")

        // Tips
        static let tipBackground = Color(hex: "fff9f0")
        static let tipBorder = Color(hex: "fde4b8")
        static let tipLabel = Color(hex: "92610a")

        // Kvante avatar background
        static let kvanteAvatar = Color(hex: "e85d26")

        // Input bar
        static let inputBackground = Color(hex: "f0ebe3")
        static let sendActive = Color(hex: "e85d26")
        static let sendInactive = Color(hex: "c4b89e")

        // Wrong answer (warm, not red)
        static let wrong = Color(hex: "e85d26")

        // Assignment intro
        static let assignmentBackground = Color(hex: "e85d26")
    }

    // MARK: - Fonts

    enum Fonts {
        static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static let greeting = Font.system(size: 28, weight: .bold, design: .rounded)
        static let assignmentText = Font.system(size: 28, weight: .bold, design: .rounded)
        static let buttonLabel = Font.system(size: 15, weight: .bold, design: .rounded)
        static let body = Font.body
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.bold)
        static let subtitle = Font.subheadline
    }

    // MARK: - Shapes

    enum Shapes {
        static let bubbleRadius: CGFloat = 20
        static let cardRadius: CGFloat = 18
        static let buttonRadius: CGFloat = 20
        static let inputRadius: CGFloat = 20
        static let smallRadius: CGFloat = 14
        static let buttonShadowOffset: CGFloat = 4
    }

    // MARK: - Avatars

    static let studentAvatars: [(emoji: String, name: String)] = [
        ("🐱", "Kat"),
        ("🦉", "Ugle"),
        ("🐻", "Bjørn"),
        ("🐰", "Kanin"),
        ("🐸", "Frø"),
        ("🦊", "Ræv"),
        ("🔵", "Blå"),
        ("🟣", "Lilla"),
        ("🟠", "Orange"),
        ("🔶", "Diamant"),
    ]
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
```

- [ ] **Step 3: Add file to Xcode project and build**

Open `ios/Kvante/Kvante.xcodeproj` in Xcode. Add `Theme/KvanteTheme.swift` to the Kvante target. Or if using folder references, just build:

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Theme/KvanteTheme.swift
git commit -m "feat: add KvanteTheme design system with all color, font, and shape tokens"
```

---

### Task 2: Restyle ChatBubble

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatBubble.swift`

- [ ] **Step 1: Replace avatar with themed 🤖**

Replace the `avatar` computed property (lines 55-69):

```swift
private var avatar: some View {
    ZStack {
        Circle()
            .fill(KvanteTheme.Colors.kvanteAvatar)
            .frame(width: 36, height: 36)
        Text("🤖")
            .font(.system(size: 18))
    }
}
```

- [ ] **Step 2: Replace text bubble colors**

Replace `textBubble` method (lines 101-113):

```swift
private func textBubble(_ text: String) -> some View {
    Text(text)
        .font(.body)
        .foregroundStyle(isKvante ? KvanteTheme.Colors.textPrimary : .white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isKvante ? KvanteTheme.Colors.kvanteBubble : KvanteTheme.Colors.studentBubble,
            in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
        )
        .overlay(
            isKvante
                ? RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                    .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
                : nil
        )
}
```

- [ ] **Step 3: Replace assignment intro bubble colors**

Replace `assignmentIntroBubble` method (lines 117-144):

```swift
private func assignmentIntroBubble(_ assignment: ParsedAssignment) -> some View {
    VStack(spacing: 6) {
        Text(assignment.text)
            .font(KvanteTheme.Fonts.assignmentText)
            .foregroundStyle(.white)
        HStack(spacing: 4) {
            Text("Opgave \(assignment.localId)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .padding(.horizontal, 16)
    .background(
        KvanteTheme.Colors.assignmentBackground,
        in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
    )
}
```

Note: Difficulty stars removed from assignment intro per spec (no stars).

- [ ] **Step 4: Replace feedback bubble colors**

Replace `feedbackBubble` method (lines 148-165):

```swift
private func feedbackBubble(_ feedback: FeedbackResponse) -> some View {
    let (icon, color) = toneStyle(feedback.tone)
    return VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            Text(toneLabel(feedback.tone))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        Text(feedback.feedbackText)
            .font(.body)
            .foregroundStyle(KvanteTheme.Colors.textPrimary)
    }
    .padding(14)
    .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius))
    .overlay(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
            .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
    )
}
```

Update `toneStyle` to use theme colors:

```swift
private func toneStyle(_ tone: String) -> (String, Color) {
    switch tone {
    case "celebratory": return ("checkmark.circle.fill", KvanteTheme.Colors.success)
    case "encouraging": return ("hand.thumbsup.fill", KvanteTheme.Colors.primary)
    case "supportive": return ("heart.fill", KvanteTheme.Colors.teal)
    default: return ("message.fill", KvanteTheme.Colors.teal)
    }
}
```

- [ ] **Step 5: Replace answer result bubble colors**

Replace `answerResultBubble` method (lines 199-246):

```swift
private func answerResultBubble(_ result: AnswerResult) -> some View {
    let color: Color = result.isCorrect ? KvanteTheme.Colors.success : KvanteTheme.Colors.wrong

    return VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "text.viewfinder")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                Text("Læste: **\(result.studentAnswer)**")
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
                Text("via \(result.source)")
                    .font(.caption2)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
            }
            HStack(spacing: 6) {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(color)
                Text("Svar: **\(result.correctAnswer)**")
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
            }
            if !result.ocrDebug.isEmpty {
                Text(result.ocrDebug)
                    .font(.caption2)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KvanteTheme.Colors.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

        HStack(spacing: 8) {
            Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(color)
            Text(result.message)
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.textPrimary)
        }
    }
    .padding(14)
    .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius))
    .overlay(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
            .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
    )
}
```

- [ ] **Step 6: Replace example step bubble colors**

Replace `exampleStepBubble` method (lines 256-293):

```swift
private func exampleStepBubble(_ step: AnimationStep, stepNumber: Int, total: Int, gridState: GridState? = nil) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
            Text("\(stepNumber)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(KvanteTheme.Colors.primary, in: Circle())
            Text("Trin \(stepNumber) af \(total)")
                .font(.caption)
                .foregroundStyle(KvanteTheme.Colors.primary)
        }

        Text(step.text)
            .font(.body)
            .foregroundStyle(KvanteTheme.Colors.textPrimary)

        VisualComponentView(
            visual: step.visual,
            animate: true,
            cumulativeObjects: 0,
            cumulativeCrossedOut: 0,
            cumulativeRows: 2,
            cumulativeGrouped: 0,
            cumulativeGridState: gridState
        )
        .frame(maxWidth: .infinity)
    }
    .padding(14)
    .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius))
    .overlay(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
            .stroke(KvanteTheme.Colors.primary.opacity(0.2), lineWidth: 1)
    )
}
```

- [ ] **Step 7: Replace tip bubble colors**

Replace `tipBubble` method (lines 297-322):

```swift
private func tipBubble(_ text: String) -> some View {
    HStack(spacing: 10) {
        ZStack {
            Circle()
                .fill(KvanteTheme.Colors.tipBackground)
                .frame(width: 32, height: 32)
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(KvanteTheme.Colors.tipLabel)
        }
        VStack(alignment: .leading, spacing: 2) {
            Text("Kvantes Tip")
                .font(.caption.weight(.bold))
                .foregroundStyle(KvanteTheme.Colors.tipLabel)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(KvanteTheme.Colors.textPrimary)
        }
    }
    .padding(12)
    .background(KvanteTheme.Colors.tipBackground, in: RoundedRectangle(cornerRadius: 16))
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(KvanteTheme.Colors.tipBorder, lineWidth: 1.5)
    )
}
```

- [ ] **Step 8: Replace loading bubble colors**

Replace `loadingBubble` method (lines 342-353):

```swift
private func loadingBubble(_ text: String) -> some View {
    HStack(spacing: 10) {
        TypingDots()
        Text(text)
            .font(.subheadline)
            .foregroundStyle(KvanteTheme.Colors.textSecondary)
            .italic()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius))
    .overlay(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
            .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
    )
}
```

Update `TypingDots` to use theme color:

```swift
struct TypingDots: View {
    @State private var active = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(KvanteTheme.Colors.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(active == i ? 1.4 : 0.7)
                    .opacity(active == i ? 1.0 : 0.3)
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                active = (active + 1) % 3
            }
        }
    }
}
```

- [ ] **Step 9: Replace sender label colors**

Update the "KVANTE" and "DIG" labels (lines 14-17 and 37-42) to use theme:

```swift
// Kvante label (line 15-16):
.foregroundStyle(KvanteTheme.Colors.textSecondary)

// Student label (line 39-40):
.foregroundStyle(KvanteTheme.Colors.textSecondary)
```

- [ ] **Step 10: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 11: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/ChatBubble.swift
git commit -m "feat: restyle ChatBubble with warm KvanteTheme palette"
```

---

### Task 3: Restyle ChatInputBar, ActionChip, OcrConfirmView

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatInputBar.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/ActionChip.swift`
- Modify: `ios/Kvante/Kvante/Views/Chat/OcrConfirmView.swift`

- [ ] **Step 1: Restyle ChatInputBar**

Replace the full body of `ChatInputBar` (lines 9-71):

```swift
var body: some View {
    VStack(spacing: 0) {
        Divider().opacity(0.15)

        HStack(spacing: 10) {
            // + menu button
            Menu {
                Button {
                    onCamera()
                } label: {
                    Label("Scan mit svar", systemImage: "camera.fill")
                }
                Button {
                    onHelp()
                } label: {
                    Label("Hjælp mig med opgaven", systemImage: "lightbulb.fill")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(KvanteTheme.Colors.primary)
            }

            // Text field
            HStack(spacing: 8) {
                TextField("Skriv til Kvante...", text: $text)
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
                    .submitLabel(.send)
                    .onSubmit { if !text.trimmingCharacters(in: .whitespaces).isEmpty { onSend() } }

                Button(action: onCamera) {
                    Image(systemName: "camera.fill")
                        .font(.body)
                        .foregroundStyle(KvanteTheme.Colors.mutedText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(KvanteTheme.Colors.muted, in: Capsule())

            // Send button
            Button {
                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    onSend()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespaces).isEmpty
                            ? KvanteTheme.Colors.sendInactive
                            : KvanteTheme.Colors.sendActive
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(KvanteTheme.Colors.backgroundStart.opacity(0.95))
    }
}
```

- [ ] **Step 2: Restyle ActionChip**

Replace the full body of `ActionChip` (lines 7-27):

```swift
var body: some View {
    Button(action: action) {
        Text(model.label)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                model.isPrimary
                    ? AnyShapeStyle(KvanteTheme.Colors.primary)
                    : AnyShapeStyle(KvanteTheme.Colors.muted)
            )
            .foregroundStyle(model.isPrimary ? .white : KvanteTheme.Colors.textPrimary)
            .clipShape(Capsule())
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 3: Restyle OcrConfirmView**

Replace the full body of `OcrConfirmView` (lines 11-120):

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 16) {
        // Header
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.kvanteAvatar)
                    .frame(width: 36, height: 36)
                Text("🤖")
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Jeg har scannet dit billede!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
                Text("Er det her rigtigt?")
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
            }
        }

        // Reading card
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DIT SVAR")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(KvanteTheme.Colors.success)

                if isEditing {
                    HStack {
                        TextField("Skriv dit svar", text: $correctedText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(KvanteTheme.Colors.textPrimary)
                        Button {
                            let answer = correctedText.trimmingCharacters(in: .whitespaces)
                            if !answer.isEmpty { onConfirm(answer) }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(KvanteTheme.Colors.success)
                        }
                        .disabled(correctedText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    HStack {
                        Text(readText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(KvanteTheme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(KvanteTheme.Colors.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius))
        }

        // Buttons
        if !isEditing {
            VStack(spacing: 10) {
                Button {
                    onConfirm(readText)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.body)
                        Text("Ja, det er rigtigt")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KvanteTheme.Colors.success, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    correctedText = readText
                    isEditing = true
                } label: {
                    Text("Nej, lad mig rette")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KvanteTheme.Colors.muted, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius))
                        .foregroundStyle(KvanteTheme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }

        // Source
        Text(source)
            .font(.caption2)
            .foregroundStyle(KvanteTheme.Colors.textSecondary)
    }
    .padding(16)
    .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: 22))
    .overlay(
        RoundedRectangle(cornerRadius: 22)
            .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
    )
}
```

- [ ] **Step 4: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/ChatInputBar.swift ios/Kvante/Kvante/Views/Chat/ActionChip.swift ios/Kvante/Kvante/Views/Chat/OcrConfirmView.swift
git commit -m "feat: restyle ChatInputBar, ActionChip, and OcrConfirmView with warm theme"
```

---

### Task 4: Restyle ChatView Background

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Chat/ChatView.swift`

- [ ] **Step 1: Add warm background to ChatView**

Replace the body of `ChatView` (lines 6-54):

```swift
var body: some View {
    VStack(spacing: 0) {
        // Messages
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message, onChip: { chip in
                            viewModel.handleChip(chip)
                        }, onConfirmAnswer: { answer in
                            viewModel.confirmAnswer(answer)
                        })
                        .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(KvanteTheme.Colors.backgroundStart)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }

        // Input bar
        ChatInputBar(
            text: $viewModel.inputText,
            onSend: { viewModel.sendMessage() },
            onCamera: { viewModel.showScanner = true },
            onHelp: { viewModel.requestHelp() }
        )
    }
    .background(KvanteTheme.Colors.backgroundStart)
    .navigationTitle("Kvante")
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(isPresented: $viewModel.showScanner) {
        DocumentScannerView(
            onScan: { imageData in
                viewModel.showScanner = false
                viewModel.scanAnswer(imageData)
            },
            onCancel: {
                viewModel.showScanner = false
            }
        )
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/Chat/ChatView.swift
git commit -m "feat: warm cream background for ChatView"
```

---

### Task 5: Restyle Practice Flow

**Files:**
- Modify: `ios/Kvante/Kvante/Views/Practice/PracticeSessionView.swift`
- Modify: `ios/Kvante/Kvante/Views/Practice/TopicPickerView.swift`
- Modify: `ios/Kvante/Kvante/Views/Practice/DifficultyPickerView.swift`

- [ ] **Step 1: Restyle PracticeSessionView progress bar and completion**

Replace `progressBar` (lines 39-68):

```swift
private var progressBar: some View {
    VStack(spacing: 4) {
        HStack {
            Text("Opgave \(currentIndex + 1) af \(assignments.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
            Spacer()
            Text("\(completedCount) løst")
                .font(.caption.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.success)
        }
        .padding(.horizontal, 20)

        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(KvanteTheme.Colors.muted)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 5)
                    .fill(KvanteTheme.Colors.successGradient)
                    .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(assignments.count, 1)), height: 8)
                    .animation(.easeInOut, value: currentIndex)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 20)
    }
    .padding(.vertical, 8)
    .background(KvanteTheme.Colors.backgroundStart.opacity(0.95))
}
```

Replace `completionView` (lines 72-88):

```swift
private var completionView: some View {
    VStack(spacing: 24) {
        Spacer()

        ZStack {
            Circle()
                .fill(KvanteTheme.Colors.success.opacity(0.15))
                .frame(width: 100, height: 100)
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(KvanteTheme.Colors.success)
        }

        Text("Flot klaret!")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(KvanteTheme.Colors.textPrimary)

        Text("Du har gennemført alle \(assignments.count) opgaver")
            .font(.title3)
            .foregroundStyle(KvanteTheme.Colors.textSecondary)

        Spacer()
    }
    .frame(maxWidth: .infinity)
    .background(KvanteTheme.Colors.backgroundStart)
}
```

- [ ] **Step 2: Restyle TopicPickerView**

Replace `topicColors` dictionary (lines 11-21) with warm theme colors:

```swift
private let topicColors: [String: Color] = [
    "addition": KvanteTheme.Colors.primary,
    "subtraktion": Color(hex: "e74c3c"),
    "multiplikation": Color(hex: "3498db"),
    "division": Color(hex: "6c5ce7"),
    "broeker": Color(hex: "9b59b6"),
    "decimaltal": KvanteTheme.Colors.teal,
    "geometri": KvanteTheme.Colors.success,
    "ligninger": Color(hex: "e84393"),
    "procent": Color(hex: "f39c12"),
]
```

Replace `TopicCard` body (lines 73-94) to use warm styling:

```swift
var body: some View {
    VStack(spacing: 10) {
        Image(systemName: topic.icon)
            .font(.system(size: 32))
            .foregroundStyle(color)

        Text(topic.name)
            .font(.headline)
            .foregroundStyle(KvanteTheme.Colors.textPrimary)

        Text("\(topic.problemCount) opgaver")
            .font(.caption)
            .foregroundStyle(KvanteTheme.Colors.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius))
    .overlay(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
            .stroke(color.opacity(0.2), lineWidth: 1)
    )
}
```

Add `.background(KvanteTheme.Colors.backgroundStart)` to the ScrollView in `TopicPickerView`.

- [ ] **Step 3: Restyle DifficultyPickerView**

Replace the difficulty card button label (lines 30-58):

```swift
Button { onSelect(info.level) } label: {
    HStack(spacing: 14) {
        Text(info.emoji)
            .font(.title)

        VStack(alignment: .leading, spacing: 2) {
            Text(info.label)
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.textPrimary)
            Text(info.description)
                .font(.subheadline)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
        }

        Spacer()

        if available {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(KvanteTheme.Colors.textSecondary)
        } else {
            Text("Ingen opgaver")
                .font(.caption2)
                .foregroundStyle(KvanteTheme.Colors.mutedText)
        }
    }
    .padding(16)
    .background(KvanteTheme.Colors.kvanteBubble, in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius))
    .overlay(
        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
            .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
    )
    .opacity(available ? 1 : 0.4)
}
```

Update the topic icon color (line 20): `.foregroundStyle(KvanteTheme.Colors.primary)`.

Add `.background(KvanteTheme.Colors.backgroundStart)` to the outer VStack.

- [ ] **Step 4: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ios/Kvante/Kvante/Views/Practice/
git commit -m "feat: restyle practice flow with warm theme — progress bar, topic cards, difficulty picker"
```

---

### Task 6: Restyle Home Screen

**Files:**
- Modify: `ios/Kvante/Kvante/Views/NewHomeView.swift`

- [ ] **Step 1: Rewrite NewHomeView**

Replace the entire content of `NewHomeView.swift`:

```swift
import SwiftUI
import SwiftData

struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void

    var body: some View {
        ZStack {
            // Warm background
            KvanteTheme.Colors.background
                .ignoresSafeArea()

            // Subtle decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(KvanteTheme.Colors.tipBorder.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .offset(x: geo.size.width - 60, y: -30)
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.15))
                    .frame(width: 90, height: 90)
                    .offset(x: -30, y: geo.size.height - 200)
            }

            VStack(spacing: 0) {
                // Header with avatar + greeting
                HStack(spacing: 14) {
                    // Student avatar
                    Text(profile.avatarName)
                        .font(.system(size: 44))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hej \(profile.name)!")
                            .font(KvanteTheme.Fonts.greeting)
                            .foregroundStyle(KvanteTheme.Colors.textPrimary)
                        if serverDiscovery.serverURL == nil {
                            Text(serverDiscovery.isSearching
                                ? "Leder efter serveren..."
                                : "Ingen server fundet")
                                .font(.caption)
                                .foregroundStyle(KvanteTheme.Colors.mutedText)
                        } else {
                            Text("Klar til matematik?")
                                .font(.subheadline)
                                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Two main action buttons
                HStack(spacing: 14) {
                    // Ugematematik button
                    Button(action: {}) {
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 24))
                            Text("Ugematematik")
                                .font(KvanteTheme.Fonts.buttonLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.buttonRadius)
                                .fill(KvanteTheme.Colors.primary)
                                .shadow(color: KvanteTheme.Colors.primaryShadow, radius: 0, y: KvanteTheme.Shapes.buttonShadowOffset)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.5)

                    // Øvelser button
                    Button(action: onPractice) {
                        VStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 24))
                            Text("Øvelser")
                                .font(KvanteTheme.Fonts.buttonLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.buttonRadius)
                                .fill(KvanteTheme.Colors.teal)
                                .shadow(color: KvanteTheme.Colors.tealShadow, radius: 0, y: KvanteTheme.Shapes.buttonShadowOffset)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(serverDiscovery.serverURL == nil)
                    .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
```

Note: Ugematematik button is disabled for now (Phase 3 will enable it). The `ModeCard` struct is no longer needed and can be removed from this file.

- [ ] **Step 2: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ios/Kvante/Kvante/Views/NewHomeView.swift
git commit -m "feat: warm Toca Boca-inspired home screen with avatar greeting and two action buttons"
```

---

### Task 7: Update StudentProfile for Emoji Avatars

**Files:**
- Modify: `ios/Kvante/Kvante/Models/StudentProfile.swift`

- [ ] **Step 1: Change default avatar from SF Symbol to emoji**

Replace the default value in `StudentProfile` init:

The `avatarName` field already stores a string. The only change: wherever we reference it as an SF Symbol (`Image(systemName: profile.avatarName)`), we need to switch to `Text(profile.avatarName)`. The `avatarName` field will now store emoji strings like "🐱" instead of SF Symbol names like "person.crop.circle.fill".

No model migration needed — SwiftData handles string fields. New users get emoji avatars from the new onboarding. Existing profiles keep their SF Symbol string but will display incorrectly; since this is a dev-only concern (no production users yet), this is acceptable.

- [ ] **Step 2: Commit**

No file changes needed for the model itself — the avatar format change is handled by the new onboarding (Task 8). This task is a no-op.

---

### Task 8: Conversational Onboarding

**Files:**
- Create: `ios/Kvante/Kvante/Views/Onboarding/ChatOnboardingView.swift`
- Modify: `ios/Kvante/Kvante/ContentView.swift`

- [ ] **Step 1: Create ChatOnboardingView**

Create `ios/Kvante/Kvante/Views/Onboarding/ChatOnboardingView.swift`:

```swift
import SwiftUI
import SwiftData

struct ChatOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let apiClient: APIClient?
    let onComplete: () -> Void

    // State
    @State private var messages: [OnboardingMessage] = []
    @State private var currentStep: OnboardingStep = .greeting
    @State private var nameInput = ""
    @State private var selectedName = ""
    @State private var selectedGrade = 4
    @State private var isRegistering = false

    enum OnboardingStep {
        case greeting
        case waitingForName
        case askGrade
        case askAvatar
        case done
    }

    struct OnboardingMessage: Identifiable {
        let id = UUID()
        let text: String
        let isKvante: Bool
        var content: OnboardingContent = .text

        enum OnboardingContent {
            case text
            case gradePicker
            case avatarPicker
        }
    }

    var body: some View {
        ZStack {
            KvanteTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                onboardingBubble(message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar (only during name step)
                if currentStep == .waitingForName {
                    nameInputBar
                }
            }
        }
        .onAppear { startConversation() }
    }

    // MARK: - Conversation Flow

    private func startConversation() {
        addKvanteMessage("Hej! Jeg er Kvante 🤖\nJeg hjælper med matematik.", delay: 0.5) {
            addKvanteMessage("Hvad hedder du?", delay: 0.8) {
                currentStep = .waitingForName
            }
        }
    }

    private func submitName() {
        let name = nameInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        selectedName = name
        addStudentMessage(name)
        nameInput = ""
        currentStep = .askGrade

        addKvanteMessage("Hej \(name)! Hvilken klasse går du i?", delay: 0.8) {
            withAnimation(.spring(duration: 0.4)) {
                messages.append(OnboardingMessage(
                    text: "",
                    isKvante: true,
                    content: .gradePicker
                ))
            }
        }
    }

    private func selectGrade(_ grade: Int) {
        selectedGrade = grade
        addStudentMessage("\(grade). klasse")

        // Remove picker
        messages.removeAll { $0.content == .gradePicker }

        currentStep = .askAvatar
        addKvanteMessage("Fedt! Vælg et billede der ligner dig:", delay: 0.8) {
            withAnimation(.spring(duration: 0.4)) {
                messages.append(OnboardingMessage(
                    text: "",
                    isKvante: true,
                    content: .avatarPicker
                ))
            }
        }
    }

    private func selectAvatar(_ emoji: String) {
        addStudentMessage(emoji)

        // Remove picker
        messages.removeAll { $0.content == .avatarPicker }

        currentStep = .done
        addKvanteMessage("Perfekt! Så er vi klar 🤖", delay: 0.6) {
            register(name: selectedName, grade: selectedGrade, avatar: emoji)
        }
    }

    // MARK: - Message Helpers

    private func addKvanteMessage(_ text: String, delay: Double, then: @escaping () -> Void = {}) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(duration: 0.4)) {
                messages.append(OnboardingMessage(text: text, isKvante: true))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                then()
            }
        }
    }

    private func addStudentMessage(_ text: String) {
        withAnimation(.spring(duration: 0.4)) {
            messages.append(OnboardingMessage(text: text, isKvante: false))
        }
    }

    // MARK: - Bubble Views

    @ViewBuilder
    private func onboardingBubble(_ message: OnboardingMessage) -> some View {
        switch message.content {
        case .text:
            HStack(alignment: .top, spacing: 10) {
                if message.isKvante {
                    kvanteAvatar
                } else {
                    Spacer(minLength: 60)
                }

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.isKvante ? KvanteTheme.Colors.textPrimary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isKvante ? KvanteTheme.Colors.kvanteBubble : KvanteTheme.Colors.studentBubble,
                        in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                    )
                    .overlay(
                        message.isKvante
                            ? RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                                .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
                            : nil
                    )

                if message.isKvante {
                    Spacer(minLength: 60)
                }
            }

        case .gradePicker:
            HStack(alignment: .top, spacing: 10) {
                Spacer().frame(width: 46) // align with bubbles
                HStack(spacing: 10) {
                    ForEach(3...6, id: \.self) { grade in
                        Button {
                            selectGrade(grade)
                        } label: {
                            Text("\(grade).")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                        .fill(KvanteTheme.Colors.primary)
                                        .shadow(color: KvanteTheme.Colors.primaryShadow, radius: 0, y: 3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }

        case .avatarPicker:
            HStack(alignment: .top, spacing: 10) {
                Spacer().frame(width: 46)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(KvanteTheme.studentAvatars, id: \.emoji) { avatar in
                        Button {
                            selectAvatar(avatar.emoji)
                        } label: {
                            Text(avatar.emoji)
                                .font(.system(size: 32))
                                .frame(width: 56, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                        .fill(KvanteTheme.Colors.kvanteBubble)
                                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                        .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 340)
                Spacer()
            }
        }
    }

    private var kvanteAvatar: some View {
        ZStack {
            Circle()
                .fill(KvanteTheme.Colors.kvanteAvatar)
                .frame(width: 36, height: 36)
            Text("🤖")
                .font(.system(size: 18))
        }
    }

    // MARK: - Name Input Bar

    private var nameInputBar: some View {
        HStack(spacing: 10) {
            TextField("Dit navn...", text: $nameInput)
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(KvanteTheme.Colors.muted, in: Capsule())
                .submitLabel(.send)
                .onSubmit { submitName() }

            Button(action: submitName) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                            ? KvanteTheme.Colors.sendInactive
                            : KvanteTheme.Colors.sendActive
                    )
            }
            .buttonStyle(.plain)
            .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(KvanteTheme.Colors.backgroundStart.opacity(0.95))
    }

    // MARK: - Registration

    private func register(name: String, grade: Int, avatar: String) {
        isRegistering = true
        let profile = StudentProfile(
            name: name,
            avatarName: avatar,
            gradeLevel: grade
        )

        Task {
            if let client = apiClient {
                if let response = try? await client.registerStudent(
                    name: profile.name, gradeLevel: profile.gradeLevel
                ) {
                    profile.backendStudentId = response.studentId
                }
            }

            modelContext.insert(profile)
            try? modelContext.save()
            isRegistering = false

            // Brief pause before transitioning
            try? await Task.sleep(for: .seconds(1.0))
            onComplete()
        }
    }
}

// Make OnboardingContent equatable for removeAll
extension ChatOnboardingView.OnboardingMessage.OnboardingContent: Equatable {}
```

- [ ] **Step 2: Update ContentView to use ChatOnboardingView**

In `ContentView.swift`, change line 30 from:

```swift
OnboardingView(apiClient: apiClient) {}
```

to:

```swift
ChatOnboardingView(apiClient: apiClient) {}
```

- [ ] **Step 3: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ios/Kvante/Kvante/Views/Onboarding/ChatOnboardingView.swift ios/Kvante/Kvante/ContentView.swift
git commit -m "feat: conversational chat-style onboarding with emoji avatars"
```

---

### Task 9: Delete Old OnboardingView and Clean Up

**Files:**
- Delete: `ios/Kvante/Kvante/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Verify no other references to OnboardingView**

Search for any remaining references:

Run: `grep -r "OnboardingView" ios/Kvante/Kvante/ --include="*.swift"`

Expected: Only hits in `ChatOnboardingView.swift` (if any) and no remaining `OnboardingView` references.

- [ ] **Step 2: Delete old file**

Run: `rm ios/Kvante/Kvante/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 3: Build and verify**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git rm ios/Kvante/Kvante/Views/Onboarding/OnboardingView.swift
git commit -m "chore: remove old OnboardingView, replaced by ChatOnboardingView"
```

---

### Task 10: Final Visual Polish Pass

**Files:**
- Modify: `ios/Kvante/Kvante/ContentView.swift` (background)
- Modify: `ios/Kvante/Kvante/Views/LoadingView.swift` (if it exists, restyle)

- [ ] **Step 1: Add warm background to ContentView**

In `ContentView.swift`, wrap the `Group` in a ZStack with the background:

```swift
var body: some View {
    NavigationStack {
        ZStack {
            KvanteTheme.Colors.background.ignoresSafeArea()

            Group {
                // ... existing content unchanged
            }
        }
    }
    // ... rest unchanged
}
```

- [ ] **Step 2: Restyle LoadingView**

Check if LoadingView exists and update its colors to use theme. Replace `.orange` or `.purple` with `KvanteTheme.Colors.primary` and set background to `KvanteTheme.Colors.backgroundStart`.

- [ ] **Step 3: Build and run on simulator**

Run: `cd ios/Kvante && xcodebuild -scheme Kvante -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Visual verification**

Launch the app on iPad Simulator. Walk through:
1. Fresh install → conversational onboarding (delete app data first)
2. Home screen with avatar and two buttons
3. Øvelser → topic picker → difficulty → chat
4. Chat with warm cream background, white Kvante bubbles, orange student bubbles
5. Tips with golden border
6. OCR confirm with warm colors

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: complete Phase 1 visual polish — warm backgrounds everywhere"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | KvanteTheme design system | Create `Theme/KvanteTheme.swift` |
| 2 | Restyle ChatBubble | Modify `ChatBubble.swift` |
| 3 | Restyle ChatInputBar, ActionChip, OcrConfirmView | Modify 3 chat component files |
| 4 | Restyle ChatView background | Modify `ChatView.swift` |
| 5 | Restyle practice flow | Modify `PracticeSessionView`, `TopicPickerView`, `DifficultyPickerView` |
| 6 | Restyle home screen | Rewrite `NewHomeView.swift` |
| 7 | Update StudentProfile for emoji avatars | No-op — handled by new onboarding |
| 8 | Conversational onboarding | Create `ChatOnboardingView.swift`, modify `ContentView` |
| 9 | Delete old OnboardingView | Delete `OnboardingView.swift` |
| 10 | Final visual polish | Backgrounds, LoadingView, visual verification |
