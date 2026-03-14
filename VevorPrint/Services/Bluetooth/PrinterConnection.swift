/// PrinterConnection.swift
/// Wraps a CBPeripheral and handles GATT service/characteristic discovery.
/// Once the write characteristic is found, `isReady` becomes true and
/// callers can use `send(data:)` to transmit ESC/POS byte streams.

import Foundation
import CoreBluetooth
import OSLog

// MARK: - PrinterConnectionDelegate

protocol PrinterConnectionDelegate: AnyObject {
    /// Called when the write characteristic has been discovered and the connection is print-ready.
    func printerConnectionReady(_ connection: PrinterConnection)
    /// Called when the connection encounters a GATT-level error.
    func printerConnection(_ connection: PrinterConnection, didFailWith error: Error)
    /// Called when a chunk has been acknowledged (for `.withResponse` writes).
    func printerConnectionDidWriteChunk(_ connection: PrinterConnection)
}

// MARK: - PrinterConnection

/// Manages the lifecycle of a single BLE printer peripheral.
final class PrinterConnection: NSObject {

    // MARK: - Properties

    private(set) var peripheral: CBPeripheral
    private(set) var writeCharacteristic: CBCharacteristic?
    private(set) var notifyCharacteristic: CBCharacteristic?
    private(set) var isReady = false

    /// Effective chunk size — negotiated after connection.
    private(set) var chunkSize = BLEConstants.minChunkSize

    weak var delegate: PrinterConnectionDelegate?

    /// Continuation waiting for peripheralIsReady(toSendWriteWithoutResponse:).
    private var sendReadyContinuation: CheckedContinuation<Void, Never>?

    private let logger = Logger(subsystem: "de.baronblk.vevorprint", category: "PrinterConnection")

    // MARK: - Init

    /// - Parameter peripheral: The CBPeripheral to manage. Must already be in `.connected` state.
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    // MARK: - Discovery

    /// Starts GATT service and characteristic discovery.
    func discoverServices() {
        logger.info("Discovering services for \(self.peripheral.name ?? "unknown")")
        // Pass nil to discover all services — required for UUID verification.
        peripheral.discoverServices(nil)
    }

    // MARK: - Send

    /// Sends raw bytes to the printer, split into negotiated chunk sizes.
    ///
    /// Flow control strategy:
    ///   - `.withoutResponse`: waits for `peripheralIsReady` before each chunk when the
    ///     CoreBluetooth transmit buffer is full (prevents EXC_BREAKPOINT assertion).
    ///   - `.withResponse`: the BLE stack serialises writes automatically. A short inter-
    ///     chunk delay is inserted so the printer's internal row buffer never runs dry.
    ///     Without this delay, the print motor stalls between packets and produces an
    ///     audible clicking noise (motor start/stop per BLE round-trip ~30–100 ms).
    ///
    /// - Parameter data: The ESC/POS byte stream to send.
    /// - Throws: `PrinterError.notReady` when write characteristic is unavailable.
    func send(data: Data) async throws {
        guard isReady, let char = writeCharacteristic else {
            throw PrinterError.notReady
        }

        let useNoResponse = char.properties.contains(.writeWithoutResponse)
        let writeType: CBCharacteristicWriteType = useNoResponse ? .withoutResponse : .withResponse
        let delayNs = UInt64(BLEConstants.writeDelay * 1_000_000_000)

        var offset = 0
        while offset < data.count {
            if useNoResponse {
                // Wait for transmit buffer space to prevent the CoreBluetooth
                // EXC_BREAKPOINT assertion on overflow.
                if !peripheral.canSendWriteWithoutResponse {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        self.sendReadyContinuation = continuation
                    }
                }
            } else {
                // For withResponse writes: insert a small delay between chunks.
                // This keeps the printer's internal row buffer fed and prevents
                // the motor starvation that causes dot-matrix-like clicking noise.
                if offset > 0 {
                    try await Task.sleep(nanoseconds: delayNs)
                }
            }

            let end   = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]
            peripheral.writeValue(chunk, for: char, type: writeType)
            offset = end
        }
        logger.debug("Sent \(data.count) bytes in \(Int((data.count + self.chunkSize - 1) / self.chunkSize)) chunk(s)")
    }
}

// MARK: - CBPeripheralDelegate

