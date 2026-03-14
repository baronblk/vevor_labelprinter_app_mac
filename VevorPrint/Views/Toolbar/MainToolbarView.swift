/// MainToolbarView.swift
/// Top toolbar: print, preview, export, undo/redo, and zoom controls.

import SwiftUI

// MARK: - MainToolbarView

struct MainToolbarView: ToolbarContent {

    // MARK: - Environment

    @Environment(AppSettings.self)      private var appSettings
    @Environment(LabelViewModel.self)   private var labelVM
    @Environment(PrinterViewModel.self) private var printerVM
    @Environment(ToastStore.self)       private var toastStore

    // MARK: - Bindings

    @Binding var showPreview: Bool
    @Binding var showTemplates: Bool

    // MARK: - Toolbar Content

    var body: some ToolbarContent {

        // Leading — print controls
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task {
                    await printerVM.printLabel(
                        elements: labelVM.sortedElements,
                        labelSize: labelVM.labelSize,
                        toastStore: toastStore
                    )
                }
            } label: {
                if printerVM.isPrinting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Drucken", systemImage: "printer")
                }
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printerVM.connectionState != .connected || printerVM.isPrinting)
            .help("Label drucken (⌘P)")

            Button {
                showPreview = true
            } label: {
                Label("Vorschau", systemImage: "eye")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help("Druckvorschau (⇧⌘P)")
        }

        // Templates & Export
        ToolbarItemGroup(placement: .secondaryAction) {
            Button {
                showTemplates = true
            } label: {
                Label("Vorlagen", systemImage: "square.stack.3d.up")
            }
            .help("Vorlagenbibliothek (⌘T)")
            .keyboardShortcut("t", modifiers: .command)

            Menu {
                Button("Als PNG exportieren…") {
                    ExportService.exportPNG(
                        elements: labelVM.sortedElements,
                        labelSize: labelVM.labelSize
                    )
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Als PDF exportieren…") {
                    ExportService.exportPDF(
                        elements: labelVM.sortedElements,
                        labelSize: labelVM.labelSize
                    )
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Design exportieren (JSON)…") {
                    ExportService.exportJSON(
                        elements: labelVM.sortedElements,
                        labelSize: labelVM.labelSize
                    )
                }

                Button("Design importieren (JSON)…") {
                    if let result = ExportService.importJSON() {
                        labelVM.loadTemplate(fromElements: result.elements, labelSize: result.labelSize)
                    }
                }
            } label: {
                Label("Exportieren", systemImage: "square.and.arrow.up")
            }
            .help("Exportieren / Importieren")
        }

        // Zoom
        ToolbarItemGroup(placement: .secondaryAction) {
            Menu {
                ForEach(ZoomLevel.allCases) { level in
                    Button(level.label) {
                        appSettings.canvasZoom = level.value
                    }
                }
            } label: {
                Text("\(Int(appSettings.canvasZoom * 100)) %")
                    .monospacedDigit()
                    .frame(minWidth: 52)
            }
            .help("Zoom")
        }

        // Bluetooth status (trailing)
        ToolbarItem(placement: .status) {
            BluetoothStatusView()
        }
    }
}

// MARK: - ZoomLevel

enum ZoomLevel: CaseIterable, Identifiable {
    case p50, p75, p100, p150, p200, fit

    var id: Self { self }

    var value: Double {
        switch self {
        case .p50:  return 0.5
        case .p75:  return 0.75
        case .p100: return 1.0
        case .p150: return 1.5
        case .p200: return 2.0
        case .fit:  return 1.0   // fit logic handled in canvas
        }
    }

    var label: String {
        switch self {
        case .p50:  return "50 %"
        case .p75:  return "75 %"
        case .p100: return "100 %"
        case .p150: return "150 %"
        case .p200: return "200 %"
        case .fit:  return "Einpassen"
        }
    }
}
