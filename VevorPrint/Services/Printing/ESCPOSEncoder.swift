/// ESCPOSEncoder.swift
/// Encodes a CGImage into an ESC/POS byte stream for thermal printers.
///
/// Command sequence:
///   1. ESC @         (0x1B 0x40)       — Initialise printer
///   2. GS v 0        (0x1D 0x76 0x30 m xL xH yL yH + bitmap) — Raster image
///      Repeated in strips of ≤255 rows because many budget printer firmwares
///      ignore the yH byte and only print yL rows (≤255 dots). Sending the full
///      image in one GS v 0 with yH > 0 causes only a partial "strip" to print.
///   3. LF × 3        (0x0A × 3)        — Paper feed
///   4. GS V          (0x1D 0x56 0x00)  — Full cut
///
/// The bitmap is converted to 1-bit (MSB first) using a simple luminance
/// threshold: pixels with luminance < 128 are printed (bit = 1), lighter
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

    /// GS v 0 — One or more raster bit image commands covering the full image.
    ///
    /// Many budget thermal printer firmwares (including the Vevor Y428BT-42B0)
    /// only read the `yL` byte of the row count and ignore `yH`. This silently
    /// caps the printed height at `yL` dots — for any label taller than ~21 mm
    /// at 300 DPI the printer stops after the first strip and ignores the rest.
    ///
    /// Workaround: split the bitmap into vertical strips of at most 255 rows and
    /// emit a separate `GS v 0` header for each strip, always with `yH = 0`.
    /// The printer renders each strip seamlessly as a continuous feed.
    ///
    /// The image is converted to 8-bpp greyscale, then each pixel is
    /// thresholded to 1 bit (luminance < 128 → printed).
    ///
    /// CoreGraphics quirks handled here:
    ///   - bytesPerRow must be aligned to a 4-byte boundary for the CGContext.
    ///   - CoreGraphics origin is bottom-left (rows stored bottom-to-top).
    ///     Iterating rows in reverse gives the correct top-to-bottom print order.
    ///
    /// - Parameter image: Source CGImage (any colour space).
    /// - Returns: Complete GS v 0 command bytes (one or more strips) + pixel data.
    /// - Throws: `EncoderError.bitmapContextFailed` on allocation failure.
    static func rasterImageCommand(from image: CGImage) throws -> [UInt8] {
        let width  = image.width
        let height = image.height

        // ESC/POS bytes per row (8 pixels per byte, MSB first).
        let escBytesPerRow = (width + 7) / 8

        // CGContext bytesPerRow must be aligned to a 4-byte boundary.
        // Using 1 byte per pixel (8-bpp grey), so round up width to next multiple of 4.
        let ctxBytesPerRow = ((width + 3) / 4) * 4

        guard let graySpace = CGColorSpace(name: CGColorSpace.linearGray),
              let ctx = CGContext(
                data: nil,
                width:  width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: ctxBytesPerRow,
                space: graySpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            throw EncoderError.bitmapContextFailed
        }

        // White background, then image.
        ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = ctx.data else {
            throw EncoderError.imageDrawFailed
        }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: ctxBytesPerRow * height)

        // Pack all pixels into a flat 1-bit array (MSB first, dark = 1).
        // CoreGraphics row 0 is at the BOTTOM; iterate in reverse for top-to-bottom order.
        var bitmapBytes = [UInt8](repeating: 0, count: escBytesPerRow * height)
        for row in 0 ..< height {
            let cgRow  = (height - 1) - row   // flip: cgRow 0 = bottom
            let escRow = row
            for col in 0 ..< width {
                let luminance = pixels[cgRow * ctxBytesPerRow + col]
                if luminance < 128 {
                    let byteIdx  = escRow * escBytesPerRow + col / 8
                    let bitShift = 7 - (col % 8)   // MSB first
                    bitmapBytes[byteIdx] |= (1 << bitShift)
                }
            }
        }

        // GS v 0 header fields:
        //   mode: 0x00 = normal (1× scaling)
        //   xL/xH: bytes per row (little-endian)
        //   yL/yH: row count for this strip (always yH = 0, yL ≤ 255)
        let xL = UInt8(escBytesPerRow & 0xFF)
        let xH = UInt8((escBytesPerRow >> 8) & 0xFF)

        // Split into strips of max 255 rows so yH is always 0.
        // Some firmware caps the height at yL and ignores yH; strips avoid that.
        let maxRowsPerStrip = 255
        var cmd: [UInt8] = []
        var startRow = 0
        while startRow < height {
            let rowCount = min(maxRowsPerStrip, height - startRow)
            let yL = UInt8(rowCount)
            cmd += [GS, 0x76, 0x30, 0x00, xL, xH, yL, 0x00]
            let byteStart = startRow * escBytesPerRow
            let byteEnd   = byteStart + rowCount * escBytesPerRow
            cmd += bitmapBytes[byteStart ..< byteEnd]
            startRow += rowCount
        }
        return cmd
    }
}
