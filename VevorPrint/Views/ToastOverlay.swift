/// ToastOverlay.swift
/// Floating toast notification that appears at the bottom of the canvas.
/// Uses ToastStore (injected via @Environment) to track the active message.

import SwiftUI

// MARK: - ToastOverlay

struct ToastOverlay: View {

    @Environment(ToastStore.self) private var toastStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear   // full-size transparent background

            if let toast = toastStore.current {
                ToastBanner(toast: toast) {
                    toastStore.dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast.id)
            }
        }
        .allowsHitTesting(toastStore.current != nil)
    }
}

// MARK: - ToastBanner

private struct ToastBanner: View {

    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.symbolName)
                .foregroundStyle(toast.style.tintColor)
                .font(.system(size: 16, weight: .semibold))
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Benachrichtigung schliessen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .frame(maxWidth: 420)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(toast.message)
        .accessibilityAddTraits(.isStaticText)
    }
}
