/// ElementView.swift
/// SwiftUI view that renders a single AnyLabelElement on screen.
/// Used by LabelCanvasView as the per-element rendering layer
/// (overlaid on top of the static Canvas background).
/// Also used by LabelRenderer (off-screen) for print output.

import SwiftUI

// MARK: - ElementView

struct ElementView: View {

    // MARK: - Input

    let element: AnyLabelElement
    /// Points per mm at the current zoom level.
    let scale: CGFloat
    /// Whether this element is currently being edited inline (text).
    var isEditing: Bool = false
    /// Called when inline editing commits.
    var onEditCommit: ((String) -> Void)? = nil

    // MARK: - Body

    var body: some View {
        Group {
            switch element.elementType {
            case .text:    textView
            case .image:   imageView
            case .qrCode:  qrView
            case .barcode: barcodeView
            case .line:    lineView
            }
        }
        .frame(width: element.frame.width * scale,
               height: element.frame.height * scale)
        .rotationEffect(.degrees(element.rotation))
    }

    // MARK: - Text

    @ViewBuilder
    private var textView: some View {
        if let el = element.unwrap(as: TextElement.self) {
            if isEditing {
                InlineTextEditor(
                    text: el.text,
                    fontSize: el.fontSize * scale / 25.4 * 3.78,  // approx pt for screen
                    fontName: el.fontName,
                    isBold: el.isBold,
                    isItalic: el.isItalic,
                    alignment: el.textAlignment,
                    textColor: el.textColor
                ) { newText in
                    onEditCommit?(newText)
                }
            } else {
                Text(el.text)
                    .font(screenFont(for: el))
                    .foregroundStyle(Color(el.textColor.nsColor))
                    .multilineTextAlignment(swiftUIAlignment(el.textAlignment))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment(el.textAlignment))
                    .padding(2)
            }
        }
    }

    // MARK: - Image

    @ViewBuilder
    private var imageView: some View {
        if let el = element.unwrap(as: ImageElement.self) {
            if let data = el.imageData, let nsImg = ImageImporter.nsImage(from: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: contentMode(el.contentMode))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.1)
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: min(element.frame.width, element.frame.height) * scale * 0.3))
                    .foregroundStyle(.gray)
                Text("Bild importieren")
                    .font(.system(size: 9))
                    .foregroundStyle(.gray)
            }
        }
        .border(Color.gray.opacity(0.3), width: 0.5)
    }

    // MARK: - QR Code

    @ViewBuilder
    private var qrView: some View {
        if let el = element.unwrap(as: QRCodeElement.self) {
            let sizePx = element.frame.width * scale
            if let cgImg = BarcodeGenerator.qrCode(
                payload: el.payload.isEmpty ? " " : el.payload,
                correctionLevel: el.correctionLevel,
                size: sizePx
            ) {
                Image(cgImg, scale: 1.0, label: Text("QR-Code"))
                    .resizable()
                    .interpolation(.none)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                qrPlaceholder
            }
        }
    }

    private var qrPlaceholder: some View {
        ZStack {
            Color.white
            Image(systemName: "qrcode").font(.system(size: 20)).foregroundStyle(.black)
        }
    }

    // MARK: - Barcode

    @ViewBuilder
    private var barcodeView: some View {
        if let el = element.unwrap(as: BarcodeElement.self) {
            let w = element.frame.width  * scale
            let h = element.frame.height * scale
            VStack(spacing: 2) {
                let codeH = el.showHumanReadable ? h * 0.82 : h
                if let cgImg = BarcodeGenerator.generate(
                    for: el,
                    size: CGSize(width: w, height: codeH)
                ) {
                    Image(cgImg, scale: 1.0, label: Text("Barcode"))
                        .resizable()
                        .interpolation(.none)
                        .frame(width: w, height: codeH)
                } else {
                    barcodePlaceholder(width: w, height: codeH)
                }
                if el.showHumanReadable {
                    Text(el.payload)
                        .font(.system(size: max(6, h * 0.12)).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }

    private func barcodePlaceholder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.white
            Image(systemName: "barcode").font(.system(size: min(width, height) * 0.5)).foregroundStyle(.black)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Line

    @ViewBuilder
    private var lineView: some View {
        if let el = element.unwrap(as: LineElement.self) {
            let lw = max(0.5, el.lineWidth * scale)
            if el.orientation == .horizontal {
                Rectangle()
                    .fill(Color(el.lineColor.nsColor))
                    .frame(maxWidth: .infinity, maxHeight: lw)
            } else {
                Rectangle()
                    .fill(Color(el.lineColor.nsColor))
                    .frame(maxWidth: lw, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func screenFont(for el: TextElement) -> Font {
        let ptSize = max(6, el.fontSize * scale * 0.6)
        var font = Font.custom(el.fontName, size: ptSize)
        if el.isBold && el.isItalic { font = font.bold().italic() }
        else if el.isBold            { font = font.bold() }
        else if el.isItalic          { font = font.italic() }
        return font
    }

    private func swiftUIAlignment(_ opt: TextAlignmentOption) -> TextAlignment {
        switch opt {
        case .left:      return .leading
        case .center:    return .center
        case .right:     return .trailing
        case .justified: return .leading
        }
    }

    private func frameAlignment(_ opt: TextAlignmentOption) -> Alignment {
        switch opt {
        case .left:      return .topLeading
        case .center:    return .top
        case .right:     return .topTrailing
        case .justified: return .topLeading
        }
    }

    private func contentMode(_ mode: ImageContentMode) -> ContentMode {
        switch mode {
        case .fit:     return .fit
        case .fill:    return .fill
        case .stretch: return .fill
        }
    }
}

// MARK: - InlineTextEditor

/// NSViewRepresentable that puts a focused NSTextView inside the element frame.
struct InlineTextEditor: NSViewRepresentable {

    var text: String
    let fontSize: CGFloat
    let fontName: String
    let isBold: Bool
    let isItalic: Bool
    let alignment: TextAlignmentOption
    let textColor: CodableColor
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isFieldEditor = false
        textView.font = resolvedFont()
        textView.textColor = textColor.nsColor
        textView.alignment = alignment.nsAlignment
        textView.string = text
        textView.selectAll(nil)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let tv = scrollView.documentView as! NSTextView
        if tv.string != text { tv.string = text }
        tv.font = resolvedFont()
        tv.textColor = textColor.nsColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCommit: onCommit) }

    private func resolvedFont() -> NSFont {
        var traits: NSFontTraitMask = []
        if isBold   { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }
        if let font = NSFontManager.shared.font(withFamily: fontName, traits: traits, weight: 5, size: fontSize) {
            return font
        }
        return .systemFont(ofSize: fontSize)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let onCommit: (String) -> Void
        init(onCommit: @escaping (String) -> Void) { self.onCommit = onCommit }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            onCommit(tv.string)
        }
    }
}
