// DevScreenshotSubmit.swift
//
// Debug-only feature: capture a screenshot and send it (with an optional
// note) to the backend's /dev/screenshots endpoint. Claude can then fetch
// the latest screenshot during a dev session to inspect what the user is
// seeing.
//
// Two triggers:
// 1. Tap the floating camera button in the bottom-right corner
// 2. Shake the iPad (alternative/fallback gesture)
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit

// MARK: - Shake detection
//
// SwiftUI doesn't expose motion events directly, so we extend UIWindow
// to post a notification on shake. The view modifier listens for it.

extension Notification.Name {
    static let kvanteDeviceDidShake = Notification.Name("kvanteDeviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .kvanteDeviceDidShake, object: nil)
        }
    }
}

// MARK: - Screenshot capture

enum ScreenshotCapture {
    /// Render the current key window into a UIImage.
    static func captureKeyWindow() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

// MARK: - Submit sheet

struct DevScreenshotSubmitSheet: View {
    let image: UIImage
    let apiClient: APIClient?
    let onDismiss: () -> Void

    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Note til Claude (valgfri)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("fx: knappen er for lille her", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if didSucceed {
                    Text("Sendt ✓")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Send screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await submit() } }
                        .disabled(isSubmitting || apiClient == nil)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private func submit() async {
        guard let apiClient else {
            errorMessage = "Ingen forbindelse til serveren"
            return
        }
        guard let pngData = image.pngData() else {
            errorMessage = "Kunne ikke kode billedet"
            return
        }
        isSubmitting = true
        errorMessage = nil
        do {
            try await apiClient.submitDevScreenshot(imageData: pngData, note: note)
            didSucceed = true
            // Auto-dismiss after a brief confirmation
            try? await Task.sleep(nanoseconds: 600_000_000)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}

// MARK: - View modifier

// MARK: - Floating button overlay

private struct DevScreenshotFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.85))
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send debug screenshot")
    }
}

// MARK: - Combined modifier (shake + floating button)

private struct DevScreenshotSubmitModifier: ViewModifier {
    let apiClient: APIClient?
    @State private var captured: UIImage?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .kvanteDeviceDidShake)) { _ in
                triggerCapture()
            }
            .overlay(alignment: .bottomTrailing) {
                DevScreenshotFloatingButton(action: triggerCapture)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .allowsHitTesting(captured == nil)
            }
            .sheet(item: Binding(
                get: { captured.map { ImageWrapper(image: $0) } },
                set: { if $0 == nil { captured = nil } }
            )) { wrapper in
                DevScreenshotSubmitSheet(
                    image: wrapper.image,
                    apiClient: apiClient,
                    onDismiss: { captured = nil }
                )
            }
    }

    private func triggerCapture() {
        guard captured == nil else { return }
        captured = ScreenshotCapture.captureKeyWindow()
    }
}

private struct ImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

extension View {
    /// Attach the dev screenshot submit feature (floating button + shake
    /// gesture). Debug-only; becomes a no-op in release builds.
    func devScreenshotSubmit(apiClient: APIClient?) -> some View {
        modifier(DevScreenshotSubmitModifier(apiClient: apiClient))
    }
}

#else

import SwiftUI

extension View {
    /// Release builds: no-op so callers don't need their own #if DEBUG.
    func devScreenshotSubmit(apiClient: Any?) -> some View {
        self
    }
}

#endif
