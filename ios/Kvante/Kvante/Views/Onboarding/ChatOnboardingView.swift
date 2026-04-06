import SwiftUI
import SwiftData

// MARK: - Message Model

struct OnboardingMessage: Identifiable {
    let id = UUID()
    let text: String
    let isKvante: Bool
    var content: OnboardingContent = .text

    enum OnboardingContent: Equatable {
        case text
        case gradePicker
        case avatarPicker
    }
}

// MARK: - ChatOnboardingView

struct ChatOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    let apiClient: APIClient?
    let onComplete: () -> Void

    @State private var messages: [OnboardingMessage] = []
    @State private var nameInput = ""
    @State private var showInput = false
    @State private var selectedName = ""
    @State private var selectedGrade = 4
    @State private var selectedAvatar = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            KvanteTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(messages) { msg in
                                messageRow(msg)
                                    .id(msg.id)
                                    .transition(
                                        .move(edge: .bottom).combined(with: .opacity)
                                    )
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.bottom, showInput ? 80 : 20)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation(.spring(duration: 0.4)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Input bar — only during name entry
            if showInput {
                inputBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { startConversation() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.kvanteAvatar)
                    .frame(width: 40, height: 40)
                Text("🤖")
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Kvante")
                    .font(KvanteTheme.Fonts.clean(17, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
                Text("Din matematik-hjælper")
                    .font(KvanteTheme.Fonts.clean(13))
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(KvanteTheme.Colors.backgroundStart.opacity(0.95))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.2)
        }
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ msg: OnboardingMessage) -> some View {
        if msg.isKvante {
            kvanteBubbleRow(msg)
        } else {
            studentBubbleRow(msg)
        }
    }

    private func kvanteBubbleRow(_ msg: OnboardingMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(KvanteTheme.Colors.kvanteAvatar)
                    .frame(width: 36, height: 36)
                Text("🤖")
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 8) {
                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.body)
                        .foregroundStyle(KvanteTheme.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            KvanteTheme.Colors.kvanteBubble,
                            in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                                .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1)
                        )
                }

                switch msg.content {
                case .gradePicker:
                    gradePills
                case .avatarPicker:
                    avatarGrid
                case .text:
                    EmptyView()
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
    }

    private func studentBubbleRow(_ msg: OnboardingMessage) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(msg.text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    KvanteTheme.Colors.studentBubble,
                    in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.bubbleRadius)
                )
            Spacer().frame(width: 4)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Grade Pills

    private var gradePills: some View {
        HStack(spacing: 10) {
            ForEach(3...6, id: \.self) { grade in
                Button {
                    handleGradeSelected(grade)
                } label: {
                    Text("\(grade). klasse")
                        .font(KvanteTheme.Fonts.buttonLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                }
                .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
            }
        }
    }

    // MARK: - Avatar Grid

    private var avatarGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
            spacing: 10
        ) {
            ForEach(KvanteTheme.studentAvatars, id: \.name) { avatar in
                Button {
                    handleAvatarSelected(avatar)
                } label: {
                    Text(avatar.emoji)
                        .font(.system(size: 28))
                        .frame(width: 52, height: 52)
                        .background(
                            KvanteTheme.Colors.kvanteBubble,
                            in: RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.smallRadius)
                                .stroke(KvanteTheme.Colors.kvanteBubbleBorder, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 310)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2)
            HStack(spacing: 10) {
                TextField("Skriv dit navn...", text: $nameInput)
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textPrimary)
                    .submitLabel(.send)
                    .focused($inputFocused)
                    .onSubmit {
                        if !nameInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            submitName()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(KvanteTheme.Colors.muted, in: Capsule())

                Button {
                    if !nameInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        submitName()
                    }
                } label: {
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
    }

    // MARK: - Conversation Flow

    private func startConversation() {
        // First bubble after slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            addKvanteBubble("Hej! Jeg er Kvante 🤖\nJeg hjælper med matematik.")
        }
        // Second bubble
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            addKvanteBubble("Hvad hedder du?")
            withAnimation(.spring(duration: 0.4)) {
                showInput = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                inputFocused = true
            }
        }
    }

    private func submitName() {
        let name = nameInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        selectedName = name
        nameInput = ""

        withAnimation(.spring(duration: 0.4)) {
            showInput = false
        }
        inputFocused = false

        // Student bubble
        addStudentBubble(name)

        // Kvante responds after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            addKvanteBubble("Hej \(name)! Hvilken klasse går du i?", content: .gradePicker)
        }
    }

    private func handleGradeSelected(_ grade: Int) {
        selectedGrade = grade
        // Remove the grade picker bubble and lock in choice
        disableLastPicker()

        addStudentBubble("\(grade). klasse")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            addKvanteBubble("Fedt! Vælg et billede der ligner dig:", content: .avatarPicker)
        }
    }

    private func handleAvatarSelected(_ avatar: (emoji: String, name: String)) {
        selectedAvatar = avatar.emoji
        disableLastPicker()

        addStudentBubble(avatar.emoji)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            addKvanteBubble("Perfekt! Så er vi klar 🤖")
            register(name: selectedName, grade: selectedGrade, avatar: avatar.emoji)
        }
    }

    /// Replace the last picker message with a plain text version (no interactive content)
    private func disableLastPicker() {
        if let idx = messages.indices.last(where: { messages[$0].content != .text }) {
            var updated = messages[idx]
            let newMsg = OnboardingMessage(text: updated.text, isKvante: updated.isKvante, content: .text)
            withAnimation(.spring(duration: 0.3)) {
                messages[idx] = newMsg
            }
        }
    }

    private func addKvanteBubble(_ text: String, content: OnboardingMessage.OnboardingContent = .text) {
        let msg = OnboardingMessage(text: text, isKvante: true, content: content)
        withAnimation(.spring(duration: 0.4)) {
            messages.append(msg)
        }
    }

    private func addStudentBubble(_ text: String) {
        let msg = OnboardingMessage(text: text, isKvante: false)
        withAnimation(.spring(duration: 0.4)) {
            messages.append(msg)
        }
    }

    // MARK: - Registration

    private func register(name: String, grade: Int, avatar: String) {
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
            try? await Task.sleep(for: .seconds(1.0))
            onComplete()
        }
    }
}
