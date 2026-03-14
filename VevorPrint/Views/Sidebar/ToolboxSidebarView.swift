/// ToolboxSidebarView.swift
/// Left sidebar: element toolbox buttons, label-size picker, and printer status.
/// Full interactivity is added in Phase 2 (printer status) and Phase 3/4 (toolbox).

import SwiftUI

// MARK: - ToolboxSidebarView

struct ToolboxSidebarView: View {

    // MARK: - Environment

    @Environment(AppSettings.self)  private var appSettings
    @Environment(LabelViewModel.self)  private var labelVM
    @Environment(PrinterViewModel.self) private var printerVM

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            labelSizeSection
            Divider()
            toolboxSection
            Spacer()
            Divider()
            printerStatusSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Label Size Section

    private var labelSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Labelgröße")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            LabelSizePickerView()
        }
    }

    // MARK: - Toolbox Section

    private var toolboxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elemente")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ToolboxItem.allCases) { item in
                    ToolboxButton(item: item) {
                        addElement(for: item)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Printer Status Section

    private var printerStatusSection: some View {
        HStack(spacing: 8) {
            Image(systemName: printerVM.connectionState.symbolName)
                .foregroundStyle(connectionStateColor)
            Text(printerVM.connectionState.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var connectionStateColor: Color {
        printerVM.connectionState.color
    }

    // MARK: - Element Factories

    private func addElement(for item: ToolboxItem) {
        switch item {
        case .text:    labelVM.addTextElement()
        case .image:   labelVM.addImageElement()
        case .qrCode:  labelVM.addQRCodeElement()
        case .barcode: labelVM.addBarcodeElement()
        case .line:    labelVM.addLineElement()
        }
    }
}

// MARK: - ToolboxItem

enum ToolboxItem: String, CaseIterable, Identifiable {
    case text    = "Text"
    case image   = "Bild"
    case qrCode  = "QR-Code"
    case barcode = "Barcode"
    case line    = "Linie"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .text:    return "textformat"
        case .image:   return "photo"
        case .qrCode:  return "qrcode"
        case .barcode: return "barcode"
        case .line:    return "minus"
        }
    }
}

// MARK: - ToolboxButton

private struct ToolboxButton: View {

    let item: ToolboxItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: item.symbolName)
                    .font(.title2)
                Text(item.rawValue)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    ToolboxSidebarView()
        .environment(AppSettings())
        .environment(LabelViewModel())
        .environment(PrinterViewModel())
        .frame(width: 220, height: 600)
}
