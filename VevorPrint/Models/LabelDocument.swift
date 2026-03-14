/// LabelDocument.swift
/// SwiftData model representing a saved label template. The label elements
/// are serialised to JSON and stored as a single Data blob.

import Foundation
import SwiftData
import AppKit

// MARK: - LabelDocument

@Model
final class LabelDocument {

    // MARK: Properties

    var id: UUID
    var name: String
    /// Width of the label in millimetres.
    var widthMM: Double
    /// Height of the label in millimetres.
    var heightMM: Double
    /// JSON-encoded array of LabelElement payloads.
    var elementsData: Data
    /// PNG thumbnail of the label for the template gallery.
    var thumbnailData: Data?
    var createdAt: Date
    var updatedAt: Date

    // MARK: Init

    init(name: String, widthMM: Double, heightMM: Double, elementsData: Data = Data()) {
        self.id = UUID()
        self.name = name
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.elementsData = elementsData
        self.thumbnailData = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
