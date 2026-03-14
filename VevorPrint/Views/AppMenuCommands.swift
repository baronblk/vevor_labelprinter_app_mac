/// AppMenuCommands.swift
/// macOS menu bar commands. Full menu items are wired up incrementally as
/// features are implemented across phases.

import SwiftUI

// MARK: - AppMenuCommands

struct AppMenuCommands: Commands {

    var body: some Commands {

        // MARK: File Menu

        CommandGroup(after: .newItem) {
            Button("Neues Label") {
                // Phase 3
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Template speichern…") {
                // Phase 6
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Template laden…") {
                // Phase 6
            }
        }

        // MARK: Edit Menu

        CommandGroup(after: .undoRedo) {
            Divider()
            Button("Alles auswählen") {
                // Phase 3
            }
            .keyboardShortcut("a", modifiers: .command)
        }

        // MARK: View Menu

        CommandMenu("Ansicht") {
            Button("Zoom +") {
                // Phase 3
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom −") {
                // Phase 3
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Zoom zurücksetzen") {
                // Phase 3
            }
            .keyboardShortcut("0", modifiers: .command)
        }

        // MARK: Label Menu

        CommandMenu("Label") {
            Button("Drucken") {
                // Phase 5
            }
            .keyboardShortcut("p", modifiers: .command)

            Button("Vorschau") {
                // Phase 5
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("Als PNG exportieren…") {
                // Phase 6
            }
            .keyboardShortcut("e", modifiers: .command)

            Button("Als PDF exportieren…") {
                // Phase 6
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        // MARK: Printer Menu

        CommandMenu("Drucker") {
            Button("Drucker suchen") {
                // Phase 2
            }
            Button("Verbindung trennen") {
                // Phase 2
            }
        }
    }
}
