/// SelectionHandleView.swift
/// Renders 8 resize handles + 1 rotation handle around a selected element.
/// The parent LabelCanvasView routes drag gestures from these handles.

import SwiftUI

// MARK: - HandlePosition

/// The 8 cardinal + ordinal resize handles, plus a rotation handle.
enum HandlePosition: CaseIterable {
    case topLeft, top, topRight
    case left,         right
    case bottomLeft, bottom, bottomRight
    case rotation   // above the top-centre handle

    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight: return .init()  // diagonal
        case .topRight, .bottomLeft: return .init()
        case .top, .bottom:          return .resizeUpDown
        case .left, .right:          return .resizeLeftRight
        case .rotation:              return .openHand
        }
    }
}

// MARK: - SelectionHandleView

struct SelectionHandleView: View {

    // MARK: - Input

    /// Frame of the selected element in canvas (screen-point) coordinates.
    let elementFrame: CGRect
    /// Called when the user drags a resize handle.
    /// Parameters: (HandlePosition, CGSize dragDelta)
    let onResizeDrag: (HandlePosition, CGSize) -> Void
    /// Called when the user finishes resizing.
    let onResizeEnd: () -> Void
    /// Called when the user drags the rotation handle.
    /// Parameter: angle delta in degrees.
    let onRotateDrag: (Double) -> Void
    /// Called when the user finishes rotating.
    let onRotateEnd: () -> Void

    // MARK: - Constants

    private let handleSize: CGFloat = 8
    private let rotationHandleOffset: CGFloat = 18

    // MARK: - Body

    var body: some View {
        ZStack {
            selectionBorder
            ForEach(HandlePosition.allCases, id: \.self) { position in
                handle(for: position)
            }
        }
    }

    // MARK: - Selection Border

    private var selectionBorder: some View {
        Rectangle()
            .strokeBorder(
                Color.accentColor,
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            )
            .frame(width: elementFrame.width, height: elementFrame.height)
            .position(x: elementFrame.midX, y: elementFrame.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Individual Handle

    @ViewBuilder
    private func handle(for position: HandlePosition) -> some View {
        let pt = handlePoint(position)
        let isRotation = position == .rotation

        Circle()
            .fill(isRotation ? Color.accentColor : Color.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            .position(pt)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("canvas"))
                    .onChanged { value in
                        if isRotation {
                            let centre = CGPoint(x: elementFrame.midX, y: elementFrame.midY)
                            let start  = CGPoint(x: value.startLocation.x, y: value.startLocation.y)
                            let end    = CGPoint(x: value.location.x,     y: value.location.y)
                            let angleDelta = angleBetween(centre: centre, from: start, to: end)
                            onRotateDrag(angleDelta)
                        } else {
                            onResizeDrag(position, value.translation)
                        }
                    }
                    .onEnded { _ in
                        if isRotation { onRotateEnd() } else { onResizeEnd() }
                    }
            )
    }

    // MARK: - Handle Positions

    private func handlePoint(_ position: HandlePosition) -> CGPoint {
        let f = elementFrame
        switch position {
        case .topLeft:     return CGPoint(x: f.minX, y: f.minY)
        case .top:         return CGPoint(x: f.midX, y: f.minY)
        case .topRight:    return CGPoint(x: f.maxX, y: f.minY)
        case .left:        return CGPoint(x: f.minX, y: f.midY)
        case .right:       return CGPoint(x: f.maxX, y: f.midY)
        case .bottomLeft:  return CGPoint(x: f.minX, y: f.maxY)
        case .bottom:      return CGPoint(x: f.midX, y: f.maxY)
        case .bottomRight: return CGPoint(x: f.maxX, y: f.maxY)
        case .rotation:    return CGPoint(x: f.midX, y: f.minY - rotationHandleOffset)
        }
    }

    // MARK: - Angle helper

    private func angleBetween(centre: CGPoint, from: CGPoint, to: CGPoint) -> Double {
        let a1 = atan2(from.y - centre.y, from.x - centre.x)
        let a2 = atan2(to.y   - centre.y, to.x   - centre.x)
        return (a2 - a1) * 180.0 / .pi
    }
}
