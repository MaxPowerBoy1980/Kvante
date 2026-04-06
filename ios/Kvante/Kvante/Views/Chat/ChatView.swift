import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    var onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader

            // Progress pill
            if viewModel.allAssignments.count > 1 {
                ProgressPillView(
                    currentIndex: viewModel.currentAssignmentIndex,
                    totalCount: viewModel.totalAssignments,
                    completedIds: viewModel.completedAssignmentIds,
                    assignments: viewModel.allAssignments,
                    onTapAssignment: { index in
                        viewModel.jumpToAssignment(index)
                    }
                )
            }

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
                onHelp: { viewModel.requestHelp() }
            )
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
                        Text("🤖")
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
