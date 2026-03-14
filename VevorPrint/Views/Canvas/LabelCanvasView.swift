/// LabelCanvasView.swift
/// The main label design canvas. Renders the label boundary and a grid overlay.
/// Interactive elements (drag, resize handles) are added in Phase 3.

import SwiftUI

// MARK: - LabelCanvasView

struct LabelCanvasView: View {

    // MARK: - Environment

    @Environment(AppSettings.self) private var appSettings
    @Environment(LabelViewModel.self) private var labelVM

    // MARK: - Constants

    private let canvasBackground = Color(nsColor: .windowBackgroundColor)
    private let labelBackground  = Color.white
    private let shadowRadius: CGFloat = 8

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    canvasBackground
                        .ignoresSafeArea()

                    labelSurface
                        .padding(40)
                }
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height
                )
            }
            .background(canvasBackground)
        }
    }

    // MARK: - Label Surface

    private var labelSurface: some View {
        let zoom    = appSettings.canvasZoom
        let widthPt  = mmToPt(labelVM.labelSize.widthMM) * zoom
        let heightPt = mmToPt(labelVM.labelSize.heightMM) * zoom

        return ZStack {
            // White label paper
            Rectangle()
                .fill(labelBackground)
                .frame(width: widthPt, height: heightPt)
                .shadow(color: .black.opacity(0.2), radius: shadowRadius, x: 2, y: 2)

            // Grid overlay
            if appSettings.gridSizeMM > 0 {
                GridOverlay(
                    gridSizeMM: appSettings.gridSizeMM,
                    zoom: zoom,
                    labelWidthPt: widthPt,
                    labelHeightPt: heightPt
                )
            }

            // Label boundary
            Rectangle()
                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)
                .frame(width: widthPt, height: heightPt)

            // Placeholder text
            if true { // replace with `labelVM.elements.isEmpty` in Phase 3
                emptyCanvasHint
                    .frame(width: widthPt, height: heightPt)
            }
        }
        .frame(width: widthPt, height: heightPt)
        .clipped()
    }

    // MARK: - Empty Canvas Hint

    private var emptyCanvasHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Element aus der linken Sidebar hinzufügen")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    /// Convert millimetres to points (72 pt/inch).
    private func mmToPt(_ mm: Double) -> CGFloat {
        CGFloat(mm) / 25.4 * 72.0
    }
}

// MARK: - GridOverlay

/// Draws a dot-grid over the canvas surface.
private struct GridOverlay: View {

    let gridSizeMM: Double
    let zoom: Double
    let labelWidthPt: CGFloat
    let labelHeightPt: CGFloat

    var body: some View {
        Canvas { context, size in
            let stepPt = CGFloat(gridSizeMM) / 25.4 * 72.0 * zoom
            guard stepPt > 4 else { return }
            var x = stepPt
            while x < size.width {
                var y = stepPt
                while y < size.height {
                    let rect = CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)
                    context.fill(Path(ellipseIn: rect), with: .color(.gray.opacity(0.35)))
                    y += stepPt
                }
                x += stepPt
            }
        }
        .frame(width: labelWidthPt, height: labelHeightPt)
        .allowsHitTesting(false)
    }
}

#Preview {
    LabelCanvasView()
        .environment(AppSettings())
        .environment(LabelViewModel())
        .frame(width: 700, height: 500)
}
