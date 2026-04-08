import SwiftUI

/// Viser et scannet billede enten fra in-memory Data (lige scannet) eller
/// via AsyncImage fra backendens /scans/{id}/image (loadet fra historik).
struct ScannedImageView: View {
    let data: Data?
    let scanId: String?
    let apiClient: APIClient

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                imageFrame(uiImage: uiImage)
            } else if let scanId {
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
            } else {
                placeholder
            }
        }
    }

    private func imageFrame(uiImage: UIImage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
        Text("📷 Billedet kunne ikke hentes")
            .font(.caption)
            .foregroundStyle(KvanteTheme.Colors.textMuted)
            .frame(width: 220, height: 60)
    }
}
