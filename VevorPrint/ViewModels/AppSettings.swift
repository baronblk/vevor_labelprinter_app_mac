/// AppSettings.swift
/// Application-wide settings observable by any view via @Environment.
/// Persists lightweight preferences to UserDefaults.

import Foundation
import Observation

// MARK: - AppSettings

/// Stores and persists app-wide user preferences.
/// Inject via `.environment(appSettings)` at the root and access
/// with `@Environment(AppSettings.self)` in child views.
@Observable
final class AppSettings {

    // MARK: - Canvas

    /// Snap-to-grid interval in millimetres (0 = disabled).
    var gridSizeMM: Double {
        didSet { UserDefaults.standard.set(gridSizeMM, forKey: Keys.gridSizeMM) }
    }

    /// Show rulers on the canvas.
    var showRulers: Bool {
        didSet { UserDefaults.standard.set(showRulers, forKey: Keys.showRulers) }
    }

    /// Canvas zoom level (1.0 = 100 %).
    var canvasZoom: Double {
        didSet { UserDefaults.standard.set(canvasZoom, forKey: Keys.canvasZoom) }
    }

    // MARK: - Printing

    /// Print resolution in DPI (203 or 300).
    var printDPI: Int {
        didSet { UserDefaults.standard.set(printDPI, forKey: Keys.printDPI) }
    }

    /// BLE write chunk size in bytes.
    var bleChunkSize: Int {
        didSet { UserDefaults.standard.set(bleChunkSize, forKey: Keys.bleChunkSize) }
    }

    // MARK: - Onboarding

    /// Whether the onboarding sheet has been completed.
    var onboardingCompleted: Bool {
        didSet { UserDefaults.standard.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }

    // MARK: - Bluetooth

    /// UUID string of the last successfully paired printer peripheral.
    /// Used to auto-reconnect on next launch.
    var pairedPrinterUUID: String? {
        didSet { UserDefaults.standard.set(pairedPrinterUUID, forKey: Keys.pairedPrinterUUID) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        gridSizeMM          = defaults.object(forKey: Keys.gridSizeMM)          as? Double ?? 2.0
        showRulers          = defaults.object(forKey: Keys.showRulers)          as? Bool   ?? true
        canvasZoom          = defaults.object(forKey: Keys.canvasZoom)          as? Double ?? 1.0
        printDPI            = defaults.object(forKey: Keys.printDPI)            as? Int    ?? 203
        bleChunkSize        = defaults.object(forKey: Keys.bleChunkSize)        as? Int    ?? 512
        onboardingCompleted = defaults.object(forKey: Keys.onboardingCompleted) as? Bool   ?? false
        pairedPrinterUUID   = defaults.string(forKey: Keys.pairedPrinterUUID)
    }

    // MARK: - Reset

    /// Resets all settings to factory defaults.
    func resetToDefaults() {
        gridSizeMM          = 2.0
        showRulers          = true
        canvasZoom          = 1.0
        printDPI            = 203
        bleChunkSize        = 512
        onboardingCompleted = false
        pairedPrinterUUID   = nil
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let gridSizeMM          = "settings.gridSizeMM"
        static let showRulers          = "settings.showRulers"
        static let canvasZoom          = "settings.canvasZoom"
        static let printDPI            = "settings.printDPI"
        static let bleChunkSize        = "settings.bleChunkSize"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let pairedPrinterUUID   = "settings.pairedPrinterUUID"
    }
}
