/// LabelCanvasView.swift
/// Interactive four-layer canvas:
///   1. Canvas background — white label surface + dot grid
///   2. ElementView layer — real rendered elements (text, QR, barcode, image, line)
///   3. Hit-test layer — transparent DragGesture targets
///   4. SelectionHandleView — resize + rotation handles
///
/// Coordinate system: element frames are in **mm**; canvas converts to screen
/// points via `ptPerMM * zoom`.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - LabelCanvasView

struct LabelCanvasView: View {

    // MARK: - Environment

    @Environment(AppSettings.self)    private var appSettings
    @Environment(LabelViewModel.self) private var labelVM

    // MARK: - Constants

    /// Screen points per mm at 1× zoom (96 dpi baseline).
    private let ptPerMM: CGFloat = 96.0 / 25.4

    // MARK: - State

    @State private var dragStartFrames: [UUID: CGRect] = [:]
    @State private var resizeStartFrames: [UUID: CGRect] = [:]
    @State private var editingElementID: UUID? = nil
    @State private var isDropTargeted = false

    // MARK: - Computed

    private var zoom: CGFloat    { CGFloat(appSettings.canvasZoom) }
    private var scale: CGFloat   { ptPerMM * zoom }
    private var labelWidthPt:  CGFloat { labelVM.labelSize.widthMM  * scale }
    private var labelHeightPt: CGFloat { labelVM.labelSize.heightMM * scale }

