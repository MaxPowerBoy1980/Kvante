import SwiftUI

/// Viser et scannet billede enten fra in-memory Data (lige scannet) eller
/// via AsyncImage fra backendens /scans/{id}/image (loadet fra historik).
/// Med maxPixelSize bruger den ScanImageCache for effektiv thumbnail-rendering.
struct ScannedImageView: View {
    let data: Data?
    let scanId: String?
    let apiClient: APIClient
    var maxPixelSize: Int? = nil
    var cropRegion: CropRegion? = nil

    @State private var cachedImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                imageFrame(uiImage: uiImage)
            } else if let cachedImage {
                imageFrame(uiImage: cachedImage)
            } else if let scanId, maxPixelSize == nil, cropRegion == nil {
                // Full-resolution path (existing behavior)
                AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 220, height: 180)
                    case .success(let img):
                        imageFrameFromSwiftUIImage(img)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else if failed {
                placeholder
            } else {
                // Shimmer skeleton while loading
                RoundedRectangle(cornerRadius: 8)
                    .fill(KvanteTheme.Colors.cream)
                    .frame(width: maxPixelSize != nil ? 160 : 220,
                           height: maxPixelSize != nil ? 100 : 180)
                    .modifier(ShimmerModifier())
            }
        }
        .task(id: scanId) {
            guard let scanId, data == nil else { return }
            if let cropRegion {
                cachedImage = await ScanImageCache.shared.croppedImage(
                    for: scanId, region: cropRegion, apiClient: apiClient
                )
            } else if let maxPixelSize {
                cachedImage = await ScanImageCache.shared.image(
                    for: scanId, apiClient: apiClient, maxPixelSize: maxPixelSize
                )
            }
            if cachedImage == nil { failed = true }
        }
    }

    private func imageFrame(uiImage: UIImage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxPixelSize != nil ? 160 : 220,
                       maxHeight: maxPixelSize != nil ? 100 : 180)
                .clipShape(RoundedRectangle(cornerRadius: maxPixelSize != nil ? 8 : 14))
        }
    }

    private func imageFrameFromSwiftUIImage(_ img: Image) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            img
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var placeholder: some View {
        Text("Billedet kunne ikke hentes")
            .font(.caption)
            .foregroundStyle(KvanteTheme.Colors.textMuted)
            .frame(width: maxPixelSize != nil ? 160 : 220,
                   height: maxPixelSize != nil ? 40 : 60)
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}
