import SwiftUI
import Combine

enum BrainReactionLevel {
    case micro
    case momentum
    case milestone

    var peakScale: CGFloat {
        switch self {
        case .micro: return 1.04
        case .momentum: return 1.08
        case .milestone: return 1.10
        }
    }

    var peakGlow: CGFloat {
        switch self {
        case .micro: return 0.18
        case .momentum: return 0.28
        case .milestone: return 0.38
        }
    }

    var sparkleStrength: CGFloat {
        switch self {
        case .micro: return 0.0
        case .momentum: return 0.62
        case .milestone: return 1.0
        }
    }

    var sparkleOffset: CGSize {
        switch self {
        case .micro: return .zero
        case .momentum: return CGSize(width: 10, height: -14)
        case .milestone: return CGSize(width: 8, height: -20)
        }
    }

    var riseDuration: Double {
        switch self {
        case .micro: return 0.09
        case .momentum: return 0.12
        case .milestone: return 0.14
        }
    }

    var settleDuration: Double {
        switch self {
        case .micro: return 0.14
        case .momentum: return 0.20
        case .milestone: return 0.28
        }
    }

    var cooldown: TimeInterval {
        switch self {
        case .micro: return 0.14
        case .momentum: return 0.18
        case .milestone: return 0.24
        }
    }

    var priority: Int {
        switch self {
        case .micro: return 0
        case .momentum: return 1
        case .milestone: return 2
        }
    }
}

@MainActor
final class BrainReactionController: ObservableObject {
    @Published var scale: CGFloat = 1.0
    @Published var glow: CGFloat = 0.0
    @Published var sparkle: CGFloat = 0.0
    @Published var sparkleOffset: CGSize = .zero

    private var lastTriggerTime: Date = .distantPast
    private var activeLevel: BrainReactionLevel?
    private var settleWorkItem: DispatchWorkItem?
    private var resetWorkItem: DispatchWorkItem?

    func trigger(_ level: BrainReactionLevel) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTriggerTime)
        if elapsed < level.cooldown,
           let activeLevel,
           level.priority <= activeLevel.priority {
            return
        }

        lastTriggerTime = now
        activeLevel = level
        settleWorkItem?.cancel()
        resetWorkItem?.cancel()

        withAnimation(.easeOut(duration: level.riseDuration)) {
            scale = level.peakScale
            glow = level.peakGlow
            sparkle = level.sparkleStrength
            sparkleOffset = level.sparkleOffset
        }

        let settle = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: level.settleDuration)) {
                self.scale = 1.0
                self.glow = 0.0
                self.sparkle = 0.0
            }

            let reset = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.sparkleOffset = .zero
                if self.activeLevel == level {
                    self.activeLevel = nil
                }
            }
            self.resetWorkItem = reset
            DispatchQueue.main.asyncAfter(deadline: .now() + level.settleDuration, execute: reset)
        }

        settleWorkItem = settle
        DispatchQueue.main.asyncAfter(deadline: .now() + level.riseDuration, execute: settle)
    }
}
