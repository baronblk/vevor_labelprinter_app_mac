/// LabelViewModel.swift
/// Manages all canvas state: the ordered element array, multi-selection,
/// undo/redo stack, z-ordering, and clipboard operations.
/// Fully implemented in Phase 3.

import Foundation
import Observation
import AppKit
import CoreGraphics

// MARK: - LabelViewModel

@Observable
@MainActor
final class LabelViewModel {

    // MARK: - Label Properties

    var labelSize: LabelSize = LabelSize.predefined[0]

    // MARK: - Elements

    /// All elements on the canvas, sorted by zIndex ascending.
    var elements: [AnyLabelElement] = []

    var sortedElements: [AnyLabelElement] {
        elements.sorted { $0.zIndex < $1.zIndex }
    }

    // MARK: - Selection

    /// IDs of currently selected elements (supports multi-select via Shift-click).
    var selectedIDs: Set<UUID> = []

    var selectedElements: [AnyLabelElement] {
        elements.filter { selectedIDs.contains($0.id) }
    }

    var firstSelected: AnyLabelElement? {
        elements.first { selectedIDs.contains($0.id) }
    }

    var hasSelection: Bool { !selectedIDs.isEmpty }

    // MARK: - Interaction State

    /// True during an active drag/resize — suppresses intermediate undo snapshots.
    var isInteracting = false

    // MARK: - Undo / Redo

    private let undoManager = UndoManager()

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }

    // MARK: - Clipboard

    private var clipboard: [AnyLabelElement] = []

    // MARK: - Init

    init() {}

    // MARK: - Label Size

    /// Replaces the active label size and clears the canvas.
    /// - Parameter size: New label size to apply.
    func applyLabelSize(_ size: LabelSize) {
        let snapshot = elements
        registerUndo(actionName: "Labelgrösse aendern") {
            self.elements = snapshot
            self.selectedIDs = []
        }
        labelSize = size
        elements = []
        selectedIDs = []
    }

    // MARK: - Element CRUD

    /// Add a new element to the canvas and select it.
    /// - Parameter element: The element wrapped in AnyLabelElement.
    func addElement(_ element: AnyLabelElement) {
        var el = element
        el.zIndex = (elements.map(\.zIndex).max() ?? -1) + 1
        let snapshot = elements
        registerUndo(actionName: "Element hinzufuegen") {
            self.elements = snapshot
            self.selectedIDs = []
        }
        elements.append(el)
        selectedIDs = [el.id]
    }

    /// Remove elements with the given IDs.
    /// - Parameter ids: The set of IDs to delete.
    func removeElements(ids: Set<UUID>) {
        let snapshot = elements
        let selSnapshot = selectedIDs
        registerUndo(actionName: "Element loeschen") {
            self.elements = snapshot
            self.selectedIDs = selSnapshot
        }
        elements.removeAll { ids.contains($0.id) }
        selectedIDs.subtract(ids)
    }

    /// Delete all currently selected elements.
    func deleteSelection() {
        removeElements(ids: selectedIDs)
    }

    /// Replace an existing element in-place (matched by id).
    /// - Parameters:
    ///   - updated: Updated AnyLabelElement with the same id.
    ///   - undoName: Label shown in Edit menu for this action.
    func updateElement(_ updated: AnyLabelElement, undoName: String = "Element bearbeiten") {
        guard let idx = elements.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = elements[idx]
        registerUndo(actionName: undoName) {
            if let i = self.elements.firstIndex(where: { $0.id == old.id }) {
                self.elements[i] = old
            }
        }
        elements[idx] = updated
    }

    // MARK: - Frame helpers

    /// Translate selected elements by a delta (mm). Optionally snaps to grid.
    /// Does NOT register an undo snapshot — call `commitMove()` when the drag ends.
    /// - Parameters:
    ///   - delta: Translation in mm.
    ///   - snapGrid: Snap interval in mm; 0 disables snapping.
    func moveSelection(by delta: CGSize, snapGrid: CGFloat = 0) {
        for id in selectedIDs {
            guard let idx = elements.firstIndex(where: { $0.id == id }) else { continue }
            var el = elements[idx]
            var newOrigin = CGPoint(
                x: el.frame.origin.x + delta.width,
                y: el.frame.origin.y + delta.height
            )
            if snapGrid > 0 {
                newOrigin.x = (newOrigin.x / snapGrid).rounded() * snapGrid
                newOrigin.y = (newOrigin.y / snapGrid).rounded() * snapGrid
            }
            // Clamp to label bounds
            newOrigin.x = max(0, min(newOrigin.x, labelSize.widthMM  - el.frame.width))
            newOrigin.y = max(0, min(newOrigin.y, labelSize.heightMM - el.frame.height))
            el.frame.origin = newOrigin
            elements[idx] = el
        }
    }

    /// Record an undo snapshot after a completed drag.
    func commitMove() {
        let snapshot = elements
        registerUndo(actionName: "Verschieben") { self.elements = snapshot }
    }

    // MARK: - Selection

    /// Select an element, optionally adding to the existing selection.
    /// - Parameters:
    ///   - id: Element UUID.
    ///   - addToSelection: If true, toggles; if false, replaces the selection.
    func select(id: UUID, addToSelection: Bool = false) {
        if addToSelection {
            if selectedIDs.contains(id) { selectedIDs.remove(id) }
            else { selectedIDs.insert(id) }
        } else {
            selectedIDs = [id]
        }
    }

    /// Deselect all elements.
    func clearSelection() { selectedIDs = [] }

    /// Select every element on the canvas.
    func selectAll() { selectedIDs = Set(elements.map(\.id)) }

    // MARK: - Z-Order

    /// Move selected elements one step towards the front.
    func bringForward() { adjustZOrder(offset: +1, name: "Nach vorne") }

    /// Move selected elements one step towards the back.
    func sendBackward() { adjustZOrder(offset: -1, name: "Nach hinten") }

    /// Bring selected elements to the absolute front.
    func bringToFront() {
        let maxZ = (elements.map(\.zIndex).max() ?? 0) + 1
        for id in selectedIDs {
            guard let idx = elements.firstIndex(where: { $0.id == id }) else { continue }
            elements[idx].zIndex = maxZ
        }
        normaliseZIndices()
    }

    /// Push selected elements to the absolute back.
    func sendToBack() {
        let minZ = (elements.map(\.zIndex).min() ?? 0) - 1
        for id in selectedIDs {
            guard let idx = elements.firstIndex(where: { $0.id == id }) else { continue }
            elements[idx].zIndex = minZ
        }
        normaliseZIndices()
    }

    private func adjustZOrder(offset: Int, name: String) {
        let snapshot = elements
        registerUndo(actionName: name) { self.elements = snapshot }
        for id in selectedIDs {
            guard let idx = elements.firstIndex(where: { $0.id == id }) else { continue }
            elements[idx].zIndex += offset
        }
        normaliseZIndices()
    }

    private func normaliseZIndices() {
        let sorted = elements.sorted { $0.zIndex < $1.zIndex }
        for (newZ, el) in sorted.enumerated() {
            guard let idx = elements.firstIndex(where: { $0.id == el.id }) else { continue }
            elements[idx].zIndex = newZ
        }
    }

    // MARK: - Clipboard

    /// Copy selected elements.
    func copy() { clipboard = selectedElements }

    /// Cut selected elements.
    func cut() { copy(); deleteSelection() }

    /// Paste clipboard with a small offset.
    func paste() {
        let offset: CGFloat = 3
        var newElements: [AnyLabelElement] = []
        for var el in clipboard {
            el.frame.origin.x += offset
            el.frame.origin.y += offset
            newElements.append(reassignID(el))
        }
        let snapshot = elements
        registerUndo(actionName: "Einfuegen") { self.elements = snapshot }
        elements.append(contentsOf: newElements)
        selectedIDs = Set(newElements.map(\.id))
    }

    /// Returns a copy of `el` with a freshly generated UUID.
    private func reassignID(_ el: AnyLabelElement) -> AnyLabelElement {
        switch el.elementType {
        case .text:
            var t = el.unwrap(as: TextElement.self)!; t.id = UUID()
            return AnyLabelElement(t)
        case .image:
            var t = el.unwrap(as: ImageElement.self)!; t.id = UUID()
            return AnyLabelElement(t)
        case .qrCode:
            var t = el.unwrap(as: QRCodeElement.self)!; t.id = UUID()
            return AnyLabelElement(t)
        case .barcode:
            var t = el.unwrap(as: BarcodeElement.self)!; t.id = UUID()
            return AnyLabelElement(t)
        case .line:
            var t = el.unwrap(as: LineElement.self)!; t.id = UUID()
            return AnyLabelElement(t)
        }
    }

    // MARK: - Undo / Redo

    func undo() { undoManager.undo() }
    func redo() { undoManager.redo() }

    private func registerUndo(actionName: String, closure: @escaping () -> Void) {
        undoManager.setActionName(actionName)
        undoManager.registerUndo(withTarget: self) { _ in closure() }
    }

    // MARK: - Serialisation

    /// Encode all elements to JSON for SwiftData storage.
    func encodeElements() -> Data {
        (try? JSONEncoder().encode(elements)) ?? Data()
    }

    /// Restore elements from a JSON blob.
    /// - Parameter data: Previously encoded elements Data.
    func loadElements(from data: Data) {
        elements = (try? JSONDecoder().decode([AnyLabelElement].self, from: data)) ?? []
    }
}

