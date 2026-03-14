/// PrinterViewModel.swift
/// Manages Bluetooth connection state and print job queue.
/// Placeholder for Phase 1 — fully implemented in Phase 2/5.

import Foundation
import Observation

// MARK: - PrinterViewModel

@Observable
@MainActor
final class PrinterViewModel {

    // MARK: - Connection State

    var connectionState: ConnectionState = .disconnected

    // MARK: - Init

    init() {}
}

// MARK: - ConnectionState

/// Represents the BLE connection lifecycle.
enum ConnectionState: String {
    case disconnected = "Getrennt"
    case scanning     = "Suche..."
    case connecting   = "Verbinde..."
    case connected    = "Verbunden"
    case error        = "Fehler"

    var symbolName: String {
        switch self {
        case .disconnected: return "bluetooth.slash"
        case .scanning:     return "antenna.radiowaves.left.and.right"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .connected:    return "bluetooth"
        case .error:        return "exclamationmark.triangle"
        }
    }

    var color: String {
        switch self {
        case .connected:  return "green"
        case .scanning,
             .connecting: return "yellow"
        case .disconnected,
             .error:      return "red"
        }
    }
}
