/// PrintPreviewPanel.swift
/// Sheet showing a high-resolution rendered preview of the label before printing.
/// Renders at 150 dpi for fast display; the actual print uses the DPI from AppSettings.

import SwiftUI

// MARK: - PrintPreviewPanel

struct PrintPreviewPanel: View {

    // MARK: - Environment

    @Environment(AppSettings.self)     private var appSettings
    @Environment(LabelViewModel.self)  private var labelVM
    @Environment(PrinterViewModel.self) private var printerVM

    // MARK: - State

    @State private var previewImage: CGImage? = nil
    @State private var isRendering = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            previewArea
            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 400)
        .task { await generatePreview() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Druckvorschau")
                    .font(.headline)
                Text("\(labelVM.labelSize.name) · \(Int(appSettings.printDPI)) dpi")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Schließen") { dismiss() }
                .keyboardShortcut(.escape)
        }
        .padding()
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)

            if isRendering {
                ProgressView("Vorschau wird generiert…")
            } else if let img = previewImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(img, scale: 1.0, label: Text("Vorschau"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                        .padding(32)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Vorschau konnte nicht erstellt werden.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Print progress
            if printerVM.isPrinting {
                HStack(spacing: 8) {
                    ProgressView(value: printerVM.printProgress)
                        .frame(width: 120)
                    Text("\(Int(printerVM.printProgress * 100)) %")
                        .monospacedDigit()
                        .font(.callout)
                }
            } else {
                ConnectionBadge(state: printerVM.connectionState)
            }

            Spacer()

            Button("Vorschau aktualisieren") {
                Task { await generatePreview() }
            }
            .disabled(isRendering)

            Button {
                Task {
                    dismiss()
                    await printerVM.printLabel(
                        elements: labelVM.sortedElements,
                        labelSize: labelVM.labelSize
                    )
                }
            } label: {
                Label("Drucken", systemImage: "printer.filled")
            }
            .buttonStyle(.borderedProminent)
            .disabled(printerVM.connectionState != .connected || printerVM.isPrinting)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    // MARK: - Preview Generation

    private func generatePreview() async {
        isRendering = true
        defer { isRendering = false }

        // ImageRenderer must run on main actor — already there via @MainActor on LabelRenderer
        previewImage = LabelRenderer.render(
            elements: labelVM.sortedElements,
            labelSize: labelVM.labelSize,
            dpi: 150          // fast preview quality
        )
    }
}

// MARK: - ConnectionBadge

/// Compact inline connection status indicator.
private struct ConnectionBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
            Text(state.rawValue)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    PrintPreviewPanel()
        .environment(AppSettings())
        .environment(LabelViewModel())
        .environment(PrinterViewModel())
}
