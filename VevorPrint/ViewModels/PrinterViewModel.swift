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

    // MARK: - Print Pipeline

    /// Render and print a label.
    ///
    /// 1. Renders elements to a CGImage at the configured DPI.
    /// 2. Encodes the image to an ESC/POS byte stream.
    /// 3. Sends the byte stream to the printer with chunk-based progress updates.
    ///
    /// - Parameters:
    ///   - elements: Sorted label elements to render.
    ///   - labelSize: Label dimensions in mm.
    ///   - toastStore: Optional toast store for user-facing error feedback.
    func printLabel(
        elements: [AnyLabelElement],
        labelSize: LabelSize,
        toastStore: ToastStore? = nil
    ) async {
        guard connectionState == .connected else {
            toastStore?.show("Kein Drucker verbunden.", style: .warning)
            return
        }
        guard !isPrinting else { return }

        isPrinting = true
        printProgress = 0.0

        defer {
            isPrinting = false
            printProgress = 0.0
        }

        let dpi = CGFloat(appSettings?.printDPI ?? 203)

        // Step 1: Render label to bitmap
        guard let cgImage = LabelRenderer.render(
            elements: elements,
            labelSize: labelSize,
            dpi: dpi
        ) else {
            toastStore?.show("Label konnte nicht gerendert werden.", style: .error)
            return
        }

        // Step 2: Encode to ESC/POS
        let printData: Data
        do {
            printData = try ESCPOSEncoder.encode(cgImage)
        } catch {
            bluetooth.lastError = error.localizedDescription
            toastStore?.show("ESC/POS Fehler: \(error.localizedDescription)", style: .error)
            return
        }

        // Step 3: Send in chunks with progress updates
        let chunkSize = appSettings?.bleChunkSize ?? BLEConstants.minChunkSize
        let totalBytes = printData.count
        var offset = 0

        while offset < totalBytes {
            let end = min(offset + chunkSize, totalBytes)
            let chunk = printData[offset ..< end]
            do {
                try bluetooth.send(data: chunk)
            } catch {
                bluetooth.lastError = error.localizedDescription
                toastStore?.show("Sendefehler: \(error.localizedDescription)", style: .error)
                return
            }
            offset = end
            printProgress = Double(offset) / Double(totalBytes)
            // Yield to allow BLE write-without-response to drain
            try? await Task.sleep(nanoseconds: 5_000_000)   // 5 ms
        }

        toastStore?.show("Label erfolgreich gedruckt.", style: .success)
    }

    /// Generate a preview CGImage of the label at 150 dpi (fast preview quality).
    ///
    /// - Parameters:
    ///   - elements: Sorted label elements.
    ///   - labelSize: Label dimensions in mm.
    /// - Returns: Optional CGImage preview.
    func previewImage(elements: [AnyLabelElement], labelSize: LabelSize) -> CGImage? {
        LabelRenderer.render(elements: elements, labelSize: labelSize, dpi: 150)
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
        case .disconnected: return "minus.circle"
        case .scanning:     return "antenna.radiowaves.left.and.right"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .connected:    return "checkmark.circle.fill"
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
