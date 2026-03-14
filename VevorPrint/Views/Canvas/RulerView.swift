/// RulerView.swift
/// Horizontal and vertical canvas rulers scaled in millimetres.
/// Tick-mark density adapts to the current zoom level.

import SwiftUI

// MARK: - RulerView

struct RulerView: View {

    // MARK: Input

    /// Canvas zoom factor (1.0 = 100 %).
    let zoom: CGFloat
    /// Points per mm at zoom == 1.0.
    let ptPerMM: CGFloat
    /// Total label size in mm.
    let labelSizeMM: CGSize
    /// Whether to draw the horizontal ruler (false = vertical).
    let isHorizontal: Bool

    // MARK: Constants

    private let thickness: CGFloat = 20
    private let tickColor = Color(nsColor: .secondaryLabelColor)
    private let labelFont = Font.system(size: 8).monospacedDigit()

    // MARK: Body

    var body: some View {
        Canvas { ctx, size in
            drawRuler(ctx: ctx, size: size)
        }
        .frame(
            width:  isHorizontal ? nil : thickness,
            height: isHorizontal ? thickness : nil
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: isHorizontal ? .bottom : .trailing) {
            Divider()
        }
    }

    // MARK: Drawing

    private func drawRuler(ctx: GraphicsContext, size: CGSize) {
        let scale = zoom * ptPerMM          // points per mm at current zoom
        let totalMM = isHorizontal ? labelSizeMM.width : labelSizeMM.height

        // Choose tick interval based on zoom
        let tickIntervalMM: CGFloat = tickInterval(scale: scale)
        let labelIntervalMM = tickIntervalMM * 5

        var mm: CGFloat = 0
        while mm <= totalMM {
            let pos = mm * scale
            let isMajor = (mm.truncatingRemainder(dividingBy: labelIntervalMM)) < 0.001

            let tickLength: CGFloat = isMajor ? thickness * 0.6 : thickness * 0.3

            if isHorizontal {
                let p1 = CGPoint(x: pos, y: size.height)
                let p2 = CGPoint(x: pos, y: size.height - tickLength)
                var path = Path()
                path.move(to: p1); path.addLine(to: p2)
                ctx.stroke(path, with: .color(tickColor), lineWidth: 0.5)

                if isMajor {
                    ctx.draw(
                        Text("\(Int(mm))").font(labelFont).foregroundStyle(tickColor),
                        at: CGPoint(x: pos + 2, y: size.height - tickLength - 4),
                        anchor: .bottomLeading
                    )
                }
            } else {
                let p1 = CGPoint(x: size.width,              y: pos)
                let p2 = CGPoint(x: size.width - tickLength, y: pos)
                var path = Path()
                path.move(to: p1); path.addLine(to: p2)
                ctx.stroke(path, with: .color(tickColor), lineWidth: 0.5)

                if isMajor {
                    // Vertical text rotation not supported in Canvas; draw compact label sideways
                    ctx.draw(
                        Text("\(Int(mm))").font(labelFont).foregroundStyle(tickColor),
                        at: CGPoint(x: 2, y: pos - 1),
                        anchor: .topLeading
                    )
                }
            }
            mm += tickIntervalMM
        }
    }

    // MARK: Tick interval

    private func tickInterval(scale: CGFloat) -> CGFloat {
        // Target ~6 pt minimum between ticks
        let minPtGap: CGFloat = 6
        for interval in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0] as [CGFloat] {
            if interval * scale >= minPtGap { return interval }
        }
        return 50
    }
}

// MARK: - RulerCorner

/// The small square where horizontal and vertical rulers meet.
struct RulerCorner: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .overlay(
                Rectangle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}
