/// ESCPOSEncoder.swift
/// Encodes a CGImage into an ESC/POS byte stream for thermal printers.
///
/// Command sequence:
///   1. ESC @         (0x1B 0x40)       — Initialise printer
///   2. GS v 0        (0x1D 0x76 0x30 m xL xH yL yH + bitmap) — Raster image
///   3. LF × 3        (0x0A × 3)        — Paper feed
///   4. GS V          (0x1D 0x56 0x00)  — Full cut
///
/// The bitmap is converted to 1-bit (MSB first) using a simple luminance
/// threshold: pixels with luminance < 0.5 are printed (bit = 1), lighter
/// pixels are blank (bit = 0).

import CoreGraphics
import AppKit

// MARK: - ESCPOSEncoder

enum ESCPOSEncoder {

    // MARK: - Errors

    enum EncoderError: LocalizedError {
        case bitmapContextFailed
        case imageDrawFailed

        var errorDescription: String? {
            switch self {
            case .bitmapContextFailed: return "ESC/POS: Bitmap-Kontext konnte nicht erstellt werden."
            case .imageDrawFailed:     return "ESC/POS: Bild konnte nicht in Bitmap gerendert werden."
            }
        }
    }

    // MARK: - ESC/POS Constants

    private static let ESC:  UInt8 = 0x1B
    private static let GS:   UInt8 = 0x1D
    private static let LF:   UInt8 = 0x0A

    // MARK: - Public API

    /// Encode a CGImage as a complete ESC/POS print job.
    ///
    /// - Parameters:
    ///   - image: The label bitmap (typically from `LabelRenderer`).
    ///   - feedLines: Number of LF bytes to emit after the image (default 3).
    ///   - cut: Whether to append a paper-cut command (default true).
    /// - Returns: `Data` ready for BLE transmission.
    /// - Throws: `EncoderError` if the bitmap cannot be processed.
    static func encode(
        _ image: CGImage,
        feedLines: Int = 3,
        cut: Bool = true
    ) throws -> Data {
        var bytes: [UInt8] = []

        // 1. Initialise
        bytes += initPrinter()

        // 2. Raster image
        bytes += try rasterImageCommand(from: image)

        // 3. Paper feed
        bytes += Array(repeating: LF, count: max(0, feedLines))

        // 4. Cut
        if cut { bytes += paperCut() }

        return Data(bytes)
    }

    // MARK: - Command Builders

    /// ESC @ — Initialise printer (resets settings to defaults).
    static func initPrinter() -> [UInt8] {
        [ESC, 0x40]
    }

    /// LF × n — Feed n lines.
    static func lineFeed(count: Int = 1) -> [UInt8] {
        Array(repeating: LF, count: max(1, count))
    }

    /// GS V 0 — Full paper cut.
    static func paperCut() -> [UInt8] {
        [GS, 0x56, 0x00]
    }

    /// GS v 0 — Raster bit image command.
    ///
    /// The image is converted to 8-bpp greyscale, then each pixel is
    /// thresholded to 1 bit (luminance < 0.5 → printed).
    ///
    /// - Parameter image: Source CGImage (any colour space).
    /// - Returns: Complete GS v 0 command bytes including header + pixel data.
    /// - Throws: `EncoderError.bitmapContextFailed` on allocation failure.
    static func rasterImageCommand(from image: CGImage) throws -> [UInt8] {
        let width  = image.width
        let height = image.height

        // Number of bytes per row (8 pixels per byte, MSB first)
        let bytesPerRow = (width + 7) / 8

        // Render to 8-bpp greyscale bitmap
        guard let graySpace = CGColorSpace(name: CGColorSpace.linearGray),
              let ctx = CGContext(
                data: nil,
                width:  width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,       // 1 byte per pixel
                space: graySpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            throw EncoderError.bitmapContextFailed
        }

        // Draw white background first, then the image
        ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = ctx.data else {
            throw EncoderError.imageDrawFailed
        }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height)

        // Pack pixels into 1-bit rows (MSB first, inverted: dark pixel = 1)
        var bitmapBytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        for row in 0 ..< height {
            for col in 0 ..< width {
                let luminance = pixels[row * width + col]
                // luminance 0 = black (print), 255 = white (skip)
                if luminance < 128 {
                    let byteIdx = row * bytesPerRow + col / 8
                    let bitShift = 7 - (col % 8)          // MSB first
                    bitmapBytes[byteIdx] |= (1 << bitShift)
                }
            }
        }

        // GS v 0 header
        //   mode: 0x00 = normal (1× scaling)
        //   xL/xH: bytes per row (little-endian)
        //   yL/yH: number of rows (little-endian)
        let xL = UInt8(bytesPerRow & 0xFF)
        let xH = UInt8((bytesPerRow >> 8) & 0xFF)
        let yL = UInt8(height & 0xFF)
        let yH = UInt8((height >> 8) & 0xFF)

        var cmd: [UInt8] = [GS, 0x76, 0x30, 0x00, xL, xH, yL, yH]
        cmd += bitmapBytes
        return cmd
    }
}
