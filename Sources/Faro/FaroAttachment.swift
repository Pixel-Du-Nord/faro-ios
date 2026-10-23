import CoreGraphics
import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

/**
 An image ready to travel with a request: a JPEG of at most
 ``maxPixelSide`` pixels on its long side and ``maxBytes`` bytes.

 Creating one does the work (decoding, scaling, re-encoding), so do it off the
 main thread for large photos. A phone screenshot of 2–4 MB as PNG ends up
 around 300–500 KB and perfectly readable.
 */
public struct FaroAttachment: Sendable, Hashable, Identifiable {
    /// Faro takes up to 3 images per request.
    public static let maxCount = 3
    /// Faro's limit per image: 3 MB.
    public static let maxBytes = 3 * 1024 * 1024
    /// Images are scaled down to this many pixels on their long side.
    public static let maxPixelSide = 2048

    public let id: UUID
    /// The JPEG bytes.
    public let data: Data
    /// Always `image/jpeg`.
    public let mimeType: String
    /// The file name Faro stores it under.
    public let filename: String
    public let pixelWidth: Int
    public let pixelHeight: Int

    /**
     Reads an image (PNG, JPEG, HEIC, GIF, WebP… anything ImageIO decodes),
     applies its orientation, flattens transparency on white, scales it to
     ``maxPixelSide`` and re-encodes it as JPEG under ``maxBytes``.

     - Throws: ``FaroError/invalidAttachment`` if it cannot be read or made small enough.
     */
    public init(imageData: Data, filename: String = "image.jpg") throws {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw FaroError.invalidAttachment }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSide,
        ]
        guard let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw FaroError.invalidAttachment
        }
        try self.init(cgImage: scaled, filename: filename)
    }

    /// Re-encodes a decoded image (already the right way up).
    public init(cgImage: CGImage, filename: String = "image.jpg") throws {
        let image = try Self.flattened(Self.fitted(cgImage))
        var quality = 0.85
        var jpeg = Self.jpeg(image, quality: quality)
        while let current = jpeg, current.count > Self.maxBytes, quality > 0.25 {
            quality -= 0.15
            jpeg = Self.jpeg(image, quality: quality)
        }
        guard let jpeg, jpeg.count <= Self.maxBytes else { throw FaroError.invalidAttachment }
        self.id = UUID()
        self.data = jpeg
        self.mimeType = "image/jpeg"
        self.filename = Self.jpegName(filename)
        self.pixelWidth = image.width
        self.pixelHeight = image.height
    }

    #if canImport(UIKit)
    /// Prepares a `UIImage` (a screenshot, an edited capture…).
    public init(image: UIImage, filename: String = "screenshot.jpg") throws {
        if let cgImage = image.cgImage, image.imageOrientation == .up {
            try self.init(cgImage: cgImage, filename: filename)
        } else if let data = image.jpegData(compressionQuality: 0.95) {
            try self.init(imageData: data, filename: filename)
        } else {
            throw FaroError.invalidAttachment
        }
    }
    #endif

    // MARK: - Helpers

    private static func fitted(_ image: CGImage) throws -> CGImage {
        let side = max(image.width, image.height)
        guard side > maxPixelSide else { return image }
        let scale = Double(maxPixelSide) / Double(side)
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        return try draw(image, width: width, height: height)
    }

    /// JPEG has no alpha: paint the image on white so transparent areas don't turn black.
    private static func flattened(_ image: CGImage) throws -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: return try draw(image, width: image.width, height: image.height)
        }
    }

    private static func draw(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw FaroError.invalidAttachment }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        guard let result = context.makeImage() else { throw FaroError.invalidAttachment }
        return result
    }

    private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func jpegName(_ name: String) -> String {
        let base = (name as NSString).deletingPathExtension
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return (base.isEmpty ? "image" : String(base.prefix(60))) + ".jpg"
    }
}
