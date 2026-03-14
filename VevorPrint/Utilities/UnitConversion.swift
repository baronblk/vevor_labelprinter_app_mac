/// UnitConversion.swift
/// Pure utility functions for converting between millimetres, points, and pixels.

import CoreGraphics

// MARK: - UnitConversion

/// Converts between physical units used in label design and rendering.
enum UnitConversion {

    /// Millimetres per inch.
    static let mmPerInch: CGFloat = 25.4

    // MARK: - mm ↔ px

    /// Convert millimetres to pixels at the given DPI.
    /// - Parameters:
    ///   - mm: Length in millimetres.
    ///   - dpi: Dots per inch.
    /// - Returns: Length in pixels.
    static func mmToPx(_ mm: CGFloat, dpi: CGFloat) -> CGFloat {
        mm / mmPerInch * dpi
    }

    /// Convert pixels to millimetres at the given DPI.
    /// - Parameters:
    ///   - px: Length in pixels.
    ///   - dpi: Dots per inch.
    /// - Returns: Length in millimetres.
    static func pxToMm(_ px: CGFloat, dpi: CGFloat) -> CGFloat {
        px / dpi * mmPerInch
    }

    // MARK: - mm ↔ pt

    /// Convert millimetres to typographic points (72 pt/inch).
    /// - Parameter mm: Length in millimetres.
    /// - Returns: Length in points.
    static func mmToPt(_ mm: CGFloat) -> CGFloat {
        mm / mmPerInch * 72.0
    }

    /// Convert typographic points to millimetres.
    /// - Parameter pt: Length in points.
    /// - Returns: Length in millimetres.
    static func ptToMm(_ pt: CGFloat) -> CGFloat {
        pt / 72.0 * mmPerInch
    }

    // MARK: - px ↔ pt

    /// Convert pixels to points, given the screen scale factor.
    /// - Parameters:
    ///   - px: Length in pixels.
    ///   - scale: Screen scale (e.g. 2.0 for Retina).
    /// - Returns: Length in points.
    static func pxToPt(_ px: CGFloat, scale: CGFloat) -> CGFloat {
        px / scale
    }

    /// Convert points to pixels, given the screen scale factor.
    /// - Parameters:
    ///   - pt: Length in points.
    ///   - scale: Screen scale.
    /// - Returns: Length in pixels.
    static func ptToPx(_ pt: CGFloat, scale: CGFloat) -> CGFloat {
        pt * scale
    }
}
