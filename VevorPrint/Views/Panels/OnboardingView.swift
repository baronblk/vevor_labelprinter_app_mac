/// OnboardingView.swift
/// First-launch onboarding sheet. Guides the user through Bluetooth permission
/// and initial printer pairing. Shown automatically when onboardingCompleted == false.

import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    // MARK: - Environment

    @Environment(AppSettings.self)  private var appSettings
    @Environment(PrinterViewModel.self) private var printerVM
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var currentStep = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepView(for: step, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer navigation
            HStack {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep
                                  ? Color.accentColor
                                  : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentStep)
                    }
                }

                Spacer()

                if currentStep > 0 {
                    Button("Zurück") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }

                if currentStep < steps.count - 1 {
                    Button("Weiter") {
                        handleNextTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Fertig") {
                        appSettings.onboardingCompleted = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - Step View

    @ViewBuilder
    private func stepView(for step: OnboardingStep, index: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: step.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 32)

            Text(step.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            // Step-specific extra content
            if index == 2 {
                bluetoothPermissionExtra
            } else if index == 3 {
                printerScanExtra
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Extra Content

    @ViewBuilder
    private var bluetoothPermissionExtra: some View {
        if !printerVM.isBluetoothAvailable {
            Label("Bluetooth-Berechtigung ausstehend", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Label("Bluetooth aktiv ✓", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var printerScanExtra: some View {
        VStack(spacing: 10) {
            if printerVM.connectionState == .scanning {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Suche nach Druckern…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if printerVM.connectionState == .connected,
                      let name = printerVM.connectedPrinterName {
                Label("Verbunden mit: \(name)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button {
                    printerVM.startScanning()
                } label: {
                    Label("Drucker suchen", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(!printerVM.isBluetoothAvailable)

                if !printerVM.discoveredPeripherals.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(printerVM.discoveredPeripherals) { p in
                            Button {
                                printerVM.connect(to: p)
                            } label: {
                                HStack {
                                    Image(systemName: "printer")
                                        .foregroundStyle(.secondary)
                                    Text(p.name)
                                    Spacer()
                                    Text(p.signalLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Navigation

    private func handleNextTapped() {
        // Trigger BT scan when reaching the printer step
        if currentStep == 2, printerVM.isBluetoothAvailable {
            printerVM.startScanning()
        }
        withAnimation { currentStep += 1 }
    }

    // MARK: - Steps

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Willkommen bei VevorPrint",
            description: "Entwerfe und drucke professionelle Labels direkt vom Mac auf deinen Vevor-Thermodrucker.",
            symbolName: "printer.dotmatrix"
        ),
        OnboardingStep(
            title: "So funktioniert es",
            description: "Wähle eine Labelgröße, füge Elemente hinzu — Text, QR-Codes, Barcodes oder Bilder — und drucke direkt per Bluetooth.",
            symbolName: "hand.draw"
        ),
        OnboardingStep(
            title: "Bluetooth-Berechtigung",
            description: "VevorPrint benötigt Bluetooth, um mit dem Drucker zu kommunizieren. Klicke im nächsten Dialog auf 'Erlauben'.",
            symbolName: "bluetooth"
        ),
        OnboardingStep(
            title: "Drucker verbinden",
            description: "Schalte den Vevor Y428BT-42B0 ein und stelle sicher, dass er sichtbar ist. VevorPrint sucht automatisch nach verfügbaren Druckern.",
            symbolName: "printer.fill"
        ),
    ]
}

// MARK: - OnboardingStep

private struct OnboardingStep {
    let title: String
    let description: String
    let symbolName: String
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
        .environment(PrinterViewModel())
}
