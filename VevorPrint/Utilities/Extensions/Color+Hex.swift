/// Color+Hex.swift
/// Extension to initialise SwiftUI Color from a hex string and to export a Color as hex.

import SwiftUI

extension Color {

    // MARK: - Init from Hex

    /// Initialise a Color from a CSS-style hex string (#RGB, #RRGGBB, #RRGGBBAA).
    /// - Parameter hex: Hex string, with or without leading `#`.
    init(hex: String) {
        let sanitised = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitised).scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch sanitised.count {
        case 3: // RGB (12-bit)
            r = Double((rgb >> 8) & 0xF) / 15
            g = Double((rgb >> 4) & 0xF) / 15
            b = Double(rgb & 0xF) / 15
            a = 1.0
        case 6: // RRGGBB
            r = Double((rgb >> 16) & 0xFF) / 255
            g = Double((rgb >> 8)  & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255
            a = 1.0
        case 8: // RRGGBBAA
            r = Double((rgb >> 24) & 0xFF) / 255
            g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8)  & 0xFF) / 255
            a = Double(rgb & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - Export as Hex

    /// Return the hex string representation (without alpha, uppercase).
    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
