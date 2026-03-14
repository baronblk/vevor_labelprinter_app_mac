/// VevorPrintApp.swift
/// App entry point. Configures the SwiftData model container, creates all
/// top-level @Observable instances and injects them into the view hierarchy.

import SwiftUI
import SwiftData

@main
struct VevorPrintApp: App {

    // MARK: - State

    @State private var appSettings   = AppSettings()
    @State private var labelVM       = LabelViewModel()
    @State private var printerVM     = PrinterViewModel()

    // MARK: - SwiftData Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LabelDocument.self,
            CustomLabelSize.self,
            PrinterDevice.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // No recovery possible if the persistent store cannot be opened.
            fatalError("Could not create SwiftData ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
                .environment(labelVM)
                .environment(printerVM)
                .onAppear {
                    printerVM.onAppear(settings: appSettings)
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            AppMenuCommands()
        }
    }
}
