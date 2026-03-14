/// UnitConversionTests.swift
/// Unit tests for UnitConversion utilities. Runs without hardware or Bluetooth.

import XCTest

final class UnitConversionTests: XCTestCase {

    // MARK: - mm → px

    func testMmToPxAt203DPI() {
        let px = UnitConversion.mmToPx(25.4, dpi: 203)
        XCTAssertEqual(px, 203, accuracy: 0.01)
    }

    func testMmToPxAt300DPI() {
        let px = UnitConversion.mmToPx(25.4, dpi: 300)
        XCTAssertEqual(px, 300, accuracy: 0.01)
    }

    // MARK: - px → mm

    func testPxToMmAt203DPI() {
        let mm = UnitConversion.pxToMm(203, dpi: 203)
        XCTAssertEqual(mm, 25.4, accuracy: 0.01)
    }

    // MARK: - mm → pt

    func testMmToPt() {
        let pt = UnitConversion.mmToPt(25.4)
        XCTAssertEqual(pt, 72, accuracy: 0.01)
    }

    // MARK: - pt → mm

    func testPtToMm() {
        let mm = UnitConversion.ptToMm(72)
        XCTAssertEqual(mm, 25.4, accuracy: 0.01)
    }

    // MARK: - Round-trip

    func testRoundTripMmPxMm() {
        let original: CGFloat = 57.0
        let px = UnitConversion.mmToPx(original, dpi: 203)
        let mm = UnitConversion.pxToMm(px, dpi: 203)
        XCTAssertEqual(mm, original, accuracy: 0.001)
    }

    func testRoundTripMmPtMm() {
        let original: CGFloat = 100.0
        let pt = UnitConversion.mmToPt(original)
        let mm = UnitConversion.ptToMm(pt)
        XCTAssertEqual(mm, original, accuracy: 0.001)
    }
}
