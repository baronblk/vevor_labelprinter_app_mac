/// ContentView.swift
/// Root view of the application. Implements a three-column NavigationSplitView:
/// left toolbox sidebar | center canvas | right properties sidebar.
/// Also owns the onboarding sheet trigger.

import SwiftUI

struct ContentView: View {

    // MARK: - Environment

    @Environment(AppSettings.self)      private var appSettings
    @Environment(PrinterViewModel.self) private var printerVM

    // MARK: - State

    @State private var columnVisibility  = NavigationSplitViewVisibility.all
    @State private var showOnboarding    = false

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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environment(appSettings)
                .environment(printerVM)
        }
        .onAppear {
            if !appSettings.onboardingCompleted {
                // Small delay so the window renders before presenting the sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showOnboarding = true
                }
            }
        }
        // Re-show onboarding when the user resets settings
        .onChange(of: appSettings.onboardingCompleted) { _, completed in
            if !completed { showOnboarding = true }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .environment(LabelViewModel())
        .environment(PrinterViewModel())
}
