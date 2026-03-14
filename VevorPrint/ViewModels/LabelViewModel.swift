/// LabelViewModel.swift
/// Manages the state of the active label: elements, selection, undo/redo,
/// and the currently chosen label size.
/// Placeholder for Phase 1 — expanded in Phase 3/4.

import Foundation
import Observation
import AppKit

// MARK: - LabelViewModel

@Observable
@MainActor
final class LabelViewModel {

    // MARK: - Label

    /// Currently active label size.
    var labelSize: LabelSize = LabelSize.predefined[0]

    // MARK: - Undo / Redo (wired up in Phase 3)

    let undoManager = UndoManager()

    // MARK: - Init

    init() {}

    // MARK: - Label Size

    /// Applies a new label size, resetting canvas state.
    /// - Parameter size: The new label size to apply.
    func applyLabelSize(_ size: LabelSize) {
        labelSize = size
    }
}
