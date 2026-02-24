import SwiftUI

struct OnboardingMotion {
    static let duration: Double = 0.25
    static let easing = Animation.easeInOut(duration: duration)

    static func stagger(_ index: Int) -> Double {
        Double(index) * 0.07
    }
}

extension AnyTransition {
    static var onboardingForward: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    static var onboardingBackward: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
}
