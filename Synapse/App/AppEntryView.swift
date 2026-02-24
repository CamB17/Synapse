import SwiftUI

struct AppEntryView: View {
    @EnvironmentObject private var session: AppSession

    private enum Route: String {
        case auth
        case onboarding
        case app
    }

    private var route: Route {
        if !session.isAuthenticated {
            return .auth
        }

        if !session.hasCompletedOnboarding {
            return .onboarding
        }

        return .app
    }

    var body: some View {
        ZStack {
            switch route {
            case .auth:
                AuthLandingView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingCoordinator {
                    session.completeOnboarding()
                }
                .transition(.onboardingForward)
            case .app:
                RootView()
                    .transition(.opacity)
            }
        }
        .animation(OnboardingMotion.easing, value: route.rawValue)
    }
}
