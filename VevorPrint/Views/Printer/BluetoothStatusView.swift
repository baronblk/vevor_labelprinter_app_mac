/// BluetoothStatusView.swift
/// Small status indicator (icon + label) used in toolbar or status bar
/// to show the current BLE connection state.

import SwiftUI

// MARK: - BluetoothStatusView

struct BluetoothStatusView: View {

    // MARK: - Environment

    @Environment(PrinterViewModel.self) private var printerVM

    // MARK: - Body

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(printerVM.connectionState.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch printerVM.connectionState {
        case .connected:              return .green
        case .scanning, .connecting:  return .yellow
        case .disconnected, .error:   return .red
        }
    }
}

#Preview {
    BluetoothStatusView()
        .environment(PrinterViewModel())
        .padding()
}
