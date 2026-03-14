/// PrinterViewModel.swift
/// High-level façade over BluetoothManager, exposed to all Views via @Environment.
/// Handles printer discovery, connection lifecycle, reconnect-on-launch, and
/// persists the paired device UUID via AppSettings.

import Foundation
import Observation
import SwiftData

// MARK: - PrinterViewModel

@Observable
@MainActor
final class PrinterViewModel {

    // MARK: - Bluetooth

    let bluetooth = BluetoothManager()

    // MARK: - Derived State (forwarded from BluetoothManager for convenience)

    var connectionState: ConnectionState { bluetooth.connectionState }
    var discoveredPeripherals: [DiscoveredPeripheral] { bluetooth.discoveredPeripherals }
    var connectedPrinterName: String? { bluetooth.connectedPrinterName }
    var lastError: String? { bluetooth.lastError }
    var isBluetoothAvailable: Bool { bluetooth.isBluetoothAvailable }

    // MARK: - Print Queue State

    var isPrinting = false
    var printProgress: Double = 0    // 0.0 – 1.0

    // MARK: - Dependencies (injected after init)

    var appSettings: AppSettings?
    var modelContext: ModelContext?

    // MARK: - Init

    init() {}

    // MARK: - Lifecycle

    /// Call once after appSettings is available. Triggers auto-reconnect if a
    /// previously paired device UUID is stored.
    /// - Parameter settings: The app-wide settings instance.
    func onAppear(settings: AppSettings) {
        self.appSettings = settings
        guard let uuid = settings.pairedPrinterUUID, !uuid.isEmpty else { return }
        bluetooth.reconnect(toUUID: uuid)
    }

    /// Gracefully disconnect and clean up timers. Call from App.onTerminate.
    func onTerminate() {
        bluetooth.disconnect()
    }

    // MARK: - Scan / Connect

    /// Start BLE scan for nearby printers.
    func startScanning() {
        bluetooth.startScanning()
    }

    /// Stop an active scan.
    func stopScanning() {
        bluetooth.stopScanning()
    }

    /// Connect to a discovered peripheral and persist its UUID.
    /// - Parameter peripheral: A peripheral entry from `discoveredPeripherals`.
    func connect(to peripheral: DiscoveredPeripheral) {
        bluetooth.connect(to: peripheral)
        appSettings?.pairedPrinterUUID = peripheral.peripheral.identifier.uuidString

        // Persist to SwiftData
        if let ctx = modelContext {
            let device = PrinterDevice(
                peripheralUUID: peripheral.peripheral.identifier.uuidString,
                name: peripheral.name
            )
            device.isDefault = true
            ctx.insert(device)
            try? ctx.save()
        }
    }

    /// Disconnect from the current printer and clear the saved UUID.
    func disconnect() {
        bluetooth.disconnect()
        appSettings?.pairedPrinterUUID = nil
    }

    // MARK: - Send

    /// Transmit raw ESC/POS bytes to the printer.
    /// - Parameter data: The encoded byte stream.
    /// - Throws: `PrinterError.notReady` if not connected.
    func send(data: Data) throws {
        try bluetooth.send(data: data)
    }
}

// MARK: - ConnectionState

/// Represents the full BLE connection lifecycle.
enum ConnectionState: String {
    case disconnected = "Getrennt"
    case scanning     = "Suche..."
    case connecting   = "Verbinde..."
    case connected    = "Verbunden"
    case error        = "Fehler"

    // MARK: SF Symbol

    var symbolName: String {
        switch self {
        case .disconnected: return "bluetooth.slash"
        case .scanning:     return "antenna.radiowaves.left.and.right"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .connected:    return "bluetooth"
        case .error:        return "exclamationmark.triangle"
        }
    }

    // MARK: Color

    var color: Color {
        switch self {
        case .connected:            return .green
        case .scanning, .connecting: return .yellow
        case .disconnected, .error: return .red
        }
    }
}

// MARK: - Color Import

import SwiftUI
