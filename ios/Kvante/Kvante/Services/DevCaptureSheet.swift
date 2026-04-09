// DevCaptureSheet.swift
//
// Debug-only: note-first capture sheet presented by the Kvante FAB.
// Primary input is the TextField (auto-focused); screenshot and
// annotation are opt-in secondary actions.
//
// Two submit modes via the TODO toggle:
//   TODO (default ON):   note required, image optional, POST /dev/todos
//   Observation (off):   image required, note optional, POST /dev/screenshots
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit

struct DevCaptureSheet: View {
    let pendingScreenshot: UIImage?
    let apiClient: APIClient?
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var attachedScreenshot: UIImage?
    @State private var isTodo: Bool = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @State private var showAnnotationEditor = false
    @FocusState private var noteFocused: Bool

    private var canSubmit: Bool {
        if isSubmitting { return false }
        if isTodo {
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return attachedScreenshot != nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Hvad vil du huske?", text: $note, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                    .focused($noteFocused)
                    .padding(.horizontal)

                if let attachedScreenshot {
                    VStack(spacing: 8) {
                        Image(uiImage: attachedScreenshot)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        HStack(spacing: 16) {
                            Button("Annotér") {
                                showAnnotationEditor = true
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Fjern") {
                                self.attachedScreenshot = nil
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding(.horizontal)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if didSucceed {
                    Text("Sendt ✓")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                Spacer()

                // Action bar at the bottom
                VStack(spacing: 4) {
                    HStack {
                        Button(action: {
                            attachedScreenshot = pendingScreenshot
                        }) {
                            Label("Tag billede", systemImage: "camera")
                        }
                        .buttonStyle(.bordered)
                        .disabled(attachedScreenshot != nil || pendingScreenshot == nil)

                        Spacer()

                        HStack(spacing: 6) {
                            Text("TODO")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Toggle("TODO", isOn: $isTodo)
                                .labelsHidden()
                        }
                    }
                    .padding(.horizontal)

                    if pendingScreenshot == nil {
                        Text("Kunne ikke fange skærmen")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.top, 12)
            .navigationTitle("Ny capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onAppear {
                noteFocused = true
            }
            .fullScreenCover(isPresented: $showAnnotationEditor) {
                if let attachedScreenshot {
                    DevAnnotationEditor(
                        originalImage: attachedScreenshot,
                        onFinish: { annotated in
                            self.attachedScreenshot = annotated
                            showAnnotationEditor = false
                        },
                        onCancel: {
                            showAnnotationEditor = false
                        }
                    )
                }
            }
        }
    }

    private func submit() async {
        guard canSubmit, let apiClient else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let imageData = attachedScreenshot?.jpegData(compressionQuality: 0.85)
            if isTodo {
                try await apiClient.submitDevTodo(note: note, imageData: imageData)
            } else {
                // attachedScreenshot is guaranteed non-nil by canSubmit
                try await apiClient.submitDevScreenshot(imageData: imageData!, note: note)
            }
            didSucceed = true
            try? await Task.sleep(nanoseconds: 600_000_000)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

#endif