extension PrinterConnection: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            logger.error("Service discovery failed: \(error.localizedDescription)")
            delegate?.printerConnection(self, didFailWith: error)
            return
        }

        guard let services = peripheral.services else { return }

        logger.info("Discovered \(services.count) service(s):")
        for service in services {
            logger.info("  Service UUID: \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            logger.error("Characteristic discovery failed: \(error.localizedDescription)")
            delegate?.printerConnection(self, didFailWith: error)
            return
        }

        guard let chars = service.characteristics else { return }

        logger.info("Service \(service.uuid.uuidString) characteristics:")
        for char in chars {
            let props = char.properties
            logger.info("  Char \(char.uuid.uuidString) — props: \(props.debugDescription)")

            // Select write characteristic.
            // Priority: writeWithoutResponse > write-with-response.
            // Reason: Many BLE printers (ISSC/Nordic UART stack) use the
            // writeWithoutResponse char for bulk data (ESC/POS streaming).
            // Using .withResponse with large payloads can trigger CoreBluetooth
            // assertion failures when the actual ATT-MTU is smaller than the
            // value reported by maximumWriteValueLength(for: .withResponse).
            let isWriteNoResp = props.contains(.writeWithoutResponse)
            let isWrite       = props.contains(.write)

            if isWriteNoResp || isWrite {
                // Upgrade to this char if:
                //   a) no write char selected yet, OR
                //   b) current selection only has .write but this one has .writeWithoutResponse
                let currentLacksNoResp = writeCharacteristic
                    .map { !$0.properties.contains(.writeWithoutResponse) } ?? true
                let shouldSelect = writeCharacteristic == nil ||
                                   (isWriteNoResp && currentLacksNoResp)

                if shouldSelect {
                    writeCharacteristic = char
                    let wType: CBCharacteristicWriteType = isWriteNoResp
                        ? .withoutResponse : .withResponse
                    let maxWrite = peripheral.maximumWriteValueLength(for: wType)
                    chunkSize = min(maxWrite, BLEConstants.maxChunkSize)
                    logger.info("  ↳ Selected as WRITE characteristic (\(isWriteNoResp ? "noResponse" : "withResponse"), chunk: \(self.chunkSize)B)")
                }
            }

            // Subscribe to NOTIFY only on the write char's own service.
            // Standard BLE services (180F Battery, 1805 CurrentTime, etc.) require
            // pairing/encryption — attempting subscription causes CBError 15/14 warnings.
            if notifyCharacteristic == nil,
               writeCharacteristic?.service?.uuid == service.uuid,
               props.contains(.notify) || props.contains(.indicate) {
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
                logger.info("  ↳ Subscribed to NOTIFY characteristic")
            }
        }

        // Signal ready as soon as write char is found
        if writeCharacteristic != nil, !isReady {
            isReady = true
            delegate?.printerConnectionReady(self)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            logger.error("Write error: \(error.localizedDescription)")
            delegate?.printerConnection(self, didFailWith: error)
        } else {
            delegate?.printerConnectionDidWriteChunk(self)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        logger.debug("Notify data (\(data.count) bytes): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            logger.warning("Notify subscription error: \(error.localizedDescription)")
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        // Resume any send() call waiting for buffer space.
        let cont = sendReadyContinuation
        sendReadyContinuation = nil
        cont?.resume()
    }
}

// MARK: - PrinterError

enum PrinterError: LocalizedError {
    case notReady
    case sendFailed(String)
    case noWriteCharacteristic

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Der Drucker ist noch nicht bereit. Bitte warte, bis die Verbindung hergestellt ist."
        case .sendFailed(let detail):
            return "Sendung fehlgeschlagen: \(detail)"
        case .noWriteCharacteristic:
            return "Kein schreibfähiges Characteristic gefunden. Bitte überprüfe die BLE-UUID-Konfiguration."
        }
    }
}

// MARK: - CBCharacteristicProperties + Debug

private extension CBCharacteristicProperties {
    var debugDescription: String {
        var parts: [String] = []
        if contains(.read)                { parts.append("read") }
        if contains(.write)               { parts.append("write") }
        if contains(.writeWithoutResponse){ parts.append("writeNoResponse") }
        if contains(.notify)              { parts.append("notify") }
        if contains(.indicate)            { parts.append("indicate") }
        return parts.joined(separator: "|")
    }
}
