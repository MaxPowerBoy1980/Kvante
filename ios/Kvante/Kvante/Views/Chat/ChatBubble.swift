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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.3, green: 0.3, blue: 0.5), Color(red: 0.2, green: 0.2, blue: 0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(.white)
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
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isKvante
                    ? Color(red: 0.18, green: 0.18, blue: 0.22)
                    : Color(red: 0.35, green: 0.3, blue: 0.65),
                in: RoundedRectangle(cornerRadius: 20)
            )
    }

    // MARK: - Assignment Intro

    private func assignmentIntroBubble(_ assignment: ParsedAssignment) -> some View {
        VStack(spacing: 6) {
            Text(assignment.text)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Text("Opgave \(assignment.localId)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                ForEach(0..<min(assignment.difficultyEstimate, 5), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.3, green: 0.25, blue: 0.55), Color(red: 0.2, green: 0.2, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
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
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Color(red: 0.18, green: 0.18, blue: 0.22), in: RoundedRectangle(cornerRadius: 20))
    }

    private func toneStyle(_ tone: String) -> (String, Color) {
        switch tone {
        case "celebratory": return ("star.fill", .green)
        case "encouraging": return ("hand.thumbsup.fill", .orange)
        case "supportive": return ("heart.fill", .blue)
        default: return ("message.fill", .blue)
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
        let color: Color = result.isCorrect ? .green : .orange

        return VStack(alignment: .leading, spacing: 10) {
            // Result card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Læste: **\(result.studentAnswer)**")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text("via \(result.source)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(result.isCorrect ? .green : .red)
                    Text("Svar: **\(result.correctAnswer)**")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                if !result.ocrDebug.isEmpty {
                    Text(result.ocrDebug)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6).opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

            // Feedback message
            HStack(spacing: 8) {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(color)
                Text(result.message)
                    .font(.body)
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(Color(red: 0.18, green: 0.18, blue: 0.22), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Example (inline, expandable)

    private func exampleBubble(_ example: ExampleResponse) -> some View {
        InlineExampleView(example: example)
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
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.18, green: 0.18, blue: 0.22), in: RoundedRectangle(cornerRadius: 20))
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
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.purple.opacity(0.7))
                    .frame(width: 7, height: 7)
                    .offset(y: sin(phase + Double(i) * 0.8) * 4)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
