import SwiftUI

struct SurveyRootView: View {
    @Binding var step: OnboardingStep
    var onBackToWelcome: () -> Void
    @StateObject private var manager = SurveyManager()

    var body: some View {
        ZStack {
            if manager.isSurveyComplete {
                DoneSurveyView(
                    onBack: { manager.currentIndex = max(0, manager.steps.count - 1) },
                    onContinue: { step = .loading }
                )
                .transition(.opacity)
            } else if manager.currentIndex < manager.steps.count {
                let currentStep = manager.steps[manager.currentIndex]

                switch currentStep {
                case .question(let question):
                    SurveyQuestionView(
                        manager: manager,
                        question: question,
                        onBackToWelcome: { step = .welcome },
                        onComplete: { step = .doneSurvey }
                    )
                    .transition(.opacity)

                case .screen(let screen):
                    SurveyScreenView(
                        manager: manager,
                        screen: screen,
                        onBackToWelcome: { step = .welcome },
                        onComplete: { step = .doneSurvey }
                    )
                    .transition(.opacity)
                }
            } else {
                // Fallback if index goes out of bounds unexpectedly
                DoneSurveyView(
                    onBack: { manager.currentIndex = max(0, manager.steps.count - 1) },
                    onContinue: { step = .loading }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: manager.currentIndex)
    }
}
