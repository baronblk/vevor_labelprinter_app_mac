/// LabelCanvasView.swift
/// Interactive three-layer canvas:
///   1. SwiftUI Canvas — static element rendering (dot grid + element placeholders)
///   2. ForEach overlay — transparent hit-test targets with DragGesture per element
///   3. SelectionHandleView — 8 resize handles + 1 rotation handle for selection
///
/// Coordinate system: element frames are in **mm**; canvas converts to screen
/// points using `ptPerMM * zoom`.

import SwiftUI

// MARK: - LabelCanvasView

struct LabelCanvasView: View {

    // MARK: - Environment

    @Environment(AppSettings.self)    private var appSettings
    @Environment(LabelViewModel.self) private var labelVM

    // MARK: - Constants

    /// Screen points per mm at 1x zoom (96 dpi baseline).
    private let ptPerMM: CGFloat = 96.0 / 25.4

    // MARK: - Drag State

    @State private var dragStartFrames: [UUID: CGRect] = [:]

    // MARK: - Computed

    private var zoom: CGFloat { CGFloat(appSettings.canvasZoom) }
    private var scale: CGFloat { ptPerMM * zoom }
    private var labelWidthPt:  CGFloat { labelVM.labelSize.widthMM  * scale }
    private var labelHeightPt: CGFloat { labelVM.labelSize.heightMM * scale }

