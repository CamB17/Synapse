import SwiftUI
import UIKit

/// Setup dial for selecting a focus duration.
/// - Range: 0...maxMinutes
/// - Precision: 1 minute
/// - No wrap across the top boundary
struct FocusRingDialView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var targetMinutes: Int

    var maxMinutes: Int = 60
    var snapIncrement: Int = 1
    var hapticIncrement: Int = 5
    var trackColor: Color = Theme.surface2.opacity(0.95)
    var progressColor: Color = Theme.accent.opacity(0.30)
    var knobColor: Color = Theme.surface
    var knobStrokeColor: Color = Theme.accent.opacity(0.34)
    var detailColor: Color = Theme.textSecondary.opacity(0.16)
    var onDragActiveChanged: ((Bool) -> Void)? = nil

    private let strokeWidth: CGFloat = 18
    private let knobSize: CGFloat = 20
    private let padding: CGFloat = 2
    private let majorTickMinutes: [Int] = [15, 30, 45, 60]

    @State private var dragTargetProgress: CGFloat? = nil
    @State private var lastProgress: CGFloat? = nil
    @State private var isDraggingOnTrack = false
    @State private var lastHapticMinute: Int?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)

            // Shared geometry for ring + arc + knob.
            let radius = max(0, size / 2 - strokeWidth / 2 - padding)
            let diameter = radius * 2

            let targetProgress = currentTargetProgress
            let knobPoint = pointOnCircle(progress: targetProgress, center: center, radius: radius)

            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: strokeWidth)
                    .frame(width: diameter, height: diameter)

                Circle()
                    .stroke(detailColor.opacity(0.45), lineWidth: 1)
                    .frame(
                        width: max(0, diameter - (strokeWidth * 0.95)),
                        height: max(0, diameter - (strokeWidth * 0.95))
                    )

                ForEach(majorTickMinutes, id: \.self) { minute in
                    let tickProgress = CGFloat(minute) / CGFloat(max(1, maxMinutes))
                    let tickPoint = pointOnCircle(
                        progress: tickProgress,
                        center: center,
                        radius: radius + (strokeWidth * 0.50)
                    )
                    let isActiveTick = isDraggingOnTrack && nearestMajorTick == minute

                    Capsule(style: .continuous)
                        .fill(detailColor.opacity(isActiveTick ? 0.94 : 0.58))
                        .frame(width: isActiveTick ? 1.8 : 1.2, height: isActiveTick ? 10 : 8)
                        .rotationEffect(.degrees(Double(tickProgress) * 360))
                        .position(tickPoint)
                }

                if targetProgress > 0 {
                    Circle()
                        .trim(from: 0, to: targetProgress)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: diameter, height: diameter)
                        .animation(transitionAnimation, value: targetProgress)
                }

                // Hide the knob at 0 to avoid 0/60 ambiguity.
                if targetMinutes > 0 || dragTargetProgress != nil {
                    Circle()
                        .fill(knobColor)
                        .frame(width: knobSize, height: knobSize)
                        .overlay(
                            Circle().stroke(knobStrokeColor, lineWidth: 1)
                        )
                        .shadow(
                            color: Theme.cardShadow().opacity(isDraggingOnTrack ? 1.0 : 0.8),
                            radius: isDraggingOnTrack ? 7 : 4,
                            y: isDraggingOnTrack ? 3 : 2
                        )
                        .position(knobPoint)
                        .animation(transitionAnimation, value: targetProgress)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(dragGesture(center: center, radius: radius))
            .onAppear {
                let current = clampMinutes(targetMinutes)
                if shouldTriggerHaptic(for: current) {
                    lastHapticMinute = current
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Focus duration dial")
        .accessibilityValue(targetMinutes == 0 ? "No timer" : "\(targetMinutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let updated = clampMinutes(targetMinutes + 1)
                targetMinutes = updated
                triggerHapticIfNeeded(for: updated)
            case .decrement:
                let updated = clampMinutes(targetMinutes - 1)
                targetMinutes = updated
                triggerHapticIfNeeded(for: updated)
            @unknown default:
                break
            }
        }
    }

    private var currentTargetProgress: CGFloat {
        let base = CGFloat(clampMinutes(targetMinutes)) / CGFloat(max(1, maxMinutes))
        return dragTargetProgress ?? base
    }

    private var nearestMajorTick: Int? {
        guard isDraggingOnTrack else { return nil }
        let current = clampMinutes(targetMinutes)
        return majorTickMinutes.min { lhs, rhs in
            abs(lhs - current) < abs(rhs - current)
        }
    }

    private var transitionAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.25)
    }

    private func dragGesture(center: CGPoint, radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let distanceFromCenter = sqrt((dx * dx) + (dy * dy))
                let trackTolerance = strokeWidth * 1.2

                if !isDraggingOnTrack {
                    guard abs(distanceFromCenter - radius) <= trackTolerance else { return }
                    isDraggingOnTrack = true
                    lastProgress = nil
                    onDragActiveChanged?(true)
                }

                let rawProgress = progressFrom(location: value.location, center: center)
                let boundedProgress = unwrapAndClampProgress(rawP: rawProgress)

                dragTargetProgress = boundedProgress

                let rawMinutes = Int((boundedProgress * CGFloat(maxMinutes)).rounded())
                let snapped = snappedMinutes(rawMinutes)
                let clamped = clampMinutes(snapped)
                if clamped != targetMinutes {
                    targetMinutes = clamped
                    triggerHapticIfNeeded(for: clamped)
                }
            }
            .onEnded { _ in
                guard isDraggingOnTrack else {
                    dragTargetProgress = nil
                    lastProgress = nil
                    return
                }

                withAnimation(transitionAnimation) {
                    dragTargetProgress = nil
                }
                lastProgress = nil
                isDraggingOnTrack = false
                onDragActiveChanged?(false)
            }
    }

    private func progressFrom(location: CGPoint, center: CGPoint) -> CGFloat {
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angleFromTop = atan2(dy, dx) + (.pi / 2)
        if angleFromTop < 0 { angleFromTop += 2 * .pi }
        return CGFloat(angleFromTop / (2 * .pi))
    }

    private func unwrapAndClampProgress(rawP: CGFloat) -> CGFloat {
        let progress = min(1, max(0, rawP))

        guard let last = lastProgress else {
            lastProgress = progress
            return progress
        }

        let delta = progress - last
        if abs(delta) > 0.5 {
            if last > 0.75, progress < 0.25 {
                lastProgress = 1
                return 1
            } else if last < 0.25, progress > 0.75 {
                lastProgress = 0
                return 0
            }
        }

        lastProgress = progress
        return progress
    }

    private func pointOnCircle(progress: CGFloat, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = progress * 2 * .pi - (.pi / 2)
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    private func clampMinutes(_ value: Int) -> Int {
        min(max(value, 0), maxMinutes)
    }

    private func snappedMinutes(_ value: Int) -> Int {
        guard snapIncrement > 1 else { return value }
        let nearest = Int((Double(value) / Double(snapIncrement)).rounded()) * snapIncrement
        return nearest
    }

    private func shouldTriggerHaptic(for minutes: Int) -> Bool {
        guard hapticIncrement > 0 else { return false }
        let clamped = clampMinutes(minutes)
        if clamped == 0 || clamped == maxMinutes { return true }
        if [15, 30, 45].contains(clamped) { return true }
        return clamped % hapticIncrement == 0
    }

    private func triggerHapticIfNeeded(for minutes: Int) {
        let clamped = clampMinutes(minutes)
        guard shouldTriggerHaptic(for: clamped) else { return }
        guard lastHapticMinute != clamped else { return }
        lastHapticMinute = clamped
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
