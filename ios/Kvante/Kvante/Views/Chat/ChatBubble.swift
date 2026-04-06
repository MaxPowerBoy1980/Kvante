import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let onChip: (ActionChipModel) -> Void
    var onConfirmAnswer: ((String) -> Void)?

    private var isKvante: Bool { message.sender == .kvante }

    var body: some View {
        VStack(alignment: isKvante ? .leading : .trailing, spacing: 6) {
            // Sender label
            if isKvante {
                Text("KVANTE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    .padding(.leading, 52)
            }

            HStack(alignment: .top, spacing: 10) {
                if isKvante {
                    avatar
                } else {
                    Spacer(minLength: 60)
                }

                bubbleContent

                if !isKvante {
                    Spacer().frame(width: 4)
                } else {
                    Spacer(minLength: 60)
                }
            }

            // Sender label for student
            if !isKvante, case .text = message.content {
                Text("DIG")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    .padding(.trailing, 8)
            }

            // Action chips
            if !message.actions.isEmpty {
                chipRow
                    .padding(.leading, isKvante ? 52 : 0)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(KvanteTheme.Colors.kvanteAvatar)
                .frame(width: 36, height: 36)
            Text("🤖")
                .font(.system(size: 18))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.content {
        case .text(let text):
            textBubble(text)
        case .assignmentIntro(let assignment):
            assignmentIntroBubble(assignment)
        case .feedback(let feedback):
            feedbackBubble(feedback)
        case .ocrConfirm(let confirmation):
            ocrConfirmBubble(confirmation)
        case .answerResult(let result):
            answerResultBubble(result)
        case .example(let example):
            exampleBubble(example)
        case .exampleStep(let step, let num, let total, let gridState):
            exampleStepBubble(step, stepNumber: num, total: total, gridState: gridState)
        case .tip(let text):
            tipBubble(text)
        case .scannedImage(let data):
            scannedImageBubble(data)
        case .loading(let text):
            loadingBubble(text)
        }
    }

    // MARK: - Text Bubble

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

    // MARK: - Assignment Intro

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

    // MARK: - Feedback

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

    private func toneStyle(_ tone: String) -> (String, Color) {
        switch tone {
        case "celebratory": return ("checkmark.circle.fill", KvanteTheme.Colors.success)
        case "encouraging": return ("hand.thumbsup.fill", KvanteTheme.Colors.primary)
        case "supportive": return ("heart.fill", KvanteTheme.Colors.teal)
        default: return ("message.fill", KvanteTheme.Colors.teal)
        }
    }

    private func toneLabel(_ tone: String) -> String {
        switch tone {
        case "celebratory": return "Flot klaret!"
        case "encouraging": return "Godt forsøg!"
        case "supportive": return "Bliv ved!"
        default: return ""
        }
    }

    // MARK: - OCR Confirmation

    private func ocrConfirmBubble(_ confirmation: OcrConfirmation) -> some View {
        OcrConfirmView(
            readText: confirmation.readText,
            source: confirmation.source,
            onConfirm: { answer in
                onConfirmAnswer?(answer)
            }
        )
    }

    // MARK: - Answer Result

    private func answerResultBubble(_ result: AnswerResult) -> some View {
        let color: Color = result.isCorrect ? KvanteTheme.Colors.success : KvanteTheme.Colors.wrong

        return VStack(alignment: .leading, spacing: 10) {
            // Result card
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

            // Feedback message
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

    // MARK: - Example (legacy, kept for compatibility)

    private func exampleBubble(_ example: ExampleResponse) -> some View {
        InlineExampleView(example: example)
    }

    // MARK: - Example Step (one step per message)

    private func exampleStepBubble(_ step: AnimationStep, stepNumber: Int, total: Int, gridState: GridState? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Step header
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

            // Step text
            Text(step.text)
                .font(.body)
                .foregroundStyle(KvanteTheme.Colors.textPrimary)

            // Visual component
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

    // MARK: - Tip

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

    // MARK: - Scanned Image

    private func scannedImageBubble(_ data: Data) -> some View {
        Group {
            if let uiImage = UIImage(data: data) {
                VStack(alignment: .trailing, spacing: 4) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Loading

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

    // MARK: - Chips

    @ViewBuilder
    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(message.actions) { chip in
                    ActionChip(model: chip) { onChip(chip) }
                }
            }
        }
    }
}

// MARK: - Typing Dots Animation

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
