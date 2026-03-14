/// LabelSizePickerView.swift
/// Displays predefined label sizes plus any user-created custom sizes.
/// Selecting an item calls LabelViewModel.applyLabelSize(_:).

import SwiftUI
import SwiftData

// MARK: - LabelSizePickerView

struct LabelSizePickerView: View {

    // MARK: - Environment

    @Environment(LabelViewModel.self) private var labelVM
    @Query(sort: \CustomLabelSize.createdAt) private var customSizes: [CustomLabelSize]

    // MARK: - State

    @State private var showAddCustomSheet = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 2) {
            predefinedList
            if !customSizes.isEmpty {
                Divider().padding(.horizontal)
                customList
            }
            addCustomButton
        }
    }

    // MARK: - Predefined List

    private var predefinedList: some View {
        ForEach(LabelSize.predefined) { size in
            SizeRow(
                size: size,
                isSelected: labelVM.labelSize.id == size.id
            ) {
                labelVM.applyLabelSize(size)
            }
        }
    }

    // MARK: - Custom List

    private var customList: some View {
        ForEach(customSizes) { custom in
            let size = custom.toLabelSize()
            SizeRow(
                size: size,
                isSelected: labelVM.labelSize.id == size.id
            ) {
                labelVM.applyLabelSize(size)
            }
        }
    }

    // MARK: - Add Custom Button

    private var addCustomButton: some View {
        Button {
            showAddCustomSheet = true
        } label: {
            Label("Benutzerdefiniert…", systemImage: "plus")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .sheet(isPresented: $showAddCustomSheet) {
            AddCustomSizeView()
        }
    }
}

// MARK: - SizeRow

private struct SizeRow: View {

    let size: LabelSize
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(size.name)
                    .font(.callout)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AddCustomSizeView

/// Sheet for creating a new custom label size.
private struct AddCustomSizeView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var name   = ""
    @State private var width  = ""
    @State private var height = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Text("Benutzerdefinierte Größe")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                TextField("Breite (mm)", text: $width)
                TextField("Höhe (mm)", text: $height)
            }
            .formStyle(.grouped)

            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Erstellen") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isInputValid)
            }
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Validation

    private var isInputValid: Bool {
        !name.isEmpty
            && Double(width) != nil
            && Double(height) != nil
    }

    // MARK: - Save

    private func save() {
        guard
            let w = Double(width),
            let h = Double(height)
        else { return }

        let custom = CustomLabelSize(name: name, widthMM: w, heightMM: h)
        modelContext.insert(custom)
        dismiss()
    }
}

#Preview {
    LabelSizePickerView()
        .environment(LabelViewModel())
        .frame(width: 220, height: 400)
        .modelContainer(for: CustomLabelSize.self, inMemory: true)
}
