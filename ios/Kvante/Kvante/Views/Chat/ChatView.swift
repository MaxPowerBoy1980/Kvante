import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    var onBack: (() -> Void)?
    var onShowArk: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader

            if viewModel.isLoadingHistory {
                Spacer()
                ProgressView()
                    .scaleEffect(1.4)
                Spacer()
            } else {
                chatContent
            }
        }
        .background(KvanteTheme.Colors.cream)
        .toolbar(.hidden, for: .navigationBar)
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

    @ViewBuilder
    private var chatContent: some View {
        // Sticky assignment bar (ProgressPillView removed — replaced by ark)
        HStack(spacing: 8) {
            Text(viewModel.currentAssignment.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)
                .lineLimit(1)
            Spacer()
            Text("Opgave \(viewModel.currentAssignment.localId)")
                .font(.caption.weight(.medium))
                .foregroundStyle(KvanteTheme.Colors.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(KvanteTheme.Colors.cream)
        .overlay(
            Rectangle()
                .fill(KvanteTheme.Colors.inkSubtle)
                .frame(height: 1),
            alignment: .bottom
        )

        // Messages
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(
                            message: message,
                            apiClient: viewModel.apiClient,
                            onChip: { chip in
                                viewModel.handleChip(chip)
                            },
                            onConfirmAnswer: { answer in
                                viewModel.confirmAnswer(answer)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(KvanteTheme.Colors.cream)
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
            onHelp: { viewModel.requestHelp() },
            onExplainDifferent: { viewModel.requestExplainDifferent() },
            onSkip: { viewModel.advanceToNextAssignment() }
        )
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        ZStack {
            // Back button (leading)
            HStack {
                Button {
                    onBack?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tilbage")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Centered avatar + name + status
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: KvanteTheme.Shapes.avatarRadius)
                            .fill(KvanteTheme.Colors.kvanteAvatar)
                            .frame(width: 32, height: 32)
                        Text("\u{1F916}")
                            .font(.system(size: 16))
                    }
                    Text("Kvante")
                        .font(.headline)
                        .foregroundStyle(KvanteTheme.Colors.ink)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(KvanteTheme.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.success)
                }
            }

            // "Mit ark" button (trailing) — NEW
            HStack {
                Spacer()
                Button {
                    onShowArk?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Mit ark")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(
            Color.white
                .overlay(
                    Rectangle()
                        .fill(KvanteTheme.Colors.inkSubtle)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
}
