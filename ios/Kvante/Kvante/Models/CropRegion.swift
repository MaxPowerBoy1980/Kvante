import Foundation

/// Normalized bounding box for a cropped region of a scan image.
/// All values are 0.0–1.0 relative to the image dimensions. Origin is top-left.
struct CropRegion: Codable, Hashable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    /// Deterministic cache key suffix with 3-decimal precision.
    var cacheKeySuffix: String {
        String(format: "%.3f_%.3f_%.3f_%.3f", x, y, width, height)
    }

    /// Initialize from a raw array [x, y, width, height]. Returns nil if invalid.
    init?(from array: [Double]?) {
        guard let array, array.count == 4 else { return nil }
        self.x = array[0]
        self.y = array[1]
        self.width = array[2]
        self.height = array[3]
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
