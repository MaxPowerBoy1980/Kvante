import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

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
}
