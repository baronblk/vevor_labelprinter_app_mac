/// TemplateBrowserPanel.swift
/// Sheet panel showing saved label templates from SwiftData.
/// Supports loading, deleting, and saving new templates.

import SwiftUI
import SwiftData

// MARK: - TemplateBrowserPanel

struct TemplateBrowserPanel: View {

    // MARK: - Environment

    @Environment(AppSettings.self)    private var appSettings
    @Environment(LabelViewModel.self) private var labelVM
    @Environment(\.modelContext)      private var modelContext
    @Environment(\.dismiss)           private var dismiss

    // MARK: - SwiftData Query

    @Query(sort: \LabelDocument.updatedAt, order: .reverse)
    private var templates: [LabelDocument]

    // MARK: - State

    @State private var showSaveNameDialog  = false
    @State private var newTemplateName     = ""
    @State private var templateToDelete: LabelDocument? = nil

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if templates.isEmpty {
                emptyState
            } else {
                templateGrid
            }
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 420)
        .alert("Template speichern", isPresented: $showSaveNameDialog) {
            TextField("Name", text: $newTemplateName)
            Button("Speichern") { saveCurrentTemplate() }
                .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Gib dem aktuellen Label-Design einen Namen.")
        }
        .confirmationDialog(
            "Template löschen?",
            isPresented: Binding(
                get: { templateToDelete != nil },
                set: { if !$0 { templateToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let doc = templateToDelete {
                    modelContext.delete(doc)
                    try? modelContext.save()
                    templateToDelete = nil
                }
            }
            Button("Abbrechen", role: .cancel) { templateToDelete = nil }
        } message: {
            if let doc = templateToDelete {
                Text("\"\(doc.name)\" wird unwiderruflich geloescht.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Vorlagen")
                    .font(.headline)
                Text("\(templates.count) gespeicherte Vorlagen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Schließen") { dismiss() }
                .keyboardShortcut(.escape)
        }
        .padding()
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)],
                spacing: 16
            ) {
                ForEach(templates) { doc in
                    TemplateCardView(document: doc) {
                        labelVM.loadTemplate(doc)
                        dismiss()
                    } onDelete: {
                        templateToDelete = doc
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Keine Vorlagen vorhanden")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Speichere das aktuelle Label-Design als Vorlage,\num es hier anzuzeigen.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                newTemplateName = labelVM.labelSize.name
                showSaveNameDialog = true
            } label: {
                Label("Aktuelle Vorlage speichern", systemImage: "plus")
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func saveCurrentTemplate() {
        let name = newTemplateName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        labelVM.saveAsTemplate(name: name, modelContext: modelContext)
        newTemplateName = ""
    }
}

// MARK: - TemplateCardView

/// Single template card in the browser grid.
private struct TemplateCardView: View {

    let document: LabelDocument
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 1)

                if let data = document.thumbnailData,
                   let img  = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(6)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 100)

            // Name
            Text(document.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Size
            Text(String(format: "%.0f × %.0f mm", document.widthMM, document.heightMM))
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Action buttons
            HStack(spacing: 6) {
                Button("Laden") { onLoad() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .controlSize(.mini)
                .foregroundStyle(.red)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Preview

#Preview {
    TemplateBrowserPanel()
        .environment(AppSettings())
        .environment(LabelViewModel())
}
