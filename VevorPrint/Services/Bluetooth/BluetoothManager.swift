/// BluetoothManager.swift
/// CoreBluetooth central manager: scans for, connects to, and maintains
/// a connection with the Vevor Y428BT-42B0 label printer.
/// Discovered peripherals are accumulated for UI presentation; the selected
/// peripheral is wrapped in a PrinterConnection for GATT operations.

import Foundation
import CoreBluetooth
import OSLog

// MARK: - BluetoothManager

@Observable
@MainActor
final class BluetoothManager: NSObject {

    // MARK: - Public State (observed by UI)

    var connectionState: ConnectionState = .disconnected
    var discoveredPeripherals: [DiscoveredPeripheral] = []
    var connectedPrinterName: String?
    var lastError: String?
    var isBluetoothAvailable = false

    // MARK: - Internal

    private(set) var printerConnection: PrinterConnection?

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var scanTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var savedPeripheralUUID: String?
    /// Strong reference held from connect() until didConnect/didFailToConnect fires.
    /// CoreBluetooth requires the caller to retain the peripheral during connection.
    private var pendingPeripheral: CBPeripheral?

    private let logger = Logger(subsystem: "de.baronblk.vevorprint", category: "BluetoothManager")

    // MARK: - Init

    override init() {
        super.init()
        // Always dispatch on main queue so @Observable changes propagate to SwiftUI directly.
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    /// Begin scanning for nearby BLE printers.
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot scan — Bluetooth not powered on (state: \(self.centralManager.state.rawValue))")
            return
        }
        guard connectionState != .scanning else { return }

        discoveredPeripherals.removeAll()
        connectionState = .scanning
        lastError = nil

        // Pre-seed the list from the system cache so the user sees the last-used printer
        // immediately, before the live scan delivers its first callback.
        if let uuidString = savedPeripheralUUID,
           let uuid = UUID(uuidString: uuidString) {
            let cached = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            for peripheral in cached {
                let name = peripheral.name ?? "Drucker"
                discoveredPeripherals.append(DiscoveredPeripheral(peripheral: peripheral, name: name, rssi: -60))
                logger.info("Pre-seeded scanner list from cache: \(name)")
            }
        }

        // Scan for all services — required to discover unverified UUIDs.
        // AllowDuplicatesKey: false (default) is correct here: macOS silently
        // ignores true unless the app has Bluetooth Background Mode, which can
        // suppress all scan callbacks. After stopScan()/startScan() the duplicate
        // filter resets, so previously seen peripherals are re-reported normally.
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        logger.info("BLE scan started")

