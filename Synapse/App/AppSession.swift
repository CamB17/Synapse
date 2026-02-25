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

    @Published var shouldShowFirstTodayExperience: Bool {
        didSet {
            defaults.set(shouldShowFirstTodayExperience, forKey: Keys.shouldShowFirstTodayExperience)
        }
    }

    @Published var hasSeenTodayTooltip: Bool {
        didSet {
            defaults.set(hasSeenTodayTooltip, forKey: Keys.hasSeenTodayTooltip)
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let isAuthenticated = "session.isAuthenticated"
        static let hasCompletedOnboarding = "user.hasCompletedOnboarding"
        static let shouldShowFirstTodayExperience = "user.shouldShowFirstTodayExperience"
        static let hasSeenTodayTooltip = "user.hasSeenTodayTooltip"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAuthenticated = defaults.bool(forKey: Keys.isAuthenticated)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.shouldShowFirstTodayExperience = defaults.bool(forKey: Keys.shouldShowFirstTodayExperience)
        self.hasSeenTodayTooltip = defaults.bool(forKey: Keys.hasSeenTodayTooltip)
    }

    func signIn() {
        isAuthenticated = true
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        shouldShowFirstTodayExperience = true
    }

    func restartOnboarding() {
        hasCompletedOnboarding = false
    }

    func consumeFirstTodayExperience() {
        shouldShowFirstTodayExperience = false
    }

    func markTodayTooltipSeen() {
        hasSeenTodayTooltip = true
    }

    func signOut() {
        isAuthenticated = false
    }
}
