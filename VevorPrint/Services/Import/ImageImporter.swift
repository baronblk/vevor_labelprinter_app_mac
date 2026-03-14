/// ImageImporter.swift
/// PNG/JPEG/TIFF import with optional downscaling.
/// Returns PNG-encoded Data for storage in ImageElement.imageData.

import AppKit

// MARK: - ImageImporter

enum ImageImporter {

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case unsupportedFormat
        case loadFailed
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "Das Bildformat wird nicht unterstützt. Bitte PNG, JPEG oder TIFF verwenden."
            case .loadFailed:        return "Das Bild konnte nicht geladen werden."
            case .encodingFailed:    return "Das Bild konnte nicht kodiert werden."
            }
        }
    }

    /// Supported file extensions.
    static let supportedExtensions = ["png", "jpg", "jpeg", "tiff", "tif", "heic"]

    // MARK: - Import

    /// Load an image from disk and return PNG Data, optionally scaled to max dimension.
    /// - Parameters:
    ///   - url: File URL.
    ///   - maxPixels: Maximum width or height in pixels (0 = no limit).
    /// - Returns: PNG-encoded Data.
    /// - Throws: `ImportError` on failure.
    static func importImage(from url: URL, maxPixels: CGFloat = 2000) throws -> Data {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw ImportError.unsupportedFormat
        }
        guard let image = NSImage(contentsOf: url) else {
            throw ImportError.loadFailed
        }
        return try encode(image, maxPixels: maxPixels)
    }

    /// Encode an NSImage (possibly downscaled) as PNG Data.
    /// - Parameters:
    ///   - image: Source NSImage.
    ///   - maxPixels: Maximum dimension cap.
    /// - Returns: PNG Data.
    static func encode(_ image: NSImage, maxPixels: CGFloat = 2000) throws -> Data {
        let size = scaledSize(image.size, maxPixels: maxPixels)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { throw ImportError.encodingFailed }

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        image.draw(in: CGRect(origin: .zero, size: size),
                   from: CGRect(origin: .zero, size: image.size),
                   operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ImportError.encodingFailed
        }
        return data
    }

    /// Decode stored PNG Data back to NSImage.
    /// - Parameter data: PNG-encoded data.
    static func nsImage(from data: Data) -> NSImage? {
        NSImage(data: data)
    }

    /// Decode stored PNG Data to CGImage.
    static func cgImage(from data: Data) -> CGImage? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.cgImage
    }

    // MARK: - Helpers

    private static func scaledSize(_ original: CGSize, maxPixels: CGFloat) -> CGSize {
        guard maxPixels > 0 else { return original }
        let maxDim = max(original.width, original.height)
        guard maxDim > maxPixels else { return original }
        let scale = maxPixels / maxDim
        return CGSize(width: original.width * scale, height: original.height * scale)
    }
}
