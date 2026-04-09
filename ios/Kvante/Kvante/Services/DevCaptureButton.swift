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

// MARK: - Floating Kvante FAB

private struct DevKvanteFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                // Base circle — Kvante orange/coral
                Circle()
                    .fill(Color(red: 0.85, green: 0.48, blue: 0.35))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                // Stylized eyes (two black dots)
                HStack(spacing: 6) {
                    Circle().fill(Color.black).frame(width: 5, height: 5)
                    Circle().fill(Color.black).frame(width: 5, height: 5)
                }
                .offset(x: 12, y: 18)

                // Coral pom-pom antenna
                Path { path in
                    path.move(to: CGPoint(x: 22, y: 2))
                    path.addLine(to: CGPoint(x: 22, y: -4))
                }
                .stroke(Color(red: 0.93, green: 0.4, blue: 0.55), lineWidth: 2)
                .offset(x: 0, y: 0)

                Circle()
                    .fill(Color(red: 0.93, green: 0.4, blue: 0.55))
                    .frame(width: 6, height: 6)
                    .offset(x: 19, y: -8)

                // DEV badge
                Text("DEV")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(2)
                    .offset(x: -2, y: 28)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dev capture")
    }
}

// MARK: - View modifier

private struct DevCaptureButtonModifier: ViewModifier {
    let apiClient: APIClient?

    // pendingScreenshot is captured BEFORE the sheet is presented
    // (at FAB tap time), held in memory, and only attached to a submission
    // if the user explicitly taps "Tag billede" in the sheet.
    @State private var pendingScreenshot: UIImage?
    @State private var sheetPresented = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                DevKvanteFloatingButton(action: triggerCapture)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .allowsHitTesting(!sheetPresented)
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
