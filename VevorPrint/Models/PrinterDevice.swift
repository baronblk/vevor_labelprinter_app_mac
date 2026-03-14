/// PrinterDevice.swift
/// SwiftData model persisting a paired printer's identity so the app can
/// reconnect automatically on next launch.

import Foundation
import SwiftData

// MARK: - PrinterDevice

@Model
final class PrinterDevice {

    // MARK: Properties

    var id: UUID
    /// The BLE peripheral UUID as a string — used to retrieve the peripheral
    /// from CBCentralManager on subsequent launches.
    var peripheralUUID: String
    var name: String
    var lastConnectedAt: Date
    /// Whether this is the preferred/default printer.
    var isDefault: Bool

    // MARK: Init

    /// - Parameters:
    ///   - peripheralUUID: UUID string of the CBPeripheral.
    ///   - name: Human-readable printer name.
    init(peripheralUUID: String, name: String) {
        self.id              = UUID()
        self.peripheralUUID  = peripheralUUID
        self.name            = name
        self.lastConnectedAt = Date()
        self.isDefault       = false
    }
}
