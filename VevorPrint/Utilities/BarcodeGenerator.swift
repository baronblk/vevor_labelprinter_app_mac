/// BarcodeGenerator.swift
/// CoreImage-based barcode and QR code generator.
/// All methods are synchronous and hardware-independent (no BLE, no printer needed).

import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

// MARK: - BarcodeGenerator

enum BarcodeGenerator {

    // MARK: - Shared CIContext

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - QR Code

    /// Generate a QR Code CGImage.
    /// - Parameters:
    ///   - payload: The string to encode.
    ///   - correctionLevel: L / M / Q / H.
    ///   - size: Desired output size in pixels (square).
    /// - Returns: CGImage, or nil on failure.
    static func qrCode(payload: String, correctionLevel: QRCorrectionLevel, size: CGFloat) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = correctionLevel.rawValue
        return render(filter.outputImage, to: CGSize(width: size, height: size))
    }

    // MARK: - Code 128

    /// Generate a Code 128 barcode CGImage.
    /// - Parameters:
    ///   - payload: The string to encode.
    ///   - size: Desired output size in pixels.
    static func code128(payload: String, size: CGSize) -> CGImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(payload.utf8)
        filter.quietSpace = 2.0
        return render(filter.outputImage, to: size)
    }

    // MARK: - EAN-13

    /// Generate an EAN-13 barcode. Payload must be exactly 13 digits.
    static func ean13(payload: String, size: CGSize) -> CGImage? {
        guard let filter = CIFilter(name: "CIEAN13BarcodeGenerator") else {
            return code128(payload: payload, size: size)
        }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        return render(filter.outputImage, to: size)
    }

    // MARK: - EAN-8

    /// Generate an EAN-8 barcode. Payload must be exactly 8 digits.
    static func ean8(payload: String, size: CGSize) -> CGImage? {
        guard let filter = CIFilter(name: "CIEAN8BarcodeGenerator") else {
            return code128(payload: payload, size: size)
        }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        return render(filter.outputImage, to: size)
    }

    // MARK: - Aztec

    /// Generate an Aztec barcode.
    static func aztec(payload: String, size: CGFloat) -> CGImage? {
        let filter = CIFilter.aztecCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = 23   // %
        filter.compactStyle = 0
        return render(filter.outputImage, to: CGSize(width: size, height: size))
    }

    // MARK: - PDF417

    /// Generate a PDF417 barcode.
    static func pdf417(payload: String, size: CGSize) -> CGImage? {
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = Data(payload.utf8)
        return render(filter.outputImage, to: size)
    }

    // MARK: - DataMatrix

    /// Generate a DataMatrix barcode.
    static func dataMatrix(payload: String, size: CGFloat) -> CGImage? {
        guard let filter = CIFilter(name: "CIDataMatrixCodeGenerator") else { return nil }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        return render(filter.outputImage, to: CGSize(width: size, height: size))
    }

    // MARK: - Dispatch by BarcodeType

    /// Generate any barcode type from a BarcodeElement.
    /// - Parameters:
    ///   - element: The BarcodeElement with type + payload.
    ///   - size: Desired output size in pixels.
    /// - Returns: CGImage or nil.
    static func generate(for element: BarcodeElement, size: CGSize) -> CGImage? {
        let payload = element.payload.isEmpty ? " " : element.payload
        switch element.barcodeType {
        case .code128:    return code128(payload: payload, size: size)
        case .ean13:      return ean13(payload: payload, size: size)
        case .ean8:       return ean8(payload: payload, size: size)
        case .qrCode:     return qrCode(payload: payload, correctionLevel: .medium, size: min(size.width, size.height))
        case .aztec:      return aztec(payload: payload, size: min(size.width, size.height))
        case .pdf417:     return pdf417(payload: payload, size: size)
        case .dataMatrix: return dataMatrix(payload: payload, size: min(size.width, size.height))
        }
    }

    // MARK: - Private: Render CIImage → CGImage at target size

    /// Scales a CIImage to fill the target size and returns a CGImage.
    /// - Parameters:
    ///   - ciImage: Source CIImage (may be nil — returns nil in that case).
    ///   - targetSize: Output size in pixels.
    private static func render(_ ciImage: CIImage?, to targetSize: CGSize) -> CGImage? {
        guard let ci = ciImage else { return nil }
        let extent = ci.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let scaleX = targetSize.width  / extent.width
        let scaleY = targetSize.height / extent.height
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        return ciContext.createCGImage(scaled, from: scaled.extent)
    }
}
