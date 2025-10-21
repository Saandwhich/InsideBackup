import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.step {
            case .splash:
                SplashScreenView {
                    withAnimation { appState.step = .welcome }
                }

            case .welcome:
                WelcomeView {
                    withAnimation {
                        // Reset survey to first step on start
                        SurveyManager().clearDraft() // clear any persisted draft
                        appState.step = .survey
                    }
                }

            case .survey:
                SurveyRootView(
                    step: Binding(get: { appState.step }, set: { appState.step = $0 }),
                    onBackToWelcome: { appState.step = .welcome }
                )

            case .doneSurvey:
                DoneSurveyView(
                    onBack: { appState.step = .survey },
                    onContinue: { appState.step = .loading }
                )

            case .loading:
                LoadingProfileView {
                    appState.step = .profileCreated
                }

            case .profileCreated:
                ProfileCreatedView {
                    appState.step = .mainApp
                }

            case .mainApp:
                MainAppView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: appState.step)
    }
}