    // MARK: - Body

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                canvasBackground
                elementHitLayer
                if labelVM.hasSelection { selectionLayer }
            }
            .frame(width: labelWidthPt, height: labelHeightPt)
            .padding(48)
            .coordinateSpace(name: "canvas")
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .overlay(alignment: .topLeading) {
            if appSettings.showRulers { rulerOverlay }
        }
        .onTapGesture { labelVM.clearSelection() }
        .focusable()
        .onKeyPress(.delete)    { labelVM.deleteSelection(); return .handled }
        .onKeyPress(.escape)    { labelVM.clearSelection();  return .handled }
    }

    // MARK: - Canvas Background (static SwiftUI Canvas)

    private var canvasBackground: some View {
        Canvas { ctx, size in
            // White label surface
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

            // Dot grid
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

            // Elements (Phase 4 replaces these placeholders with real renderers)
            for el in labelVM.sortedElements {
                renderElement(el, in: ctx, size: size)
            }
        }
        .frame(width: labelWidthPt, height: labelHeightPt)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 2)
    }

    // MARK: - Element Rendering (Canvas pass)

    private func renderElement(_ el: AnyLabelElement, in ctx: GraphicsContext, size: CGSize) {
        let rect = frameInPt(el)
        let isSelected = labelVM.selectedIDs.contains(el.id)

        ctx.drawLayer { layerCtx in
            if el.rotation != 0 {
                let c = CGPoint(x: rect.midX, y: rect.midY)
                layerCtx.transform = CGAffineTransform(translationX: c.x, y: c.y)
                    .rotated(by: el.rotation * .pi / 180)
                    .translatedBy(x: -c.x, y: -c.y)
            }
            _ = isSelected   // referenced to silence warning; highlight drawn in SelectionHandleView

            switch el.elementType {
            case .text:
                guard let t = el.unwrap(as: TextElement.self) else { break }
                ctx.stroke(Path(rect), with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
                let ptSize = max(8, t.fontSize * zoom * 0.8)
                ctx.draw(
                    Text(t.text)
                        .font(.system(size: ptSize))
                        .foregroundStyle(Color(t.textColor.nsColor)),
                    in: rect
                )
            case .image:
                ctx.fill(Path(rect), with: .color(.gray.opacity(0.1)))
                ctx.stroke(Path(rect), with: .color(.gray.opacity(0.35)), lineWidth: 0.5)
                let imgSize = min(rect.width, rect.height) * 0.35
                ctx.draw(
                    Text(Image(systemName: "photo")).font(.system(size: imgSize)).foregroundStyle(.gray),
                    in: rect
                )
            case .qrCode:
                ctx.fill(Path(rect), with: .color(.white))
                ctx.stroke(Path(rect), with: .color(.gray.opacity(0.35)), lineWidth: 0.5)
                let qrSize = min(rect.width, rect.height) * 0.55
                ctx.draw(
                    Text(Image(systemName: "qrcode")).font(.system(size: qrSize)).foregroundStyle(.black),
                    in: rect
                )
            case .barcode:
                ctx.fill(Path(rect), with: .color(.white))
                ctx.stroke(Path(rect), with: .color(.gray.opacity(0.35)), lineWidth: 0.5)
                let bars = 22
                let bw = rect.width / CGFloat(bars * 2)
                for i in stride(from: 0, to: bars, by: 1) {
                    let barRect = CGRect(x: rect.minX + CGFloat(i * 2) * bw, y: rect.minY,
                                        width: bw, height: rect.height * 0.82)
                    ctx.fill(Path(barRect), with: .color(.black))
                }
            case .line:
                guard let l = el.unwrap(as: LineElement.self) else { break }
                let lw = max(1, l.lineWidth * scale)
                let midY = rect.midY
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: midY))
                ctx.stroke(path, with: .color(Color(l.lineColor.nsColor)), lineWidth: lw)
            }
        }
    }

    // MARK: - Hit Layer (transparent gesture targets)

    private var elementHitLayer: some View {
        ZStack {
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
            .onTapGesture {
                let addToSel = NSEvent.modifierFlags.contains(.shift)
                labelVM.select(id: el.id, addToSelection: addToSel)
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("canvas"))
                    .onChanged { [id = el.id] value in
                        if !labelVM.selectedIDs.contains(id) {
                            labelVM.select(id: id)
                        }
                        if !labelVM.isInteracting {
                            labelVM.isInteracting = true
                            dragStartFrames = Dictionary(
                                uniqueKeysWithValues: labelVM.selectedElements
                                    .map { ($0.id, $0.frame) }
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
        var deltaMM = CGSize(
            width:  translation.width  / scale,
            height: translation.height / scale
        )
        let gridMM = CGFloat(appSettings.gridSizeMM)
        if gridMM > 0 {
            deltaMM.width  = (deltaMM.width  / gridMM).rounded() * gridMM
            deltaMM.height = (deltaMM.height / gridMM).rounded() * gridMM
        }
        for id in labelVM.selectedIDs {
            guard let idx = labelVM.elements.firstIndex(where: { $0.id == id }),
                  let start = dragStartFrames[id] else { continue }
            var newX = start.origin.x + deltaMM.width
            var newY = start.origin.y + deltaMM.height
            let w = labelVM.elements[idx].frame.width
            let h = labelVM.elements[idx].frame.height
            newX = max(0, min(newX, labelVM.labelSize.widthMM  - w))
            newY = max(0, min(newY, labelVM.labelSize.heightMM - h))
            labelVM.elements[idx].frame.origin = CGPoint(x: newX, y: newY)
        }
    }

    // MARK: - Selection Layer

    @ViewBuilder
    private var selectionLayer: some View {
        ForEach(labelVM.selectedElements) { el in
            SelectionHandleView(
                elementFrame: frameInPt(el),
                onResizeDrag: { handle, delta in resize(el: el, handle: handle, delta: delta) },
                onResizeEnd:  { labelVM.commitMove() },
                onRotateDrag: { angle in rotate(el: el, by: angle) },
                onRotateEnd:  { labelVM.commitMove() }
            )
        }
    }

    // MARK: - Resize

    private func resize(el: AnyLabelElement, handle: HandlePosition, delta: CGSize) {
        guard let idx = labelVM.elements.firstIndex(where: { $0.id == el.id }) else { return }
        let dx = delta.width  / scale
        let dy = delta.height / scale
        var f  = labelVM.elements[idx].frame
        let minMM: CGFloat = 2.0

        switch handle {
        case .topLeft:
            f.origin.x += dx; f.size.width  -= dx
            f.origin.y += dy; f.size.height -= dy
        case .top:
            f.origin.y += dy; f.size.height -= dy
        case .topRight:
            f.size.width  += dx
            f.origin.y    += dy; f.size.height -= dy
        case .left:
            f.origin.x += dx; f.size.width -= dx
        case .right:
            f.size.width += dx
        case .bottomLeft:
            f.origin.x += dx; f.size.width  -= dx
            f.size.height += dy
        case .bottom:
            f.size.height += dy
        case .bottomRight:
            f.size.width  += dx
            f.size.height += dy
        case .rotation:
            break
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

    // MARK: - Helpers

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
