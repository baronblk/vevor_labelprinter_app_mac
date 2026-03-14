/// VevorPrintApp.swift
/// App entry point. Configures the SwiftData model container and injects
/// shared environment objects into the view hierarchy.

import SwiftUI
import SwiftData

@main
struct VevorPrintApp: App {

    // MARK: - State

    @State private var appSettings = AppSettings()

    // MARK: - SwiftData Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LabelDocument.self,
            CustomLabelSize.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create SwiftData ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            AppMenuCommands()
        }
    }
}
