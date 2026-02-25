import SwiftUI

enum FocusAnim {
    static let fast = 0.18
    static let med = 0.28
    static let slow = 0.45

    static let easeFast = Animation.easeOut(duration: fast)
    static let easeMed = Animation.easeInOut(duration: med)
    static let springEnter = Animation.spring(response: 0.45, dampingFraction: 0.92, blendDuration: 0.12)
    static let springPress = Animation.spring(response: 0.20, dampingFraction: 0.85)

    static func easedFast(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : easeFast
    }

    static func easedMed(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : easeMed
    }

    static func springedEnter(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : springEnter
    }

    static func springedPress(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0) : springPress
    }
}
