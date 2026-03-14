/// BluetoothStatusView.swift
/// Compact BLE status indicator (dot + label) used in the toolbar and status bar.
/// Tapping it opens PrinterScannerSheet for full printer management.

import SwiftUI

// MARK: - BluetoothStatusView

struct BluetoothStatusView: View {

    // MARK: - Environment

    @Environment(PrinterViewModel.self) private var printerVM

    // MARK: - State

    @State private var showScanner = false

    // MARK: - Body

    var body: some View {
        Button {
            showScanner = true
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(printerVM.connectionState.color)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if printerVM.connectionState == .scanning ||
                           printerVM.connectionState == .connecting {
                            Circle()
                                .stroke(printerVM.connectionState.color.opacity(0.4), lineWidth: 2)
                                .scaleEffect(1.6)
                        }
                    }
                Text(printerVM.connectionState.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let name = printerVM.connectedPrinterName {
                    Text("· \(name)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showScanner) {
            PrinterScannerSheet()
                .environment(printerVM)
        }
    }
}

// MARK: - PrinterScannerSheet

/// Full-featured sheet for scanning, listing, and connecting to BLE printers.
struct PrinterScannerSheet: View {

    // MARK: - Environment

    @Environment(PrinterViewModel.self) private var printerVM
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showConfigSheet = false
    @State private var peripheralToConfig: DiscoveredPeripheral? = nil

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drucker verbinden")
                        .font(.headline)
                    Text(printerVM.connectionState.rawValue)
                        .font(.caption)
                        .foregroundStyle(printerVM.connectionState.color)
                }
                Spacer()
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Error banner
            if let error = printerVM.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
            }

            // Bluetooth unavailable state
            if !printerVM.isBluetoothAvailable {
                bluetoothUnavailableView
            } else {
                // Connected device
                if printerVM.connectionState == .connected,
                   let name = printerVM.connectedPrinterName {
                    connectedDeviceRow(name: name)
                    Divider()
                }

                // Section header — direct child of outer VStack so it gets
                // its natural height without competing with the ScrollView
                Text("Verfügbare Drucker")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                // ScrollView as direct child: gets all remaining height
                // inside the fixed 480pt sheet automatically
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        if printerVM.discoveredPeripherals.isEmpty {
                            emptyDiscoveryRow
                                .padding(.horizontal)
                        } else {
                            ForEach(printerVM.discoveredPeripherals) { peripheral in
                                PeripheralRow(peripheral: peripheral) {
                                    peripheralToConfig = peripheral
                                    showConfigSheet = true
                                }
                                .padding(.horizontal)
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            Divider()

            // Footer buttons
            HStack {
                if printerVM.connectionState == .connected {
                    Button(role: .destructive) {
                        printerVM.disconnect()
                    } label: {
                        Label("Trennen", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if printerVM.connectionState == .scanning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 4)
                    Button("Stopp") {
                        printerVM.stopScanning()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        printerVM.startScanning()
                    } label: {
                        Label("Suchen", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!printerVM.isBluetoothAvailable)
                }
            }
            .padding()
        }
        .frame(width: 420, height: 480)
        .onAppear {
            if printerVM.isBluetoothAvailable,
               printerVM.connectionState == .disconnected {
                printerVM.startScanning()
            }
        }
        .onDisappear {
            // Only stop the scan when the scanner sheet itself is dismissed.
            // SwiftUI also fires onDisappear when a child sheet (PrinterConfigSheet)
            // presents on top — guard against that case to avoid killing the scan
            // before the user has had a chance to see any discovered devices.
            if !showConfigSheet {
                printerVM.stopScanning()
            }
        }
        .sheet(isPresented: $showConfigSheet) {
            if let peripheral = peripheralToConfig {
                PrinterConfigSheet(peripheral: peripheral) { dpi, paperWidthMM in
                    printerVM.connect(to: peripheral, dpi: dpi, paperWidthMM: paperWidthMM)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sub-Views

    private var bluetoothUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Bluetooth nicht verfügbar")
                .font(.headline)
            Text("Bitte aktiviere Bluetooth in den Systemeinstellungen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func connectedDeviceRow(name: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "printer.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("Verbunden")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding()
    }

    private var emptyDiscoveryRow: some View {
        HStack(spacing: 8) {
            if printerVM.connectionState == .scanning {
                ProgressView().scaleEffect(0.7)
                Text("Suche nach Druckern…")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "printer")
                    .symbolVariant(.slash)
                    .foregroundStyle(.tertiary)
                Text("Keine Drucker gefunden")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - PeripheralRow

private struct PeripheralRow: View {

    let peripheral: DiscoveredPeripheral
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "printer")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(peripheral.name)
                    .font(.body)
                Text(peripheral.peripheral.identifier.uuidString.prefix(8) + "…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()

            HStack(spacing: 4) {
                Text(peripheral.signalLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(peripheral.rssi) dBm")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button("Verbinden") {
                onConnect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - PrinterConfigSheet

/// Sheet shown before connecting to a new printer.
/// Lets the user configure DPI and paper width so the print pipeline
/// uses the correct pixel dimensions for this specific device.
struct PrinterConfigSheet: View {

    // MARK: - Input

    let peripheral: DiscoveredPeripheral
    /// Called with (dpi, paperWidthMM) when the user confirms.
    let onConfirm: (Int, Double) -> Void

    // MARK: - State

    @State private var selectedDPI: Int = 300
    @State private var paperWidthMM: Double = 100.0
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    private let dpiOptions = [203, 300]
    private let paperWidthOptions: [Double] = [40, 50, 57, 60, 75, 80, 100, 110]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drucker einrichten")
                        .font(.headline)
                    Text(peripheral.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Configuration form
            Form {
                Section {
                    Picker("Auflösung", selection: $selectedDPI) {
                        ForEach(dpiOptions, id: \.self) { dpi in
                            Text("\(dpi) DPI").tag(dpi)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Papierbreite", selection: $paperWidthMM) {
                        ForEach(paperWidthOptions, id: \.self) { w in
                            Text("\(Int(w)) mm").tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Druckerkonfiguration")
                } footer: {
                    let widthPx = Int((paperWidthMM * Double(selectedDPI) / 25.4).rounded())
                    Text("Druckkopfbreite: \(widthPx) px  ·  Diese Einstellungen werden mit dem Drucker gespeichert und können später in den Einstellungen geändert werden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button {
                    onConfirm(selectedDPI, paperWidthMM)
                    dismiss()
                } label: {
                    Label("Verbinden", systemImage: "cable.connector")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 400, height: 340)
    }
}

#Preview {
    BluetoothStatusView()
        .environment(PrinterViewModel())
        .padding()
}
