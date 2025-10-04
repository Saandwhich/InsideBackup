import SwiftUI


struct SurveyRootView: View {
    @Binding var step: OnboardingStep
    var onBackToWelcome: () -> Void

    @StateObject private var manager = SurveyManager()

    var body: some View {
        ZStack {
            if manager.currentIndex < manager.questions.count {
                SurveyQuestionView(
                    manager: manager,
                    question: manager.questions[manager.currentIndex],
                    onBackToWelcome: {
                        step = .welcome
                    },
                    onComplete: {
                        step = .doneSurvey
                    }
                )
                .transition(.opacity)
            } else {
                DoneSurveyView(
                    onBack: {
                        manager.currentIndex = 4
                    },
                    onContinue: {
                        step = .loading
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: manager.currentIndex)
    }
}
