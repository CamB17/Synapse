import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated: Bool {
        didSet {
            defaults.set(isAuthenticated, forKey: Keys.isAuthenticated)
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let isAuthenticated = "session.isAuthenticated"
        static let hasCompletedOnboarding = "user.hasCompletedOnboarding"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAuthenticated = defaults.bool(forKey: Keys.isAuthenticated)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func signIn() {
        isAuthenticated = true
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func restartOnboarding() {
        hasCompletedOnboarding = false
    }

    func signOut() {
        isAuthenticated = false
    }
}