        // Auto-stop after timeout
        scanTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.scanTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopScanning() }
        }
    }

    /// Stop an active scan.
    func stopScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
        if connectionState == .scanning {
            connectionState = .disconnected
        }
        logger.info("BLE scan stopped")
    }

    /// Connect to a discovered peripheral.
    /// - Parameter discovered: The peripheral entry from `discoveredPeripherals`.
    func connect(to discovered: DiscoveredPeripheral) {
        stopScanning()
        connectionState = .connecting
        savedPeripheralUUID = discovered.peripheral.identifier.uuidString
        pendingPeripheral = discovered.peripheral   // retain until didConnect/didFailToConnect
        logger.info("Connecting to \(discovered.name)")
        centralManager.connect(discovered.peripheral, options: nil)
    }

    /// Disconnect the current printer.
    /// - Parameter forget: If true, clears the saved UUID so auto-reconnect and
    ///   scan pre-seeding are disabled. Pass false (default) for a temporary
    ///   disconnect where the user may want to reconnect manually.
    func disconnect(forget: Bool = true) {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        if forget {
            savedPeripheralUUID = nil
        }

        if let peripheral = printerConnection?.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        printerConnection = nil
        connectionState = .disconnected
        connectedPrinterName = nil
        logger.info("Disconnected from printer (forget: \(forget))")
    }

    /// Attempt to reconnect to the last known printer UUID (called on app launch).
    /// - Parameter uuidString: The persisted CBPeripheral UUID string.
    func reconnect(toUUID uuidString: String) {
        savedPeripheralUUID = uuidString
        guard centralManager.state == .poweredOn else {
            // Will be retried in centralManagerDidUpdateState once BT powers on.
            logger.info("Queued reconnect to \(uuidString) — waiting for BT power-on")
            return
        }
        attemptReconnect(to: uuidString)
    }

    /// Send raw bytes to the connected printer.
    /// - Parameter data: ESC/POS encoded byte stream.
    /// - Throws: `PrinterError.notReady` if connection is not print-ready.
    func send(data: Data) async throws {
        try await printerConnection?.send(data: data)
    }

    // MARK: - Private Helpers

    private func attemptReconnect(to uuidString: String) {
        let uuid = UUID(uuidString: uuidString)
        let knownPeripherals = uuid.map {
            centralManager.retrievePeripherals(withIdentifiers: [$0])
        } ?? []

        if let peripheral = knownPeripherals.first {
            logger.info("Reconnecting to cached peripheral \(uuidString)")
            connectionState = .connecting
            pendingPeripheral = peripheral             // retain until didConnect/didFailToConnect
            centralManager.connect(peripheral, options: nil)
        } else {
            logger.info("Peripheral \(uuidString) not in cache — starting scan for reconnect")
            startScanning()
        }
    }

    private func scheduleReconnect() {
        guard let uuid = savedPeripheralUUID,
              reconnectAttempts < BLEConstants.maxReconnectAttempts else {
            logger.warning("Max reconnect attempts reached or no saved UUID")
            return
        }
        reconnectAttempts += 1
        logger.info("Reconnect attempt \(self.reconnectAttempts)/\(BLEConstants.maxReconnectAttempts) in \(BLEConstants.reconnectInterval)s")
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: BLEConstants.reconnectInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.attemptReconnect(to: uuid) }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch central.state {
            case .poweredOn:
                self.isBluetoothAvailable = true
                self.logger.info("CBCentralManager: poweredOn")
                // Trigger queued reconnect if any
                if let uuid = self.savedPeripheralUUID, self.printerConnection == nil {
                    self.attemptReconnect(to: uuid)
                }
            case .poweredOff:
                self.isBluetoothAvailable = false
                self.connectionState = .disconnected
                self.logger.info("CBCentralManager: poweredOff")
            case .unauthorized:
                self.isBluetoothAvailable = false
                self.connectionState = .error
                self.lastError = "Bluetooth-Zugriff nicht gestattet. Bitte in den Systemeinstellungen erlauben."
                self.logger.error("CBCentralManager: unauthorized")
            case .unsupported:
                self.isBluetoothAvailable = false
                self.connectionState = .error
                self.lastError = "Dieses Gerät unterstützt Bluetooth Low Energy nicht."
                self.logger.error("CBCentralManager: unsupported")
            default:
                self.logger.info("CBCentralManager state: \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let name = peripheral.name
                ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? "Unbekanntes Gerät"
            let rssi = RSSI.intValue
            self.logger.debug("Discovered: \(name) [\(peripheral.identifier.uuidString)] RSSI:\(rssi)")

            // Update existing entry or add new one.
            if let idx = self.discoveredPeripherals.firstIndex(where: {
                $0.peripheral.identifier == peripheral.identifier
            }) {
                // Only update RSSI when it changes by ≥3 dBm to avoid unnecessary redraws.
                if abs(self.discoveredPeripherals[idx].rssi - rssi) >= 3 {
                    self.discoveredPeripherals[idx].rssi = rssi
                }
            } else {
                self.discoveredPeripherals.append(
                    DiscoveredPeripheral(peripheral: peripheral, name: name, rssi: rssi)
                )
            }

            // Auto-connect if UUID matches saved printer
            if let savedUUID = self.savedPeripheralUUID,
               peripheral.identifier.uuidString == savedUUID {
                self.connect(to: DiscoveredPeripheral(peripheral: peripheral, name: name, rssi: rssi))
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didConnect peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.reconnectAttempts = 0
            self.pendingPeripheral = nil          // connection established, release retain
            let name = peripheral.name ?? "Drucker"
            self.connectedPrinterName = name
            self.connectionState = .connecting  // Still discovering characteristics
            self.logger.info("Connected to \(name) — starting service discovery")

            let connection = PrinterConnection(peripheral: peripheral)
            connection.delegate = self
            self.printerConnection = connection
            connection.discoverServices()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pendingPeripheral = nil          // connection failed, release retain
            let msg = error?.localizedDescription ?? "Unbekannter Fehler"
            self.logger.error("Failed to connect to \(peripheral.name ?? "?"): \(msg)")
            self.connectionState = .error
            self.lastError = "Verbindung fehlgeschlagen: \(msg)"
            self.scheduleReconnect()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                self.logger.warning("Disconnected unexpectedly: \(error.localizedDescription)")
                self.connectionState = .disconnected
                self.lastError = "Verbindung getrennt: \(error.localizedDescription)"
                self.printerConnection = nil
                self.connectedPrinterName = nil
                self.scheduleReconnect()
            } else {
                // Intentional disconnect — already handled in disconnect()
                self.logger.info("Peripheral disconnected cleanly")
            }
        }
    }
}

// MARK: - PrinterConnectionDelegate

extension BluetoothManager: PrinterConnectionDelegate {

    nonisolated func printerConnectionReady(_ connection: PrinterConnection) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.connectionState = .connected
            self.logger.info("Printer ready ✓ — write char: \(connection.writeCharacteristic?.uuid.uuidString ?? "none"), chunk: \(connection.chunkSize)B")
        }
    }

    nonisolated func printerConnection(_ connection: PrinterConnection, didFailWith error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.connectionState = .error
            self.lastError = error.localizedDescription
            self.logger.error("PrinterConnection error: \(error.localizedDescription)")
        }
    }

    nonisolated func printerConnectionDidWriteChunk(_ connection: PrinterConnection) {
        // Could be used for progress reporting in Phase 5
    }
}

// MARK: - DiscoveredPeripheral

/// Value type representing a scanned BLE peripheral for display in the UI.
struct DiscoveredPeripheral: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    var rssi: Int

    init(peripheral: CBPeripheral, name: String, rssi: Int) {
        self.id         = peripheral.identifier
        self.peripheral = peripheral
        self.name       = name
        self.rssi       = rssi
    }

    /// A human-readable signal strength label.
    var signalLabel: String {
        switch rssi {
        case ..<(-80): return "Schwach"
        case -80..<(-60): return "Mittel"
        default: return "Stark"
        }
    }

    var signalSymbol: String {
        switch rssi {
        case ..<(-80): return "wifi.slash"
        case -80..<(-60): return "wifi"
        default: return "wifi"
        }
    }
}
