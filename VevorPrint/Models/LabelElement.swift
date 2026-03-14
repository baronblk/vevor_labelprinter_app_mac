/// LabelElement.swift
/// Protocol for all canvas elements + AnyLabelElement type-erased wrapper for
/// Codable polymorphism. Concrete types: TextElement, ImageElement,
/// QRCodeElement, BarcodeElement, LineElement (fully implemented in Phase 4).
/// Phase 3 ships skeleton structs with full geometry and render() stubs.

import Foundation
import CoreGraphics
import AppKit

// MARK: - LabelElement Protocol

/// Every element placed on the canvas must conform to this protocol.
/// `frame` is in **millimetres**; rendering converts to pixels via UnitConversion.
protocol LabelElement: Identifiable, Codable {
    var id: UUID { get }
    /// Bounding rect in millimetres (origin = top-left of label).
    var frame: CGRect { get set }
    /// Clockwise rotation in degrees.
    var rotation: Double { get set }
    /// Paint order — higher values draw on top.
    var zIndex: Int { get set }
    /// Render into the given Core Graphics context.
    /// - Parameters:
    ///   - context: The CGContext to draw into.
    ///   - scale: Pixels per millimetre at the current DPI.
    func render(in context: CGContext, scale: CGFloat)
}

// MARK: - ElementType

/// Discriminator used by AnyLabelElement for decoding.
enum ElementType: String, Codable {
    case text
    case image
    case qrCode
    case barcode
    case line
}

// MARK: - AnyLabelElement (type-erased wrapper)

/// Type-erased, Codable wrapper that allows a heterogeneous [AnyLabelElement]
/// array to be serialised to JSON for SwiftData storage.
struct AnyLabelElement: Identifiable, Codable {

    // MARK: Properties

    var id: UUID { base.id }
    var frame: CGRect  { get { base.frame }  set { base.frame  = newValue } }
    var rotation: Double { get { base.rotation } set { base.rotation = newValue } }
    var zIndex: Int    { get { base.zIndex } set { base.zIndex = newValue } }
    let elementType: ElementType

    // MARK: Internal storage

    private var base: any LabelElement

    // MARK: Init

    init(_ element: some LabelElement) {
        self.base = element
        if element is TextElement    { self.elementType = .text }
        else if element is ImageElement  { self.elementType = .image }
        else if element is QRCodeElement { self.elementType = .qrCode }
        else if element is BarcodeElement{ self.elementType = .barcode }
        else                             { self.elementType = .line }
    }

    // MARK: Access

    /// Returns the underlying element cast to T, or nil.
    func unwrap<T: LabelElement>(as type: T.Type) -> T? { base as? T }

    func render(in context: CGContext, scale: CGFloat) {
        base.render(in: context, scale: scale)
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case elementType, payload
    }

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ElementType.self, forKey: .elementType)
        self.elementType = type
        switch type {
        case .text:    base = try c.decode(TextElement.self,    forKey: .payload)
        case .image:   base = try c.decode(ImageElement.self,   forKey: .payload)
        case .qrCode:  base = try c.decode(QRCodeElement.self,  forKey: .payload)
        case .barcode: base = try c.decode(BarcodeElement.self, forKey: .payload)
        case .line:    base = try c.decode(LineElement.self,    forKey: .payload)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(elementType, forKey: .elementType)
        switch elementType {
        case .text:    try c.encode(base as! TextElement,    forKey: .payload)
        case .image:   try c.encode(base as! ImageElement,   forKey: .payload)
        case .qrCode:  try c.encode(base as! QRCodeElement,  forKey: .payload)
        case .barcode: try c.encode(base as! BarcodeElement, forKey: .payload)
        case .line:    try c.encode(base as! LineElement,    forKey: .payload)
        }
    }
}

// MARK: - Equatable support for selection comparison

extension AnyLabelElement: Equatable {
    static func == (lhs: AnyLabelElement, rhs: AnyLabelElement) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - TextElement

/// A text box with font, size, style and alignment options.
struct TextElement: LabelElement {
    var id: UUID = UUID()
    var frame: CGRect = CGRect(x: 5, y: 5, width: 40, height: 10)
    var rotation: Double = 0
    var zIndex: Int = 0

