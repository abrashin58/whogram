import UIKit
import ImageIO

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    func clear() { cache.removeAllObjects() }

    func image(at path: String, maxPixels: Int) async -> UIImage? {
        let work = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled, FileManager.default.isReadableFile(atPath: path) else { return nil as UIImage? }
            let key = "\(maxPixels):\(path)" as NSString
            if let cached = self.cache.object(forKey: key) { return cached }
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, options),
                  let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceShouldCacheImmediately: true,
                      kCGImageSourceThumbnailMaxPixelSize: maxPixels
                  ] as CFDictionary), !Task.isCancelled else { return nil }
            let image = UIImage(cgImage: decoded)
            self.cache.setObject(image, forKey: key, cost: decoded.bytesPerRow * decoded.height)
            return image
        }
        return await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
    }
}
