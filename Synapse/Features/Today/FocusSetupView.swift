import SwiftUI
import SwiftData
import Combine
import UIKit

struct FocusSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let tasks: [TaskItem]
    let onSessionLogged: (Int) -> Void
    let onCancel: () -> Void

    @State private var targetMinutes = 15
    @State private var elapsedTime: TimeInterval = 0
    @State private var elapsedSeconds = 0
    @State private var runStartedAt: Date?
    @State private var accumulatedElapsedBeforeCurrentRun: TimeInterval = 0
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var selectedTaskId: UUID?
    @State private var showingTargetPicker = false
    @State private var activeSession: FocusSession?
    @State private var taskCredited = false
    @State private var lastSavedElapsed = 0
    @State private var showingEndConfirmation = false

    private let presets = [10, 15, 25, 45, 60]
    private let transition = Animation.easeInOut(duration: 0.25)
    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var selectedTaskTitle: String {
        guard let selectedTaskId,
              let task = tasks.first(where: { $0.id == selectedTaskId }) else {
            return "None"
        }
        return task.title
    }

    private var remainingSeconds: Int {
        max(0, targetMinutes * 60 - Int(elapsedTime.rounded(.down)))
    }

    private var canStartTimerSession: Bool {
        targetMinutes > 0
    }

    private var centerTimeLabel: String {
        if isRunning {
            return clock(from: remainingSeconds)
        }
        return String(format: "%02d:00", targetMinutes)
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
                topBar

                VStack(spacing: Theme.Spacing.xxxs) {
                    Text("Choose one thing.")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)

                    Text("Or just set a timer.")
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, Theme.Spacing.xs)

                ZStack {
                    FocusRingDialView(
                        targetMinutes: $targetMinutes,
                        elapsedTime: elapsedTime,
                        isRunning: isRunning,
                        maxMinutes: 60,
                        snapIncrement: 5
                    )
                    .allowsHitTesting(!isRunning)
                    .animation(transition, value: isRunning)

                    VStack(spacing: Theme.Spacing.xxxs) {
                        Text(centerTimeLabel)
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text)
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        if isRunning {
                            Text(isPaused ? "Paused" : "Remaining")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .frame(height: 360)

                Button {
                    guard !isRunning else { return }
                    withAnimation(transition) {
                        showingTargetPicker = true
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Focusing on:")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.textSecondary)

                        Text(selectedTaskTitle)
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(Theme.surface2.opacity(0.76))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
                .opacity(isRunning ? 0.6 : 1)
                .animation(transition, value: isRunning)

                presetRow

                Spacer(minLength: 0)

                VStack(spacing: Theme.Spacing.xs) {
                    if isRunning {
                        HStack(spacing: Theme.Spacing.xs) {
                            Button(isPaused ? "Resume" : "Pause") {
                                togglePause()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .font(Theme.Typography.bodySmallStrong)
                            .frame(maxWidth: .infinity)

                            Button("End") {
                                showingEndConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .font(Theme.Typography.bodySmallStrong)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        Button("Start") {
                            startSession()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .font(Theme.Typography.bodySmallStrong)
                        .frame(maxWidth: .infinity)
                        .disabled(targetMinutes <= 0)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .onReceive(ticker) { _ in
            tick()
        }
        .alert("End session?", isPresented: $showingEndConfirmation) {
            Button("End focus", role: .destructive) {
                endSessionAndDismiss()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("You can start again anytime.")
        }
        .onDisappear {
            if isRunning {
                endSession(notify: false)
            }
        }
        .fullScreenCover(isPresented: $showingTargetPicker) {
            FocusTargetPickerView(
                tasks: tasks,
                selectedTaskId: selectedTaskId
            ) { taskId in
                withAnimation(transition) {
                    selectedTaskId = taskId
                    showingTargetPicker = false
                }
            } onClose: {
                withAnimation(transition) {
                    showingTargetPicker = false
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if isRunning {
                    showingEndConfirmation = true
                } else {
                    dismiss()
                    onCancel()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Typography.iconCard)
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Theme.surface2.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text("Focus")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(Theme.text)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 36, height: 36)
        }
    }

    private var presetRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(presets, id: \.self) { preset in
                Button("\(preset)m") {
                    guard !isRunning else { return }
                    withAnimation(transition) {
                        targetMinutes = preset
                    }
                }
                .buttonStyle(.plain)
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(targetMinutes == preset ? Theme.surface : Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    Capsule(style: .continuous)
                        .fill(targetMinutes == preset ? Theme.accent : Theme.surface2.opacity(0.9))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.12), lineWidth: 0.8)
                }
                .disabled(isRunning)
            }
        }
        .opacity(isRunning ? 0.45 : 1)
        .animation(transition, value: isRunning)
    }

    private func startSession() {
        guard !isRunning else { return }
        guard canStartTimerSession else { return }
        let session = FocusSession(
            startDate: .now,
            durationSeconds: targetMinutes * 60,
            elapsedSeconds: 0,
            isPaused: false,
            taskId: selectedTaskId,
            label: nil
        )

        modelContext.insert(session)

        do {
            try modelContext.save()
            activeSession = session
            elapsedTime = 0
            elapsedSeconds = 0
            runStartedAt = .now
            accumulatedElapsedBeforeCurrentRun = 0
            lastSavedElapsed = 0
            taskCredited = false
            withAnimation(transition) {
                isRunning = true
                isPaused = false
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            modelContext.delete(session)
        }
    }

    private func tick() {
        guard isRunning else { return }
        syncElapsedFromClock()
        activeSession?.elapsedSeconds = elapsedSeconds
        activeSession?.isPaused = isPaused
        persistIfNeeded()

        if elapsedTime >= Double(targetMinutes * 60) {
            completeSessionAndReset()
        }
    }

    private func completeSessionAndReset() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        endSession(notify: true)
        withAnimation(transition) {
            elapsedTime = 0
            elapsedSeconds = 0
            accumulatedElapsedBeforeCurrentRun = 0
            runStartedAt = nil
        }
    }

    private func endSessionAndDismiss() {
        endSession(notify: true)
        dismiss()
    }

    private func endSession(notify: Bool) {
        guard let session = activeSession else { return }
        syncElapsedFromClock()
        withAnimation(transition) {
            isRunning = false
            isPaused = false
        }

        session.elapsedSeconds = elapsedSeconds
        session.finalize(at: .now)
        applyTaskCreditIfNeeded()
        persistIfNeeded(force: true)
        activeSession = nil

        if notify, elapsedSeconds > 0 {
            onSessionLogged(max(1, elapsedSeconds / 60))
        }
    }

    private func togglePause() {
        guard isRunning else { return }
        if isPaused {
            runStartedAt = .now
            withAnimation(transition) {
                isPaused = false
            }
        } else {
            syncElapsedFromClock()
            accumulatedElapsedBeforeCurrentRun = elapsedTime
            runStartedAt = nil
            withAnimation(transition) {
                isPaused = true
            }
        }
        activeSession?.isPaused = isPaused
        persistIfNeeded(force: true)
    }

    private func syncElapsedFromClock(now: Date = .now) {
        let activeRunElapsed: TimeInterval
        if isRunning, !isPaused, let runStartedAt {
            activeRunElapsed = max(0, now.timeIntervalSince(runStartedAt))
        } else {
            activeRunElapsed = 0
        }

        let combined = accumulatedElapsedBeforeCurrentRun + activeRunElapsed
        let maxDuration = Double(targetMinutes * 60)
        let clamped = min(maxDuration, max(0, combined))
        elapsedTime = clamped
        elapsedSeconds = Int(clamped.rounded(.down))
    }

    private func applyTaskCreditIfNeeded() {
        guard !taskCredited, elapsedSeconds > 0 else { return }
        guard let selectedTaskId,
              let task = tasks.first(where: { $0.id == selectedTaskId }) else { return }
        taskCredited = true
        task.focusSeconds += elapsedSeconds
    }

    private func persistIfNeeded(force: Bool = false) {
        guard force || abs(elapsedSeconds - lastSavedElapsed) >= 5 else { return }
        do {
            try modelContext.save()
            lastSavedElapsed = elapsedSeconds
        } catch {
            // Keep the UI responsive if saving fails.
        }
    }

    private func clock(from seconds: Int) -> String {
        let safe = max(0, seconds)
        let minutes = safe / 60
        let remainder = safe % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

struct FocusTargetPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [TaskItem]
    let selectedTaskId: UUID?
    let onSelect: (UUID?) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    pickerRow(title: "None", taskId: nil)
                }

                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    let items = sortedTasks.filter { $0.priority == priority }
                    if !items.isEmpty {
                        Section(priority.displayLabel) {
                            ForEach(items) { task in
                                pickerRow(title: task.title, taskId: task.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Focus target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        onClose()
                    }
                }
            }
        }
    }

    private var sortedTasks: [TaskItem] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.sortRank != rhs.priority.sortRank {
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func pickerRow(title: String, taskId: UUID?) -> some View {
        Button {
            onSelect(taskId)
            dismiss()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: selectedTaskId == taskId ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(selectedTaskId == taskId ? Theme.accent : Theme.textSecondary.opacity(0.7))

                Text(title)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
