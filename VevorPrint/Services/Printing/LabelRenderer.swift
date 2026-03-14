/// LabelRenderer.swift
/// Off-screen rendering of all label elements into a CGImage at print DPI.
///
/// Uses SwiftUI's `ImageRenderer` to composite `ElementView` instances at the
/// target pixel scale, so rendering logic is shared with the on-screen canvas.
///
/// Usage:
/// ```swift
/// let image = await LabelRenderer.render(elements: labelVM.sortedElements,
///                                        labelSize: labelVM.labelSize,
///                                        dpi: 203)
/// ```

import SwiftUI
import CoreGraphics

// MARK: - LabelRenderer

@MainActor
enum LabelRenderer {

    // MARK: - Public API

    /// Render all elements into a CGImage at the given DPI.
    ///
    /// - Parameters:
    ///   - elements: Sorted (by zIndex) array of label elements, all frames in mm.
    ///   - labelSize: Label dimensions in mm.
    ///   - dpi: Print resolution (203 or 300 dpi typical for thermal printers).
    /// - Returns: CGImage at `dpi` resolution, or `nil` on failure.
    static func render(
        elements: [AnyLabelElement],
        labelSize: LabelSize,
        dpi: CGFloat
    ) -> CGImage? {
        // pixels per mm at target DPI
        let scale = dpi / 25.4
        let widthPx  = labelSize.widthMM  * scale
        let heightPx = labelSize.heightMM * scale

        let content = renderContent(
            elements: elements,
            scale: scale,
            widthPx: widthPx,
            heightPx: heightPx
        )

        let renderer = ImageRenderer(content: content)
        // ImageRenderer.scale is points-per-logical-pixel.
        // We pass all sizes already in physical pixels, so scale = 1.
        renderer.scale = 1.0
        return renderer.cgImage
    }

    /// Render a thumbnail at reduced size (96 dpi) for UI previews.
    ///
    /// - Parameters:
    ///   - elements: Label elements.
    ///   - labelSize: Label dimensions in mm.
    ///   - maxEdge: Maximum width or height in pixels for the thumbnail.
    /// - Returns: CGImage thumbnail.
    static func thumbnail(
        elements: [AnyLabelElement],
        labelSize: LabelSize,
        maxEdge: CGFloat = 256
    ) -> CGImage? {
        let baseScale: CGFloat = 96.0 / 25.4
        let w = labelSize.widthMM  * baseScale
        let h = labelSize.heightMM * baseScale
        let factor = min(maxEdge / max(w, h, 1), 1.0)
        let scale = baseScale * factor
        let widthPx  = labelSize.widthMM  * scale
        let heightPx = labelSize.heightMM * scale

        let content = renderContent(
            elements: elements,
            scale: scale,
            widthPx: widthPx,
            heightPx: heightPx
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1.0
        return renderer.cgImage
    }

    // MARK: - Private

    /// Build the SwiftUI content tree used by ImageRenderer.
    @ViewBuilder
    private static func renderContent(
        elements: [AnyLabelElement],
        scale: CGFloat,
        widthPx: CGFloat,
        heightPx: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // White label background
            Color.white
                .frame(width: widthPx, height: heightPx)

            // Elements in z-order
            ForEach(elements.sorted { $0.zIndex < $1.zIndex }) { el in
                let frameW = el.frame.width  * scale
                let frameH = el.frame.height * scale
                let midX   = el.frame.origin.x * scale + frameW / 2
                let midY   = el.frame.origin.y * scale + frameH / 2

                ElementView(element: el, scale: scale)
                    .frame(width: frameW, height: frameH)
                    .rotationEffect(.degrees(el.rotation))
                    .position(x: midX, y: midY)
            }
        }
        .frame(width: widthPx, height: heightPx)
    }
}
