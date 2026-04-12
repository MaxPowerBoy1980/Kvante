import SwiftUI

/// Dims the entire image except the bounding box region, which is shown with an orange border.
/// Apply as `.overlay { BoundingBoxOverlay(region: cropRegion) }` on an image view.
struct BoundingBoxOverlay: View {
    let region: CropRegion

    var body: some View {
        GeometryReader { geo in
            let boxRect = CGRect(
                x: region.x * geo.size.width,
                y: region.y * geo.size.height,
                width: region.width * geo.size.width,
                height: region.height * geo.size.height
            )

            // Dimmed overlay with even-odd cutout
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                path.addRoundedRect(
                    in: boxRect,
                    cornerRadii: .init(topLeading: 4, bottomLeading: 4, bottomTrailing: 4, topTrailing: 4)
                )
            }
            .fill(style: FillStyle(eoFill: true))
            .foregroundStyle(Color.black.opacity(0.4))

            // Orange border around the highlighted region
            RoundedRectangle(cornerRadius: 4)
                .stroke(KvanteTheme.Colors.primary, lineWidth: 2)
                .frame(width: boxRect.width, height: boxRect.height)
                .position(x: boxRect.midX, y: boxRect.midY)
        }
        .allowsHitTesting(false)
    }
}
