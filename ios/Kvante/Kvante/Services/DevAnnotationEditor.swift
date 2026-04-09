// DevAnnotationEditor.swift
//
// Debug-only: full-screen PencilKit editor for annotating captured
// screenshots. Presented from DevCaptureSheet's "Annotér" button when
// an attached screenshot exists.
//
// Critical design note: canvas frame MUST match originalImage.size
// (in points) so the PKDrawing coordinate space matches the flatten
// output coordinate space. If this file is ever changed to use
// scaledToFit or aspectRatio, the flatten logic must be rewritten to
// handle the coordinate mismatch.
//
// All code in this file is gated by #if DEBUG and stripped from release
// builds.

#if DEBUG
import SwiftUI
import UIKit
import PencilKit

struct DevAnnotationEditor: View {
    let originalImage: UIImage
    let onFinish: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    Image(uiImage: originalImage)
                        .frame(
                            width: originalImage.size.width,
                            height: originalImage.size.height
                        )
                    CanvasRepresentable(canvasView: $canvasView)
                        .frame(
                            width: originalImage.size.width,
                            height: originalImage.size.height
                        )
                }
            }
            .navigationTitle("Annotér")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Færdig") {
                        onFinish(flattenedImage())
                    }
                }
            }
            .onAppear {
                // Activate the system tool picker for the canvas.
                if let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow }),
                   let toolPicker = PKToolPicker.shared(for: window) {
                    toolPicker.setVisible(true, forFirstResponder: canvasView)
                    toolPicker.addObserver(canvasView)
                    canvasView.becomeFirstResponder()
                }
            }
        }
    }

    /// Render the PKCanvasView drawing on top of the original image
    /// and return a flat UIImage. Coordinate space is consistent
    /// because the canvas frame matches originalImage.size.
    ///
    /// If the layout ever changes to use scaledToFit or a different
    /// canvas frame, this function must be rewritten to transform the
    /// drawing coordinates accordingly.
    private func flattenedImage() -> UIImage {
        let size = originalImage.size  // points
        let format = UIGraphicsImageRendererFormat()
        format.scale = originalImage.scale  // native pixel density
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            originalImage.draw(in: CGRect(origin: .zero, size: size))
            let canvasImage = canvasView.drawing.image(
                from: CGRect(origin: .zero, size: size),
                scale: originalImage.scale
            )
            canvasImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - SwiftUI wrapper for PKCanvasView

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput   // Apple Pencil + finger
        canvasView.backgroundColor = .clear    // background image visible through
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // No-op — PKCanvasView instance is @Binding-owned by parent
    }
}

#endif
