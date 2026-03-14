/// PropertiesSidebarView.swift
/// Right sidebar showing context-sensitive properties for the selected element.
/// Phase 1 shows a placeholder; full property panels are added in Phase 4.

import SwiftUI

// MARK: - PropertiesSidebarView

struct PropertiesSidebarView: View {

    // MARK: - Environment

    @Environment(LabelViewModel.self) private var labelVM

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Eigenschaften")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        // Phase 1: no elements yet — show empty state
        noSelectionView
    }

    // MARK: - Empty State

    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Kein Element ausgewählt")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Klicke ein Element auf dem Canvas an, um seine Eigenschaften zu bearbeiten.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PropertiesSidebarView()
        .environment(LabelViewModel())
        .frame(width: 260, height: 500)
}