// MARK: - Convenience Add Factories

extension LabelViewModel {

    func addTextElement() {
        var el = TextElement()
        el.frame = CGRect(
            x: max(0, (labelSize.widthMM - 40) / 2),
            y: max(0, (labelSize.heightMM - 10) / 2),
            width: min(40, labelSize.widthMM - 4),
            height: min(10, labelSize.heightMM - 4)
        )
        addElement(AnyLabelElement(el))
    }

    func addQRCodeElement() {
        let size = min(labelSize.widthMM, labelSize.heightMM) * 0.4
        var el = QRCodeElement()
        el.frame = CGRect(
            x: (labelSize.widthMM - size) / 2,
            y: (labelSize.heightMM - size) / 2,
            width: size, height: size
        )
        addElement(AnyLabelElement(el))
    }

    func addBarcodeElement() {
        var el = BarcodeElement()
        el.frame = CGRect(
            x: (labelSize.widthMM - 50) / 2,
            y: (labelSize.heightMM - 15) / 2,
            width: min(50, labelSize.widthMM - 4),
            height: 15
        )
        addElement(AnyLabelElement(el))
    }

    func addImageElement() {
        let size = min(labelSize.widthMM, labelSize.heightMM) * 0.5
        var el = ImageElement()
        el.frame = CGRect(
            x: (labelSize.widthMM - size) / 2,
            y: (labelSize.heightMM - size) / 2,
            width: size, height: size
        )
        addElement(AnyLabelElement(el))
    }

    func addLineElement() {
        var el = LineElement()
        el.frame = CGRect(
            x: 2,
            y: labelSize.heightMM / 2,
            width: labelSize.widthMM - 4,
            height: 0.5
        )
        addElement(AnyLabelElement(el))
    }
}
