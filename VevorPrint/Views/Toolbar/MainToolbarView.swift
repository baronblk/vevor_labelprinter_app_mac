/// MainToolbarView.swift
/// Top toolbar: print, preview, export, undo/redo, and zoom controls.
/// Phase 1: layout and keyboard shortcuts wired up; actions implemented in later phases.

import SwiftUI

// MARK: - MainToolbarView

struct MainToolbarView: ToolbarContent {

    // MARK: - Environment

    @Environment(AppSettings.self)  private var appSettings
    @Environment(PrinterViewModel.self) private var printerVM

    // MARK: - Toolbar Content

    var body: some ToolbarContent {

        // Leading — print controls
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                // Print action — Phase 5
            } label: {
                Label("Drucken", systemImage: "printer")
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printerVM.connectionState != .connected)

            Button {
                // Preview action — Phase 5
            } label: {
                Label("Vorschau", systemImage: "eye")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        // Export
        ToolbarItemGroup(placement: .secondaryAction) {
            Menu {
                Button("Als PNG exportieren…") {
                    // Phase 6
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Als PDF exportieren…") {
                    // Phase 6
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            } label: {
                Label("Exportieren", systemImage: "square.and.arrow.up")
            }
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
