/// FocusedValueKeys.swift
/// Declares FocusedValues keys so AppMenuCommands can read the active
/// window's ViewModels without direct environment injection.

import SwiftUI

// MARK: - FocusedValues: LabelViewModel

private struct LabelVMKey: FocusedValueKey {
    typealias Value = LabelViewModel
}

private struct PrinterVMKey: FocusedValueKey {
    typealias Value = PrinterViewModel
}

private struct AppSettingsKey: FocusedValueKey {
    typealias Value = AppSettings
}

extension FocusedValues {

    /// The active window's LabelViewModel.
    var labelVM: LabelViewModel? {
        get { self[LabelVMKey.self] }
        set { self[LabelVMKey.self] = newValue }
    }

    /// The active window's PrinterViewModel.
    var printerVM: PrinterViewModel? {
        get { self[PrinterVMKey.self] }
        set { self[PrinterVMKey.self] = newValue }
    }

    /// The active window's AppSettings.
    var appSettings: AppSettings? {
        get { self[AppSettingsKey.self] }
        set { self[AppSettingsKey.self] = newValue }
    }
}
