/// PropertiesSidebarView.swift
/// Right sidebar — shows context-sensitive property editors depending on
/// which element type is currently selected. Multiple selections show a
/// generic transform panel.

import SwiftUI

// MARK: - PropertiesSidebarView

struct PropertiesSidebarView: View {

    // MARK: - Environment

    @Environment(LabelViewModel.self) private var labelVM

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    propertiesContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Eigenschaften")
                .font(.headline)
            Spacer()
            if labelVM.hasSelection {
                Button(action: { labelVM.deleteSelection() }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Element loeschen")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Content routing

    @ViewBuilder
    private var propertiesContent: some View {
        if labelVM.selectedElements.count == 0 {
            noSelectionView
        } else if labelVM.selectedElements.count > 1 {
            multiSelectionView
        } else if let el = labelVM.firstSelected {
            switch el.elementType {
            case .text:    TextPropertiesPanel(element: el)
            case .image:   ImagePropertiesPanel(element: el)
            case .qrCode:  QRPropertiesPanel(element: el)
            case .barcode: BarcodePropertiesPanel(element: el)
            case .line:    LinePropertiesPanel(element: el)
            }
            GeometryPanel(element: el)
        }
    }

    // MARK: - Empty State

    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
                .padding(.top, 32)
            Text("Kein Element ausgewaehlt")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Klicke ein Element an oder fuege eines ueber die linke Seitenleiste hinzu.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    private var multiSelectionView: some View {
        Text("\(labelVM.selectedElements.count) Elemente ausgewaehlt")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - GeometryPanel

private struct GeometryPanel: View {

    @Environment(LabelViewModel.self) private var labelVM
    let element: AnyLabelElement

    @State private var xStr   = ""
    @State private var yStr   = ""
    @State private var wStr   = ""
    @State private var hStr   = ""
    @State private var rotStr = ""

    var body: some View {
        SidebarSection(title: "Geometrie") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    numField("X (mm)", text: $xStr) { applyGeometry(x: Double(xStr)) }
                    numField("Y (mm)", text: $yStr) { applyGeometry(y: Double(yStr)) }
                }
                HStack(spacing: 8) {
                    numField("B (mm)", text: $wStr) { applyGeometry(w: Double(wStr)) }
                    numField("H (mm)", text: $hStr) { applyGeometry(h: Double(hStr)) }
                }
                numField("Rot. (°)", text: $rotStr) { applyGeometry(rot: Double(rotStr)) }
            }
        }
        .onAppear  { syncFields() }
        .onChange(of: element.frame)    { syncFields() }
        .onChange(of: element.rotation) { syncFields() }
    }

    private func syncFields() {
        xStr   = String(format: "%.1f", element.frame.origin.x)
        yStr   = String(format: "%.1f", element.frame.origin.y)
        wStr   = String(format: "%.1f", element.frame.width)
        hStr   = String(format: "%.1f", element.frame.height)
        rotStr = String(format: "%.0f", element.rotation)
    }

    private func applyGeometry(x: Double? = nil, y: Double? = nil,
                                w: Double? = nil, h: Double? = nil,
                                rot: Double? = nil) {
        guard let idx = labelVM.elements.firstIndex(where: { $0.id == element.id }) else { return }
        var el = labelVM.elements[idx]
        if let v = x   { el.frame.origin.x    = CGFloat(v) }
        if let v = y   { el.frame.origin.y    = CGFloat(v) }
        if let v = w   { el.frame.size.width  = CGFloat(max(1, v)) }
        if let v = h   { el.frame.size.height = CGFloat(max(1, v)) }
        if let v = rot { el.rotation           = v }
        labelVM.updateElement(el, undoName: "Geometrie")
    }

    private func numField(_ label: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCommit)
        }
    }
}

// MARK: - TextPropertiesPanel

private struct TextPropertiesPanel: View {

    @Environment(LabelViewModel.self) private var labelVM
    let element: AnyLabelElement
    private var el: TextElement? { element.unwrap(as: TextElement.self) }

