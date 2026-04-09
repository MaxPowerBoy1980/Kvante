import Foundation
import UIKit
import ImageIO

/// Cache for downsampled scan thumbnails. Uses NSCache for OS-managed eviction
/// under memory pressure. Scans are immutable so no invalidation is needed.
@MainActor
final class ScanImageCache {
    static let shared = ScanImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Limit to ~30 thumbnails in memory (each ~400px, roughly 200KB)
        cache.countLimit = 30
    }

    /// Load a scan image, downsampled to maxPixelSize, from cache or network.
    func image(for scanId: String, apiClient: APIClient, maxPixelSize: Int = 400) async -> UIImage? {
        let key = "\(scanId)_\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        do {
            let url = await apiClient.scanImageURL(scanId: scanId)
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }

            let image = UIImage(cgImage: cgImage)
            cache.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }
}