    // MARK: Text Properties
    var text: String = "Text"
    var fontName: String = "Helvetica"
    var fontSize: Double = 12          // pt
    var isBold: Bool = false
    var isItalic: Bool = false
    var textAlignment: TextAlignmentOption = .left
    var textColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)

    func render(in context: CGContext, scale: CGFloat) {
        // Full rendering implemented in Phase 4/5
        let rect = CGRect(
            x: frame.origin.x * scale,
            y: frame.origin.y * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(rect)
    }
}

// MARK: - ImageElement

/// A raster or PDF image element.
struct ImageElement: LabelElement {
    var id: UUID = UUID()
    var frame: CGRect = CGRect(x: 5, y: 5, width: 30, height: 30)
    var rotation: Double = 0
    var zIndex: Int = 0

    // MARK: Image Properties
    /// Base64-encoded PNG data of the imported image.
    var imageData: Data? = nil
    var contentMode: ImageContentMode = .fit
    var maintainAspectRatio: Bool = true

    func render(in context: CGContext, scale: CGFloat) {
        // Phase 4/5: render imageData as CGImage
    }
}

enum ImageContentMode: String, Codable {
    case fit, fill, stretch
}

// MARK: - QRCodeElement

/// A QR code generated from an arbitrary string payload.
struct QRCodeElement: LabelElement {
    var id: UUID = UUID()
    var frame: CGRect = CGRect(x: 5, y: 5, width: 20, height: 20)
    var rotation: Double = 0
    var zIndex: Int = 0

    // MARK: QR Properties
    var payload: String = "https://example.com"
    var correctionLevel: QRCorrectionLevel = .medium

    func render(in context: CGContext, scale: CGFloat) {
        // Phase 4/5: render via CIQRCodeGenerator
    }
}

enum QRCorrectionLevel: String, Codable {
    case low = "L", medium = "M", quartile = "Q", high = "H"
}

// MARK: - BarcodeElement

/// A 1-D or 2-D barcode generated via CoreImage CIFilter.
struct BarcodeElement: LabelElement {
    var id: UUID = UUID()
    var frame: CGRect = CGRect(x: 5, y: 5, width: 50, height: 15)
    var rotation: Double = 0
    var zIndex: Int = 0

    // MARK: Barcode Properties
    var payload: String = "123456789012"
    var barcodeType: BarcodeType = .code128
    var showHumanReadable: Bool = true

    func render(in context: CGContext, scale: CGFloat) {
        // Phase 4/5: render via CIFilter
    }
}

enum BarcodeType: String, Codable, CaseIterable {
    case code128   = "Code 128"
    case ean13     = "EAN-13"
    case ean8      = "EAN-8"
    case qrCode    = "QR Code"
    case aztec     = "Aztec"
    case pdf417    = "PDF417"
    case dataMatrix = "DataMatrix"
}

// MARK: - LineElement

/// A horizontal or vertical separator line.
struct LineElement: LabelElement {
    var id: UUID = UUID()
    var frame: CGRect = CGRect(x: 2, y: 20, width: 56, height: 0.5)
    var rotation: Double = 0
    var zIndex: Int = 0

    // MARK: Line Properties
    var orientation: LineOrientation = .horizontal
    var lineWidth: Double = 0.5   // mm
    var lineColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)

    func render(in context: CGContext, scale: CGFloat) {
        let rect = CGRect(
            x: frame.origin.x * scale,
            y: frame.origin.y * scale,
            width: frame.width * scale,
            height: max(frame.height * scale, lineWidth * scale)
        )
        context.setFillColor(lineColor.cgColor)
        context.fill(rect)
    }
}

enum LineOrientation: String, Codable {
    case horizontal, vertical
}

// MARK: - CodableColor

/// CGColor-compatible, Codable colour value.
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - TextAlignmentOption

/// Codable replacement for NSTextAlignment.
enum TextAlignmentOption: String, Codable, CaseIterable {
    case left, center, right, justified

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left:      return .left
        case .center:    return .center
        case .right:     return .right
        case .justified: return .justified
        }
    }
}
