/// BLEConstants.swift
/// Central place for all Bluetooth Low Energy UUIDs and protocol constants.
/// UUIDs marked "UNVERIFIED" must be confirmed with a real Vevor Y428BT-42B0.
/// After first successful connect, update the verified UUIDs and commit with:
/// `chore(bluetooth): update verified BLE UUIDs`

import CoreBluetooth

// MARK: - BLEConstants

enum BLEConstants {

    // MARK: - Service UUIDs

    /// Primary printer service UUID (UNVERIFIED — common for generic ESC/POS BLE printers).
    static let printerServiceUUID  = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")

    /// SPP-over-BLE service UUID (fallback, UNVERIFIED).
    static let sppServiceUUID      = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")

    // MARK: - Characteristic UUIDs

    /// Write characteristic for sending ESC/POS data (UNVERIFIED).
    static let writeCharUUID       = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")

    /// Notify characteristic for printer status (UNVERIFIED, optional).
    static let notifyCharUUID      = CBUUID(string: "0000FF03-0000-1000-8000-00805F9B34FB")

    // MARK: - Transfer

    /// Starting chunk size in bytes — safe minimum for all BLE peripherals.
    static let minChunkSize  = 20
    /// Maximum chunk size, used when `maximumWriteValueLength` permits.
    static let maxChunkSize  = 512
    /// Delay between consecutive BLE write packets (seconds).
    static let writeDelay: TimeInterval = 0.02

    // MARK: - Scan

    /// How long (seconds) to scan before stopping automatically.
    static let scanTimeout: TimeInterval = 15.0
    /// Reconnect attempt interval (seconds).
    static let reconnectInterval: TimeInterval = 5.0
    /// Maximum number of automatic reconnect attempts.
    static let maxReconnectAttempts = 5
}
