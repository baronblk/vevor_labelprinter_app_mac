/// View+ConditionalModifier.swift
/// Convenience extension that applies a modifier only when a condition is true.

import SwiftUI

extension View {

    /// Applies the given transform if the condition evaluates to true.
    /// - Parameters:
    ///   - condition: The Boolean condition to evaluate.
    ///   - transform: The view-modifier closure applied when `condition` is `true`.
    /// - Returns: The original or transformed view.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies one of two transforms depending on the condition.
    /// - Parameters:
    ///   - condition: The Boolean condition to evaluate.
    ///   - trueTransform: Applied when condition is `true`.
    ///   - falseTransform: Applied when condition is `false`.
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        then trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }
}
