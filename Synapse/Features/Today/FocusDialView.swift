import SwiftUI
import UIKit

/// Tiimo-style: knob indicates TARGET, arc fills TOWARD knob as time elapses.
/// - Target range is 0...maxMinutes (default 60).
/// - No wrap: dragging clamps at 0 and max.
struct FocusRingDialView: View {
    @Binding var targetMinutes: Int

    /// External timer state (seconds elapsed since Start, fractional)
    var elapsedTime: TimeInterval
    var isRunning: Bool

    var maxMinutes: Int = 60
    var snapIncrement: Int = 5

    // Visual tuning
    private let strokeWidth: CGFloat = 18
    private let knobSize: CGFloat = 20
    private let padding: CGFloat = 2
    private let transition = Animation.easeInOut(duration: 0.25)

    // Drag state
    @State private var dragTargetProgress: CGFloat? = nil
    @State private var lastProgress: CGFloat? = nil
    @State private var isDraggingOnTrack = false
    @State private var lastSnappedStep: Int = -1

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: size/2, y: size/2)

            // IMPORTANT: arc + knob must share exact same radius math
            let radius = max(0, size/2 - strokeWidth/2 - padding)
            let diameter = radius * 2

            let targetP = currentTargetProgress
            let runningHeadP = runningHeadProgress(targetProgress: targetP)
            let knobProgress = (isRunning && targetMinutes > 0) ? runningHeadP : targetP
            let knobPoint = pointOnCircle(progress: knobProgress, center: center, radius: radius)

            ZStack {
                // Track
                Circle()
                    .stroke(Theme.surface2.opacity(0.95), lineWidth: strokeWidth)
                    .frame(width: diameter, height: diameter)

                // Target preview arc (0 -> target)
                if targetP > 0 {
                    Circle()
                        .trim(from: 0, to: targetP)
                        .stroke(
                            Theme.accent.opacity(0.88),
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .butt,
                                lineJoin: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: diameter, height: diameter)
                        .animation(isRunning ? nil : transition, value: targetP)
                }

                // Running arc (targetP -> headP)  ✅ Tiimo-style
                if isRunning, targetMinutes > 0 {
                    // When elapsed==0 head==target, so this arc length is 0 (that's correct).
                    if runningHeadP > targetP {
                        Circle()
                            .trim(from: targetP, to: runningHeadP)
                            .stroke(
                                Theme.accent.opacity(0.88),
                                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt, lineJoin: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: diameter, height: diameter)
                    }
                }

                // Knob follows the running head while active.
                Circle()
                    .fill(Theme.surface)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle().stroke(Theme.accent.opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: Theme.cardShadow().opacity(0.8), radius: 4, y: 2)
                    .position(knobPoint)
                    .animation(
                        isRunning ? nil : transition,
                        value: knobProgress
                    )
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(dragGesture(center: center, radius: radius))
            .onAppear {
                let step = snappedMinutes(targetMinutes) / max(1, snapIncrement)
                lastSnappedStep = step
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Focus duration dial")
        .accessibilityValue("\(targetMinutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let updated = clampMinutes(targetMinutes + 1)
                targetMinutes = updated
                triggerHapticIfNeeded(for: updated, force: true)
            case .decrement:
                let updated = clampMinutes(targetMinutes - 1)
                targetMinutes = updated
                triggerHapticIfNeeded(for: updated, force: true)
            @unknown default:
                break
            }
        }
    }

    // MARK: - Progress math

    private var currentTargetProgress: CGFloat {
        // target progress is 0..1 based on maxMinutes
        let base = CGFloat(clampMinutes(targetMinutes)) / CGFloat(max(1, maxMinutes))
        return dragTargetProgress ?? base
    }

    /// Returns the moving "head" position on the dial during a running session.
    /// Tiimo-style: head starts at targetProgress and moves toward 1.0 (60m) as time elapses.
    /// - elapsed=0   => head == targetProgress
    /// - elapsed=end => head == 1.0
    private func runningHeadProgress(targetProgress: CGFloat) -> CGFloat {
        guard isRunning else { return targetProgress }
        guard targetMinutes > 0 else { return targetProgress }

        let targetSeconds = targetMinutes * 60
        let fraction = min(1, max(0, elapsedTime / Double(targetSeconds)))

        // Head moves along the remaining arc: targetProgress -> 1.0
        return targetProgress + (1.0 - targetProgress) * CGFloat(fraction)
    }

    // MARK: - Dragging (no wrap)

    private func dragGesture(center: CGPoint, radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                // Don’t allow editing while running (keep it immersive + stable)
                guard !isRunning else { return }

                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let distanceFromCenter = sqrt((dx * dx) + (dy * dy))
                let trackTolerance = strokeWidth * 1.2

                if !isDraggingOnTrack {
                    guard abs(distanceFromCenter - radius) <= trackTolerance else { return }
                    isDraggingOnTrack = true
                    lastProgress = nil
                }

                let rawP = progressFrom(location: value.location, center: center) // 0..1 wrapped
                let boundedP = unwrapAndClampProgress(rawP: rawP)

                dragTargetProgress = boundedP

                let minutes = Int((boundedP * CGFloat(maxMinutes)).rounded())
                let clamped = clampMinutes(minutes)
                if clamped != targetMinutes {
                    targetMinutes = clamped
                    triggerHapticIfNeeded(for: clamped)
                }
            }
            .onEnded { _ in
                guard !isRunning else {
                    dragTargetProgress = nil
                    lastProgress = nil
                    isDraggingOnTrack = false
                    return
                }
                guard isDraggingOnTrack else {
                    dragTargetProgress = nil
                    lastProgress = nil
                    return
                }

                withAnimation(transition) {
                    dragTargetProgress = nil
                }
                lastProgress = nil
                isDraggingOnTrack = false
            }
    }

    /// Convert a touch point to a circular progress (0..1), where 0 is at top.
    private func progressFrom(location: CGPoint, center: CGPoint) -> CGFloat {
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angleFromTop = atan2(dy, dx) + (.pi / 2)
        if angleFromTop < 0 { angleFromTop += 2 * .pi }
        return CGFloat(angleFromTop / (2 * .pi)) // wraps naturally
    }

    /// Prevent wrap: clamp to [0,1] and avoid jumping across 12 o’clock.
    /// Strategy:
    /// - Track lastProgress during drag.
    /// - If a jump > 0.5 happens, treat it as attempting to wrap:
    ///   - If last near 1 and new near 0 => clamp to 1 (user trying to go past max)
    ///   - If last near 0 and new near 1 => clamp to 0 (user trying to go below min)
    private func unwrapAndClampProgress(rawP: CGFloat) -> CGFloat {
        let p = min(1, max(0, rawP))

        guard let last = lastProgress else {
            lastProgress = p
            return p
        }

        let delta = p - last
        // Wrap detection
        if abs(delta) > 0.5 {
            if last > 0.75 && p < 0.25 {
                // would wrap forward past max
                lastProgress = 1.0
                return 1.0
            } else if last < 0.25 && p > 0.75 {
                // would wrap backward below 0
                lastProgress = 0.0
                return 0.0
            }
        }

        lastProgress = p
        return p
    }

    private func pointOnCircle(progress: CGFloat, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = progress * 2 * .pi - (.pi / 2)
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    // MARK: - Minutes + snapping

    private func clampMinutes(_ value: Int) -> Int {
        min(max(value, 0), maxMinutes)
    }

    private func snappedMinutes(_ value: Int) -> Int {
        guard snapIncrement > 0 else { return clampMinutes(value) }
        let nearest = Int((Double(value) / Double(snapIncrement)).rounded()) * snapIncrement
        return clampMinutes(nearest)
    }

    private func triggerHapticIfNeeded(for minutes: Int, force: Bool = false) {
        guard snapIncrement > 0 else { return }
        let step = minutes / snapIncrement
        guard force || step != lastSnappedStep else { return }
        lastSnappedStep = step
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
