import SwiftUI
import SwiftData
import UIKit

enum FocusSessionExitAction {
    case close
    case startAnother
}

struct FocusSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .forward)])
    private var tasks: [TaskItem]

    @Bindable var session: FocusSession
    let onExit: (FocusSessionExitAction) -> Void

    @State private var timer: Timer?
    @State private var showEndConfirmation = false
    @State private var showCompletionSheet = false
    @State private var taskAlreadyCredited = false
    @State private var lastSavedElapsed = 0

    private let transition = Animation.easeInOut(duration: 0.25)

    private var linkedTask: TaskItem? {
        guard let taskId = session.taskId else { return nil }
        return tasks.first(where: { $0.id == taskId })
    }

    private var isTimerMode: Bool {
        session.durationSeconds != nil
    }

    private var totalSeconds: Int {
        max(0, session.durationSeconds ?? 0)
    }

    private var remainingSeconds: Int {
        max(0, totalSeconds - session.elapsedSeconds)
    }

    private var progress: CGFloat {
        if isTimerMode {
            guard totalSeconds > 0 else { return 0 }
            return CGFloat(Double(session.elapsedSeconds) / Double(totalSeconds))
        }

        let loop = max(1, session.elapsedSeconds % 60)
        return CGFloat(Double(loop) / 60.0)
    }

    private var titleText: String {
        if let linkedTask {
            return linkedTask.title
        }
        if let label = session.label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        return "Manual focus"
    }

    private var topLabel: String {
        linkedTask == nil ? "Manual focus" : "Focusing on"
    }

    private var timeText: String {
        isTimerMode ? clock(from: remainingSeconds) : clock(from: session.elapsedSeconds)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.canvas(),
                    Theme.surface2.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                VStack(spacing: Theme.Spacing.xxxs) {
                    Text(topLabel)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)

                    Text(titleText)
                        .font(Theme.Typography.titleMedium)
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, Theme.Spacing.lg)

                Spacer(minLength: Theme.Spacing.sm)

                ZStack {
                    Circle()
                        .stroke(Theme.surface2, lineWidth: 14)
                        .frame(width: 268, height: 268)

                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, progress)))
                        .stroke(
                            Theme.accent.opacity(0.86),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 268, height: 268)

                    Text(timeText)
                        .font(.system(size: 62, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                        .minimumScaleFactor(0.35)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                if session.isPaused && !showCompletionSheet {
                    Text("Paused")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Button(session.isPaused ? "Resume" : "Pause") {
                        if session.isPaused {
                            resume()
                        } else {
                            pause()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)

                    Button("End") {
                        showEndConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(showCompletionSheet)
                }

                Spacer()
            }
            .padding(Theme.Spacing.md)
        }
        .alert("End session?", isPresented: $showEndConfirmation) {
            Button("End focus", role: .destructive) {
                endEarly()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("You can start again anytime.")
        }
        .sheet(isPresented: $showCompletionSheet) {
            FocusCompletionSheet(
                taskTitle: linkedTask?.title,
                onMarkDone: {
                    markTaskDone()
                },
                onNotYet: {},
                onStartAnother: {
                    close(with: .startAnother)
                },
                onClose: {
                    close(with: .close)
                }
            )
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if session.endDate == nil, !session.isPaused {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
            persist(force: true)
        }
        .animation(transition, value: session.isPaused)
        .animation(transition, value: showCompletionSheet)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard session.endDate == nil, !session.isPaused else { return }
        session.elapsedSeconds += 1
        persist()

        if isTimerMode, remainingSeconds <= 0 {
            completeByTimer()
        }
    }

    private func pause() {
        guard !session.isPaused else { return }
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()
        session.isPaused = true
        stopTimer()
        persist(force: true)
    }

    private func resume() {
        guard session.endDate == nil else { return }
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        session.isPaused = false
        startTimer()
        persist(force: true)
    }

    private func completeByTimer() {
        guard session.endDate == nil else { return }
        stopTimer()
        session.elapsedSeconds = max(session.elapsedSeconds, totalSeconds)
        session.finalize(at: .now)
        applyTaskCreditIfNeeded()
        persist(force: true)

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        withAnimation(transition) {
            showCompletionSheet = true
        }
    }

    private func endEarly() {
        guard session.endDate == nil else {
            close(with: .close)
            return
        }
        stopTimer()
        session.finalize(at: .now)
        applyTaskCreditIfNeeded()
        persist(force: true)
        close(with: .close)
    }

    private func applyTaskCreditIfNeeded() {
        guard !taskAlreadyCredited else { return }
        taskAlreadyCredited = true
        guard session.elapsedSeconds > 0 else { return }
        guard let task = linkedTask else { return }
        task.focusSeconds += session.elapsedSeconds
    }

    private func markTaskDone() {
        guard let task = linkedTask else { return }
        guard task.state != .completed else { return }
        task.state = .completed
        task.completedAt = .now
        persist(force: true)
    }

    private func persist(force: Bool = false) {
        guard force || abs(session.elapsedSeconds - lastSavedElapsed) >= 5 else { return }
        do {
            try modelContext.save()
            lastSavedElapsed = session.elapsedSeconds
        } catch {
            // Keep UI responsive if persistence fails.
        }
    }

    private func close(with action: FocusSessionExitAction) {
        stopTimer()
        persist(force: true)
        dismiss()
        onExit(action)
    }

    private func clock(from seconds: Int) -> String {
        let safe = max(0, seconds)
        let minutes = safe / 60
        let remainder = safe % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
