/// ToastStore.swift
/// Observable store for non-blocking toast notifications.
/// Inject at app level via `.environment(toastStore)` and access
/// in any view or ViewModel via `@Environment(ToastStore.self)`.

import Foundation
import Observation
import SwiftUI

// MARK: - Toast

/// A single transient notification message.
struct Toast: Identifiable {
    let id       = UUID()
    let message  : String
    let style    : ToastStyle
    let duration : TimeInterval

    enum ToastStyle {
        case info, success, warning, error

        var symbolName: String {
            switch self {
            case .info:    return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error:   return "xmark.circle.fill"
            }
        }

        var tintColor: Color {
            switch self {
            case .info:    return .blue
            case .success: return .green
            case .warning: return .orange
            case .error:   return .red
            }
        }
    }
}

// MARK: - ToastStore

@Observable
@MainActor
final class ToastStore {

    // MARK: State

    /// The currently displayed toast (nil when hidden).
    var current: Toast? = nil

    // MARK: API

    /// Show a toast message.
    ///
    /// - Parameters:
    ///   - message: Human-readable text.
    ///   - style: Visual style (info / success / warning / error). Default: `.info`.
    ///   - duration: Auto-dismiss delay in seconds. Default: 3.
    func show(
        _ message: String,
        style: Toast.ToastStyle = .info,
        duration: TimeInterval = 3
    ) {
        current = Toast(message: message, style: style, duration: duration)
        // Auto-dismiss
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if self?.current?.message == message {
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.current = nil
                }
            }
        }
    }

    /// Dismiss the current toast immediately.
    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { current = nil }
    }
}