    // MARK: - Body

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                gridBackground
                elementLayer
                hitLayer
                if labelVM.hasSelection { selectionLayer }
            }
            .frame(width: labelWidthPt, height: labelHeightPt)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .padding(48)
            .coordinateSpace(name: "canvas")
            .onTapGesture {
                editingElementID = nil
                labelVM.clearSelection()
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .overlay(alignment: .topLeading) {
            if appSettings.showRulers { rulerOverlay }
        }
        .focusable()
        .onKeyPress(.delete)  { labelVM.deleteSelection(); return .handled }
        .onKeyPress(.escape)  { editingElementID = nil; labelVM.clearSelection(); return .handled }
        .onKeyPress(.return)  { editingElementID = nil; return .handled }
        // Image drag & drop
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(urls: urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    // MARK: - Layer 1: Grid Background

    private var gridBackground: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let gridMM = CGFloat(appSettings.gridSizeMM)
            if gridMM > 0 {
                let spacing = gridMM * scale
                var x: CGFloat = 0
                while x <= size.width {
                    var y: CGFloat = 0
                    while y <= size.height {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - 0.6, y: y - 0.6, width: 1.2, height: 1.2)),
                            with: .color(.gray.opacity(0.22))
                        )
                        y += spacing
                    }
                    x += spacing
                }
            }
        }
        .frame(width: labelWidthPt, height: labelHeightPt)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)
    }

    // MARK: - Layer 2: Element Rendering

    private var elementLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(labelVM.sortedElements) { el in
                let rect = frameInPt(el)
                let isEditing = editingElementID == el.id
                ElementView(
                    element: el,
                    scale: scale,
                    isEditing: isEditing,
                    onEditCommit: { newText in
                        applyTextEdit(id: el.id, newText: newText)
                    }
                )
                .frame(width: rect.width, height: rect.height)
                .rotationEffect(.degrees(el.rotation))
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)   // gestures handled in hit layer
            }
        }
    }

    // MARK: - Layer 3: Hit Targets

    private var hitLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(labelVM.sortedElements) { el in
                hitTarget(for: el)
            }
        }
    }

    @ViewBuilder
    private func hitTarget(for el: AnyLabelElement) -> some View {
        let rect = frameInPt(el)
        Color.clear
            .contentShape(Rectangle())
            .frame(width: max(8, rect.width), height: max(8, rect.height))
            .rotationEffect(.degrees(el.rotation))
            .position(x: rect.midX, y: rect.midY)
            .accessibilityLabel(accessibilityLabel(for: el))
            .accessibilityHint(el.elementType == .text ? "Doppeltippen zum Bearbeiten" : "Tippen zum Auswaehlen")
            .accessibilityAddTraits(.isButton)
            .onTapGesture(count: 2) {
                // Double-click → start inline editing (text only)
                if el.elementType == .text {
                    labelVM.select(id: el.id)
                    editingElementID = el.id
                }
            }
            .onTapGesture(count: 1) {
                editingElementID = nil
                let addToSel = NSEvent.modifierFlags.contains(.shift)
                labelVM.select(id: el.id, addToSelection: addToSel)
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("canvas"))
                    .onChanged { [id = el.id] value in
                        if !labelVM.selectedIDs.contains(id) { labelVM.select(id: id) }
                        if !labelVM.isInteracting {
                            labelVM.isInteracting = true
                            dragStartFrames = Dictionary(
                                uniqueKeysWithValues: labelVM.selectedElements.map { ($0.id, $0.frame) }
                            )
                        }
                        applyDrag(translation: value.translation)
                    }
                    .onEnded { _ in
                        labelVM.isInteracting = false
                        labelVM.commitMove()
                        dragStartFrames = [:]
                    }
            )
    }

    private func applyDrag(translation: CGSize) {
        var deltaMM = CGSize(width: translation.width / scale, height: translation.height / scale)
        let gridMM = CGFloat(appSettings.gridSizeMM)
        if gridMM > 0 {
            deltaMM.width  = (deltaMM.width  / gridMM).rounded() * gridMM
            deltaMM.height = (deltaMM.height / gridMM).rounded() * gridMM
        }
        for id in labelVM.selectedIDs {
            guard let idx = labelVM.elements.firstIndex(where: { $0.id == id }),
                  let start = dragStartFrames[id] else { continue }
            let w = labelVM.elements[idx].frame.width
            let h = labelVM.elements[idx].frame.height
            let newX = max(0, min(start.origin.x + deltaMM.width,  labelVM.labelSize.widthMM  - w))
            let newY = max(0, min(start.origin.y + deltaMM.height, labelVM.labelSize.heightMM - h))
            labelVM.elements[idx].frame.origin = CGPoint(x: newX, y: newY)
        }
    }

    // MARK: - Layer 4: Selection Handles

    @ViewBuilder
    private var selectionLayer: some View {
        ForEach(labelVM.selectedElements) { el in
            SelectionHandleView(
                elementFrame: frameInPt(el),
                onResizeDrag: { handle, delta in resize(el: el, handle: handle, delta: delta) },
                onResizeEnd:  { [id = el.id] in
                    resizeStartFrames.removeValue(forKey: id)
                    labelVM.isInteracting = false
                    labelVM.commitMove()
                },
                onRotateDrag: { angle in rotate(el: el, by: angle) },
                onRotateEnd:  { labelVM.commitMove() }
            )
        }
    }

    // MARK: - Resize

    private func resize(el: AnyLabelElement, handle: HandlePosition, delta: CGSize) {
        guard let idx = labelVM.elements.firstIndex(where: { $0.id == el.id }) else { return }

        // Capture start frame on first call of this drag gesture
        if resizeStartFrames[el.id] == nil {
            resizeStartFrames[el.id] = labelVM.elements[idx].frame
            labelVM.isInteracting = true
        }
        guard let startFrame = resizeStartFrames[el.id] else { return }

        let dx = delta.width / scale
        let dy = delta.height / scale
        var f = startFrame  // ALWAYS use start frame, not current frame
        let minMM: CGFloat = 2.0

        switch handle {
        case .topLeft:     f.origin.x += dx; f.size.width -= dx; f.origin.y += dy; f.size.height -= dy
        case .top:         f.origin.y += dy; f.size.height -= dy
        case .topRight:    f.size.width += dx; f.origin.y += dy; f.size.height -= dy
        case .left:        f.origin.x += dx; f.size.width -= dx
        case .right:       f.size.width += dx
        case .bottomLeft:  f.origin.x += dx; f.size.width -= dx; f.size.height += dy
        case .bottom:      f.size.height += dy
        case .bottomRight: f.size.width += dx; f.size.height += dy
        case .rotation:    break
        }
        f.size.width  = max(minMM, f.size.width)
        f.size.height = max(minMM, f.size.height)
        labelVM.elements[idx].frame = f
    }

    // MARK: - Rotation

    private func rotate(el: AnyLabelElement, by angle: Double) {
        guard let idx = labelVM.elements.firstIndex(where: { $0.id == el.id }) else { return }
        labelVM.elements[idx].rotation = (labelVM.elements[idx].rotation + angle)
            .truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Inline Text Edit

    private func applyTextEdit(id: UUID, newText: String) {
        guard let idx = labelVM.elements.firstIndex(where: { $0.id == id }),
              var el = labelVM.elements[idx].unwrap(as: TextElement.self) else { return }
        el.text = newText
        labelVM.elements[idx] = AnyLabelElement(el)
    }

    // MARK: - Image Drop

    private func handleDrop(urls: [URL]) {
        guard let url = urls.first else { return }
        let ext = url.pathExtension.lowercased()
        do {
            let data: Data
            if ext == "pdf" {
                data = try PDFImporter.importFirstPage(from: url)
            } else {
                data = try ImageImporter.importImage(from: url)
            }
            var el = ImageElement()
            let size = min(labelVM.labelSize.widthMM, labelVM.labelSize.heightMM) * 0.5
            el.frame = CGRect(
                x: (labelVM.labelSize.widthMM - size) / 2,
                y: (labelVM.labelSize.heightMM - size) / 2,
                width: size, height: size
            )
            el.imageData = data
            labelVM.addElement(AnyLabelElement(el))
        } catch {
            // Errors surfaced in Phase 7 via toast/alert system
        }
    }

    // MARK: - Helpers

    /// Human-readable accessibility label describing an element.
    private func accessibilityLabel(for el: AnyLabelElement) -> String {
        switch el.elementType {
        case .text:
            let text = el.unwrap(as: TextElement.self)?.text ?? ""
            return text.isEmpty ? "Leeres Textfeld" : "Text: \(text)"
        case .image:    return "Bild"
        case .qrCode:   return "QR-Code"
        case .barcode:  return "Barcode"
        case .line:     return "Linie"
        }
    }

    private func frameInPt(_ el: AnyLabelElement) -> CGRect {
        CGRect(
            x: el.frame.origin.x * scale,
            y: el.frame.origin.y * scale,
            width:  el.frame.width  * scale,
            height: el.frame.height * scale
        )
    }

    // MARK: - Ruler Overlay

    private var rulerOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                RulerCorner().frame(width: 20, height: 20)
                RulerView(
                    zoom: zoom, ptPerMM: ptPerMM,
                    labelSizeMM: CGSize(width: labelVM.labelSize.widthMM,
                                       height: labelVM.labelSize.heightMM),
                    isHorizontal: true
                )
            }
            HStack(spacing: 0) {
                RulerView(
                    zoom: zoom, ptPerMM: ptPerMM,
                    labelSizeMM: CGSize(width: labelVM.labelSize.widthMM,
                                       height: labelVM.labelSize.heightMM),
                    isHorizontal: false
                )
                Spacer()
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LabelCanvasView()
        .environment(AppSettings())
        .environment(LabelViewModel())
        .frame(width: 700, height: 500)
}