    var body: some View {
        SidebarSection(title: "Text") {
            if let el {
                VStack(alignment: .leading, spacing: 10) {
                    // Content
                    TextEditor(text: Binding(
                        get: { el.text },
                        set: { update(text: $0) }
                    ))
                    .font(.system(size: 12))
                    .frame(minHeight: 60)
                    .border(Color(nsColor: .separatorColor), width: 0.5)

                    // Font family
                    Picker("Schrift", selection: Binding(
                        get: { el.fontName },
                        set: { update(fontName: $0) }
                    )) {
                        ForEach(["Helvetica","Arial","Courier","Times New Roman","Georgia"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }

                    // Size slider
                    HStack {
                        Text("Groesse (pt)").font(.caption).foregroundStyle(.secondary)
                        Slider(
                            value: Binding(get: { el.fontSize }, set: { update(fontSize: $0) }),
                            in: 6...72, step: 1
                        )
                        Text("\(Int(el.fontSize))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 28)
                    }

                    // Bold / Italic
                    HStack(spacing: 12) {
                        Toggle("Fett", isOn: Binding(
                            get: { el.isBold }, set: { update(bold: $0) }
                        )).toggleStyle(.checkbox)
                        Toggle("Kursiv", isOn: Binding(
                            get: { el.isItalic }, set: { update(italic: $0) }
                        )).toggleStyle(.checkbox)
                    }

                    // Alignment
                    Picker("Ausrichtung", selection: Binding(
                        get: { el.textAlignment },
                        set: { update(alignment: $0) }
                    )) {
                        ForEach(TextAlignmentOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }.pickerStyle(.segmented)

                    // Color
                    ColorPicker("Farbe", selection: Binding(
                        get: { Color(el.textColor.nsColor) },
                        set: { update(color: CodableColor(nsColor: NSColor($0))) }
                    ))
                }
            }
        }
    }

    private func update(text: String? = nil, fontName: String? = nil, fontSize: Double? = nil,
                        bold: Bool? = nil, italic: Bool? = nil,
                        alignment: TextAlignmentOption? = nil, color: CodableColor? = nil) {
        guard var u = el else { return }
        if let v = text      { u.text          = v }
        if let v = fontName  { u.fontName       = v }
        if let v = fontSize  { u.fontSize       = v }
        if let v = bold      { u.isBold         = v }
        if let v = italic    { u.isItalic       = v }
        if let v = alignment { u.textAlignment  = v }
        if let v = color     { u.textColor      = v }
        labelVM.updateElement(AnyLabelElement(u), undoName: "Text bearbeiten")
    }
}

// MARK: - ImagePropertiesPanel

private struct ImagePropertiesPanel: View {

    @Environment(LabelViewModel.self) private var labelVM
    let element: AnyLabelElement
    private var el: ImageElement? { element.unwrap(as: ImageElement.self) }

    var body: some View {
        SidebarSection(title: "Bild") {
            if let el {
                VStack(alignment: .leading, spacing: 10) {
                    // Thumbnail
                    if let data = el.imageData, let img = ImageImporter.nsImage(from: data) {
                        Image(nsImage: img)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 80).frame(maxWidth: .infinity)
                    }
                    Button("Bild importieren...") { openPanel() }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)

                    Picker("Darstellung", selection: Binding(
                        get: { el.contentMode }, set: { update(contentMode: $0) }
                    )) {
                        Text("Einpassen").tag(ImageContentMode.fit)
                        Text("Fuellen").tag(ImageContentMode.fill)
                        Text("Strecken").tag(ImageContentMode.stretch)
                    }.pickerStyle(.segmented)
                }
            }
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data: Data = url.pathExtension.lowercased() == "pdf"
                ? try PDFImporter.importFirstPage(from: url)
                : try ImageImporter.importImage(from: url)
            update(imageData: data)
        } catch {}
    }

    private func update(imageData: Data? = nil, contentMode: ImageContentMode? = nil) {
        guard var u = el else { return }
        if let v = imageData   { u.imageData   = v }
        if let v = contentMode { u.contentMode = v }
        labelVM.updateElement(AnyLabelElement(u), undoName: "Bild bearbeiten")
    }
}

// MARK: - QRPropertiesPanel

private struct QRPropertiesPanel: View {

    @Environment(LabelViewModel.self) private var labelVM
    let element: AnyLabelElement
    private var el: QRCodeElement? { element.unwrap(as: QRCodeElement.self) }

    var body: some View {
        SidebarSection(title: "QR-Code") {
            if let el {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inhalt").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: Binding(
                            get: { el.payload }, set: { update(payload: $0) }
                        ))
                        .font(.system(size: 11).monospaced())
                        .frame(minHeight: 50)
                        .border(Color(nsColor: .separatorColor), width: 0.5)
                    }
                    Picker("Fehlerkorrektur", selection: Binding(
                        get: { el.correctionLevel }, set: { update(level: $0) }
                    )) {
                        Text("L – Gering").tag(QRCorrectionLevel.low)
                        Text("M – Mittel").tag(QRCorrectionLevel.medium)
                        Text("Q – Hoch").tag(QRCorrectionLevel.quartile)
                        Text("H – Maximum").tag(QRCorrectionLevel.high)
                    }
                }
            }
        }
    }

    private func update(payload: String? = nil, level: QRCorrectionLevel? = nil) {
        guard var u = el else { return }
        if let v = payload { u.payload          = v }
        if let v = level   { u.correctionLevel  = v }
        labelVM.updateElement(AnyLabelElement(u), undoName: "QR-Code bearbeiten")
    }
}

