/// OnboardingView.swift
/// First-launch onboarding sheet. Guides the user through Bluetooth permission
/// and initial printer pairing. Fully implemented in Phase 2.

import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    // MARK: - Environment

    @Environment(AppSettings.self)  private var appSettings
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var currentStep = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Header illustration
            Image(systemName: "printer.dotmatrix")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(Color.accentColor)

            Text(steps[currentStep].title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(steps[currentStep].description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()

            HStack {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Weiter") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Fertig") {
                        appSettings.onboardingCompleted = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(32)
        .frame(width: 480, height: 340)
    }

    // MARK: - Steps

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Willkommen bei VevorPrint",
            description: "Entwerfe und drucke professionelle Labels direkt vom Mac auf deinen Vevor-Thermodrucker."
        ),
        OnboardingStep(
            title: "Bluetooth-Berechtigung",
            description: "VevorPrint benötigt Bluetooth, um mit dem Drucker zu kommunizieren. Klicke im nächsten Dialog auf \"Erlauben\"."
        ),
        OnboardingStep(
            title: "Drucker verbinden",
            description: "Schalte den Vevor Y428BT-42B0 ein und stelle sicher, dass er erkennbar ist. VevorPrint sucht automatisch nach verfügbaren Druckern."
        ),
    ]
}

// MARK: - OnboardingStep

private struct OnboardingStep {
    let title: String
    let description: String
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
}
