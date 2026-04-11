import SwiftUI
import VisionKit

// MARK: - Image Downscaling

func downscaleToJPEG(_ image: UIImage, maxDimension: CGFloat = 2048, quality: CGFloat = 0.8) -> Data {
    let size = image.size
    let scale: CGFloat
    if max(size.width, size.height) > maxDimension {
        scale = maxDimension / max(size.width, size.height)
    } else {
        scale = 1.0
    }

    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let scaled = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return scaled.jpegData(compressionQuality: quality) ?? Data()
}

// MARK: - BulkScanButton

struct BulkScanButton: View {
    let hasIncompleteAssignments: Bool
    let onScanComplete: ([Data]) -> Void

    @State private var showScanner = false

    var body: some View {
        if hasIncompleteAssignments {
            Button {
                showScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Scan hele arket")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView { images in
                    showScanner = false
                    let jpegData = images.map { downscaleToJPEG($0) }
                    onScanComplete(jpegData)
                } onCancel: {
                    showScanner = false
                }
            }
        }
    }
}

// MARK: - DocumentScannerView (VisionKit wrapper)

struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}
