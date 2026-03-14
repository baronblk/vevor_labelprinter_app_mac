/// ContentView.swift
/// Root view of the application. Implements a three-column NavigationSplitView:
/// left toolbox sidebar | center canvas | right properties sidebar.

import SwiftUI

struct ContentView: View {

    // MARK: - Environment

    @Environment(AppSettings.self) private var appSettings

    // MARK: - State

    @State private var columnVisibility = NavigationSplitViewVisibility.all

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left sidebar — toolbox & label size picker
            ToolboxSidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } content: {
            // Center — label canvas
            LabelCanvasView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 700)
        } detail: {
            // Right sidebar — element properties
            PropertiesSidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        }
        .navigationTitle("VevorPrint")
        .toolbar {
            MainToolbarView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
}
