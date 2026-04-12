// DevCaptureButton.swift
//
// Debug-only feature: a global floating Kvante-styled capture button.
// Tap opens a note-first capture sheet where the user can write a TODO,
// optionally attach a screenshot of the underlying screen, and annotate
// it with Apple Pencil. Replaces the old shake-to-submit screenshot flow.
//
// Note-first semantics: the screenshot is captured in the background when
// the button is tapped, held in memory, and only attached to a submission
// if the user explicitly taps "Tag billede" in the sheet. This keeps pure
// note-capture friction-free while still making the underlying screen
// available.
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit

// MARK: - Screenshot capture (unchanged helper)

enum ScreenshotCapture {
    /// Render the current key window into a UIImage.
    /// Returns nil if no key window is available (unlikely in practice).
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

// MARK: - Notification trigger (replaces visible FAB)

extension Notification.Name {
    /// Long-press on KvanteFace triggers dev capture via this notification.
    static let devCaptureRequested = Notification.Name("devCaptureRequested")
}

// MARK: - View modifier (invisible — listens for notification)

private struct DevCaptureButtonModifier: ViewModifier {
    let apiClient: APIClient?

    @State private var pendingScreenshot: UIImage?
    @State private var sheetPresented = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .devCaptureRequested)) { _ in
                guard !sheetPresented else { return }
                triggerCapture()
            }
            .sheet(isPresented: $sheetPresented) {
                DevCaptureSheet(
                    pendingScreenshot: pendingScreenshot,
                    apiClient: apiClient,
                    onDismiss: {
                        sheetPresented = false
                        pendingScreenshot = nil
                    }
                )
            }
    }

    private func triggerCapture() {
        pendingScreenshot = ScreenshotCapture.captureKeyWindow()
        sheetPresented = true
    }
}

extension View {
    /// Attach the dev capture feature (floating Kvante button + sheet).
    /// Debug-only; becomes a no-op in release builds.
    func devCaptureButton(apiClient: APIClient?) -> some View {
        modifier(DevCaptureButtonModifier(apiClient: apiClient))
    }
}

#else

import SwiftUI

extension View {
    /// Release builds: no-op so callers don't need their own #if DEBUG.
    func devCaptureButton(apiClient: Any?) -> some View {
        self
    }
}

#endif
