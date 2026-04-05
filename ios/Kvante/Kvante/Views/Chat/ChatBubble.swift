import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let onChip: (ActionChipModel) -> Void
    var onConfirmAnswer: ((String) -> Void)?

    private var isKvante: Bool { message.sender == .kvante }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isKvante {
                avatar
            } else {
                Spacer(minLength: 80)
            }

            VStack(alignment: isKvante ? .leading : .trailing, spacing: 10) {
                bubbleContent
                chipRow
            }

            if !isKvante {
                Spacer().frame(width: 8)
            } else {
                Spacer(minLength: 80)
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
                        colors: [.orange, .orange.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            Text("K")
                .font(.system(size: 18, weight: .bold, design: .rounded))
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
            .foregroundStyle(isKvante ? Color.primary : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isKvante
                    ? AnyShapeStyle(Color(.systemGray6))
                    : AnyShapeStyle(Color.orange),
                in: BubbleShape(isFromUser: !isKvante)
            )
    }

    // MARK: - Assignment Intro

    private func assignmentIntroBubble(_ assignment: ParsedAssignment) -> some View {
        VStack(spacing: 6) {
            Text(assignment.text)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Text("Opgave \(assignment.localId)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("·")
                    .foregroundStyle(.white.opacity(0.5))
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
                colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.6)],
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
        }
        .padding(14)
        .background(color.opacity(0.08), in: BubbleShape(isFromUser: false))
        .overlay(
            BubbleShape(isFromUser: false)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
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
        let icon = result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"

        return VStack(alignment: .leading, spacing: 10) {
            // Debug info — what OCR read vs correct
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Læste: **\(result.studentAnswer)**")
                        .font(.subheadline)
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
                }
                if !result.ocrDebug.isEmpty {
                    Text(result.ocrDebug)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))

            // Feedback message
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(result.message)
                    .font(.body)
            }
        }
        .padding(14)
        .background(color.opacity(0.08), in: BubbleShape(isFromUser: false))
        .overlay(
            BubbleShape(isFromUser: false)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
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

    // MARK: - Example

    private func exampleBubble(_ example: ExampleResponse) -> some View {
        NavigationLink {
            AnimatedExplanationView(example: example)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(example.exampleProblem)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(example.steps.count) trin — tryk for at se")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    Text("Mit svar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: BubbleShape(isFromUser: false))
    }

    // MARK: - Chips

    @ViewBuilder
    private var chipRow: some View {
        if !message.actions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(message.actions) { chip in
                        ActionChip(model: chip) { onChip(chip) }
                    }
                }
            }
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let smallR: CGFloat = 4
        return RoundedRectangle(cornerRadius: r)
            .path(in: rect)
    }
}

// MARK: - Typing Dots Animation

struct TypingDots: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.orange)
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
