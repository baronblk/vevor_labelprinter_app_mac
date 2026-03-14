/// PDFImporter.swift
/// PDFKit-based importer. Renders the first page of a PDF to a PNG Data blob
/// at a given DPI so it can be stored in an ImageElement.

import PDFKit
import AppKit

// MARK: - PDFImporter

enum PDFImporter {

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case cannotOpenDocument
        case noPages
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .cannotOpenDocument: return "Die PDF-Datei konnte nicht geöffnet werden."
            case .noPages:            return "Die PDF-Datei enthält keine Seiten."
            case .renderFailed:       return "Die PDF-Seite konnte nicht gerendert werden."
            }
        }
    }

    // MARK: - Import

    /// Load a PDF from disk and render page 0 as PNG Data.
    /// - Parameters:
    ///   - url: File URL of the PDF.
    ///   - dpi: Render resolution (default: 300).
    ///   - pageIndex: Zero-based page index (default: 0).
    /// - Returns: PNG-encoded Data of the rendered page.
    /// - Throws: `ImportError` on failure.
    static func importFirstPage(from url: URL, dpi: CGFloat = 300, pageIndex: Int = 0) throws -> Data {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.cannotOpenDocument
        }
        guard let page = document.page(at: pageIndex) else {
            throw ImportError.noPages
        }
        return try renderPage(page, dpi: dpi)
    }

    /// Render a PDFPage to PNG Data.
    /// - Parameters:
    ///   - page: The PDFPage to render.
    ///   - dpi: Target resolution.
    /// - Returns: PNG-encoded Data.
    static func renderPage(_ page: PDFPage, dpi: CGFloat = 300) throws -> Data {
        let pointsPerInch: CGFloat = 72
        let scale = dpi / pointsPerInch
        let pageBounds = page.bounds(for: .mediaBox)
        let pixelSize = CGSize(
            width:  pageBounds.width  * scale,
            height: pageBounds.height * scale
        )

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw ImportError.renderFailed }

        let context = NSGraphicsContext(bitmapImageRep: bitmapRep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: scale, y: scale)
        // White background
        NSColor.white.setFill()
        NSBezierPath(rect: pageBounds).fill()
        page.draw(with: .mediaBox, to: context.cgContext)
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ImportError.renderFailed
        }
        return pngData
    }

    // MARK: - Page count

    /// Returns the number of pages in a PDF file.
    /// - Parameter url: File URL.
    static func pageCount(at url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }
}
