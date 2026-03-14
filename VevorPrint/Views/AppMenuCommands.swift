/// AppMenuCommands.swift
/// Complete macOS menu bar commands wired to the focused window's ViewModels
/// via @FocusedValue (declared in FocusedValueKeys.swift).

import SwiftUI

// MARK: - AppMenuCommands

struct AppMenuCommands: Commands {

    // MARK: - Focused ViewModels

    @FocusedValue(\.labelVM)     var labelVM:     LabelViewModel?
    @FocusedValue(\.printerVM)   var printerVM:   PrinterViewModel?
    @FocusedValue(\.appSettings) var appSettings: AppSettings?

    // MARK: - Commands

    var body: some Commands {

        // MARK: File Menu

        CommandGroup(after: .newItem) {
            Button("Neues Label") {
                if let vm = labelVM {
                    vm.applyLabelSize(vm.labelSize)
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Design exportieren (JSON)...") {
                if let vm = labelVM {
                    ExportService.exportJSON(elements: vm.sortedElements, labelSize: vm.labelSize)
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(labelVM == nil)

            Button("Design importieren (JSON)...") {
                if let vm = labelVM, let result = ExportService.importJSON() {
                    vm.loadTemplate(fromElements: result.elements, labelSize: result.labelSize)
                }
            }
            .disabled(labelVM == nil)
        }

        // MARK: Edit Menu

        CommandGroup(after: .undoRedo) {
            Divider()

            Button("Alles auswaehlen") {
                labelVM?.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(labelVM == nil)

            Button("Auswahl aufheben") {
                labelVM?.clearSelection()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(labelVM == nil)

            Divider()

            Button("Loeschen") {
                labelVM?.deleteSelection()
            }
            .disabled(labelVM?.hasSelection != true)
        }

        // MARK: View Menu

        CommandMenu("Ansicht") {
            Button("Zoom vergroessern") {
                if let s = appSettings { s.canvasZoom = min(4.0, s.canvasZoom + 0.25) }
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom verkleinern") {
                if let s = appSettings { s.canvasZoom = max(0.25, s.canvasZoom - 0.25) }
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Zoom zuruecksetzen") {
                appSettings?.canvasZoom = 1.0
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Button(appSettings?.showRulers == true ? "Lineale ausblenden" : "Lineale einblenden") {
                appSettings?.showRulers.toggle()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // MARK: Label Menu

        CommandMenu("Label") {
            Button("Drucken...") {
                if let vm = labelVM, let pvm = printerVM {
                    Task {
                        await pvm.printLabel(elements: vm.sortedElements, labelSize: vm.labelSize)
                    }
                }
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printerVM?.connectionState != .connected)

            Divider()

            Button("Als PNG exportieren...") {
                if let vm = labelVM {
                    ExportService.exportPNG(elements: vm.sortedElements, labelSize: vm.labelSize)
                }
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(labelVM == nil)

            Button("Als PDF exportieren...") {
                if let vm = labelVM {
                    ExportService.exportPDF(elements: vm.sortedElements, labelSize: vm.labelSize)
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(labelVM == nil)

            Divider()

            Button("Nach vorne") {
                labelVM?.bringForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(labelVM?.hasSelection != true)

            Button("Nach hinten") {
                labelVM?.sendBackward()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(labelVM?.hasSelection != true)

            Button("In den Vordergrund") {
                labelVM?.bringToFront()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(labelVM?.hasSelection != true)

            Button("In den Hintergrund") {
                labelVM?.sendToBack()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(labelVM?.hasSelection != true)
        }

        // MARK: Printer Menu

        CommandMenu("Drucker") {
            Button("Drucker suchen...") {
                printerVM?.startScanning()
            }

            Button("Verbindung trennen") {
                printerVM?.disconnect()
            }
            .disabled(printerVM?.connectionState != .connected)
        }
    }
}
