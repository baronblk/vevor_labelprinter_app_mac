/// ExportService.swift
/// Handles PNG, PDF, and JSON export as well as JSON import.
/// All methods run on the main actor and present macOS save / open panels.

import AppKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - ExportService

@MainActor
enum ExportService {

    // MARK: - PNG Export

    /// Export the label as a PNG file at the given DPI.
    ///
    /// - Parameters:
    ///   - elements: Sorted label elements.
    ///   - labelSize: Label dimensions in mm.
    ///   - dpi: Resolution (default 300 dpi).
    /// - Returns: `true` if the file was saved successfully.
    @discardableResult
    static func exportPNG(
        elements: [AnyLabelElement],
        labelSize: LabelSize,
        dpi: CGFloat = 300
    ) -> Bool {
        guard let cgImage = LabelRenderer.render(elements: elements, labelSize: labelSize, dpi: dpi)
        else { return false }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(
            width:  Double(cgImage.width)  / dpi * 25.4,
            height: Double(cgImage.height) / dpi * 25.4
        )
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }

        let panel = NSSavePanel()
        panel.title            = "Label als PNG exportieren"
        panel.nameFieldStringValue = "\(labelSize.name).png"
        panel.allowedContentTypes  = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: - PDF Export

    /// Export the label as a single-page PDF.
    ///
    /// - Parameters:
    ///   - elements: Sorted label elements.
    ///   - labelSize: Label dimensions in mm.
    /// - Returns: `true` if the file was saved successfully.
    @discardableResult
    static func exportPDF(
        elements: [AnyLabelElement],
        labelSize: LabelSize
    ) -> Bool {
        guard let cgImage = LabelRenderer.render(elements: elements, labelSize: labelSize, dpi: 300)
        else { return false }

        // Physical size in points (72 pt/inch)
        let ptPerMM: CGFloat = 72.0 / 25.4
        let pageRect = CGRect(
            x: 0, y: 0,
            width:  labelSize.widthMM  * ptPerMM,
            height: labelSize.heightMM * ptPerMM
        )

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              var mediaBox = Optional(pageRect),
              let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return false }

        pdfCtx.beginPDFPage(nil)
        pdfCtx.draw(cgImage, in: pageRect)
        pdfCtx.endPDFPage()
        pdfCtx.closePDF()

        let panel = NSSavePanel()
        panel.title                = "Label als PDF exportieren"
        panel.nameFieldStringValue = "\(labelSize.name).pdf"
        panel.allowedContentTypes  = [.pdf]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try (pdfData as Data).write(to: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: - JSON Export

    /// Export the label design (elements + size) as JSON.
    ///
    /// - Parameters:
    ///   - elements: All label elements.
    ///   - labelSize: Label dimensions.
    /// - Returns: `true` if saved successfully.
    @discardableResult
    static func exportJSON(
        elements: [AnyLabelElement],
        labelSize: LabelSize
    ) -> Bool {
        let payload = LabelExportPayload(elements: elements, labelSize: labelSize)
        guard let data = try? JSONEncoder().encode(payload) else { return false }

        let panel = NSSavePanel()
        panel.title                = "Label-Design exportieren"
        panel.nameFieldStringValue = "\(labelSize.name).vevorprint"
        panel.allowedContentTypes  = [UTType(filenameExtension: "vevorprint") ?? .json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    // MARK: - JSON Import

    /// Present an open panel and decode a previously exported label design.
    ///
    /// - Returns: Decoded `(elements, labelSize)` tuple, or `nil` if cancelled / failed.
    static func importJSON() -> (elements: [AnyLabelElement], labelSize: LabelSize)? {
        let panel = NSOpenPanel()
        panel.title            = "Label-Design importieren"
        panel.canChooseFiles   = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection  = false
        panel.allowedContentTypes  = [
            UTType(filenameExtension: "vevorprint") ?? .json,
            .json
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(LabelExportPayload.self, from: data)
        else { return nil }

        return (payload.elements, payload.labelSize)
    }
}

// MARK: - LabelExportPayload

/// Codable container for a complete label design (JSON import/export).
private struct LabelExportPayload: Codable {
    var elements: [AnyLabelElement]
    var labelSize: LabelSize
}
