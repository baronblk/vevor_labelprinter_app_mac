/// LabelSize.swift
/// Defines predefined label sizes and a SwiftData model for user-defined custom sizes.
/// All dimensions are stored in millimetres.

import Foundation
import SwiftData

// MARK: - Predefined Label Sizes

/// A value type representing a label's physical dimensions in millimetres.
struct LabelSize: Identifiable, Hashable, Codable {

    // MARK: Properties

    let id: UUID
    var name: String
    /// Width in millimetres.
    var widthMM: Double
    /// Height in millimetres.
    var heightMM: Double
    var isCustom: Bool

    // MARK: Init

    init(id: UUID = UUID(), name: String, widthMM: Double, heightMM: Double, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.isCustom = isCustom
    }

    // MARK: Predefined Sizes

    static let predefined: [LabelSize] = [
        LabelSize(name: "40 × 30 mm",            widthMM: 40,  heightMM: 30),
        LabelSize(name: "50 × 30 mm",            widthMM: 50,  heightMM: 30),
        LabelSize(name: "57 × 32 mm (Kasse)",    widthMM: 57,  heightMM: 32),
        LabelSize(name: "60 × 40 mm (Adresse S)", widthMM: 60,  heightMM: 40),
        LabelSize(name: "75 × 40 mm (Adresse)",  widthMM: 75,  heightMM: 40),
        LabelSize(name: "100 × 50 mm (Versand)", widthMM: 100, heightMM: 50),
        LabelSize(name: "100 × 150 mm (Paket)",  widthMM: 100, heightMM: 150),
    ]
}

// MARK: - CustomLabelSize (SwiftData Model)

/// Persisted user-defined label size stored via SwiftData.
@Model
final class CustomLabelSize {

    // MARK: Properties

    var id: UUID
    var name: String
    var widthMM: Double
    var heightMM: Double
    var createdAt: Date

    // MARK: Init

    init(name: String, widthMM: Double, heightMM: Double) {
        self.id = UUID()
        self.name = name
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.createdAt = Date()
    }

    /// Convert to the value-type `LabelSize`.
    func toLabelSize() -> LabelSize {
        LabelSize(id: id, name: name, widthMM: widthMM, heightMM: heightMM, isCustom: true)
    }
}