// MARK: - BarcodePropertiesPanel

private struct BarcodePropertiesPanel: View {

    @Environment(LabelViewModel.self) private var labelVM
    let element: AnyLabelElement
    private var el: BarcodeElement? { element.unwrap(as: BarcodeElement.self) }

    var body: some View {
        SidebarSection(title: "Barcode") {
            if let el {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inhalt").font(.caption).foregroundStyle(.secondary)
                        TextField("", text: Binding(
                            get: { el.payload }, set: { update(payload: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11).monospaced())
                    }
                    Picker("Typ", selection: Binding(
                        get: { el.barcodeType }, set: { update(type: $0) }
                    )) {
                        ForEach(BarcodeType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Klartext anzeigen", isOn: Binding(
                        get: { el.showHumanReadable }, set: { update(showHR: $0) }
                    )).toggleStyle(.checkbox)
                }
            }
        }
    }

    private func update(payload: String? = nil, type: BarcodeType? = nil, showHR: Bool? = nil) {
        guard var u = el else { return }
        if let v = payload { u.payload           = v }
        if let v = type    { u.barcodeType       = v }
        if let v = showHR  { u.showHumanReadable = v }
        labelVM.updateElement(AnyLabelElement(u), undoName: "Barcode bearbeiten")
    }
}

// MARK: - LinePropertiesPanel

private struct LinePropertiesPanel: View {

    @Environment(LabelViewModel.self) private var labelVM
    let element: AnyLabelElement
    private var el: LineElement? { element.unwrap(as: LineElement.self) }

    var body: some View {
        SidebarSection(title: "Linie") {
            if let el {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Ausrichtung", selection: Binding(
                        get: { el.orientation }, set: { update(orientation: $0) }
                    )) {
                        Text("Horizontal").tag(LineOrientation.horizontal)
                        Text("Vertikal").tag(LineOrientation.vertical)
                    }.pickerStyle(.segmented)

                    HStack {
                        Text("Staerke (mm)").font(.caption).foregroundStyle(.secondary)
                        Slider(
                            value: Binding(get: { el.lineWidth }, set: { update(width: $0) }),
                            in: 0.1...5, step: 0.1
                        )
                        Text(String(format: "%.1f", el.lineWidth))
                            .font(.caption.monospacedDigit()).frame(width: 32)
                    }

                    ColorPicker("Farbe", selection: Binding(
                        get: { Color(el.lineColor.nsColor) },
                        set: { update(color: CodableColor(nsColor: NSColor($0))) }
                    ))
                }
            }
        }
    }

    private func update(orientation: LineOrientation? = nil, width: Double? = nil, color: CodableColor? = nil) {
        guard var u = el else { return }
        if let v = orientation { u.orientation = v }
        if let v = width       { u.lineWidth   = v }
        if let v = color       { u.lineColor   = v }
        labelVM.updateElement(AnyLabelElement(u), undoName: "Linie bearbeiten")
    }
}

// MARK: - SidebarSection

struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal).padding(.vertical, 8)
            Divider()
            content().padding(.horizontal).padding(.vertical, 10)
            Divider()
        }
    }
}

// MARK: - CodableColor + NSColor init

extension CodableColor {
    init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.init(red: Double(c.redComponent), green: Double(c.greenComponent),
                  blue: Double(c.blueComponent), alpha: Double(c.alphaComponent))
    }
}

#Preview {
    PropertiesSidebarView()
        .environment(LabelViewModel())
        .frame(width: 260, height: 600)
}
