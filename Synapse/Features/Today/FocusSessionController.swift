import Foundation
import Combine
import SwiftData

enum FocusScreenState: Equatable {
    case setup
    case running
    case paused
}

@MainActor
final class FocusSessionController: ObservableObject {
    @Published var selectedTaskID: UUID? = nil
    @Published var targetMinutes: Int = 0 {
        didSet {
            let clamped = clampMinutes(targetMinutes)
            if clamped != targetMinutes {
                targetMinutes = clamped
                return
            }
            if phase == .setup {
                remainingSeconds = clamped * 60
            }
        }
    }

    @Published private(set) var phase: FocusScreenState = .setup
    @Published private(set) var startedAt: Date?
    @Published private(set) var pauseBeganAt: Date?
    @Published private(set) var pausedAccumulated: TimeInterval = 0
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var lastCompletedSessionMinutes: Int?

    private var activeSession: FocusSession?
    private weak var modelContext: ModelContext?
    private var ticker: Timer?
    private var lastSavedElapsed: Int = 0

    var isCountdownMode: Bool {
        targetMinutes > 0
    }

    var remainingFractionOrNil: Double? {
        guard isCountdownMode else { return nil }
        let total = max(1, targetMinutes * 60)
        return min(1, max(0, Double(remainingSeconds) / Double(total)))
    }

    var runningDisplayTime: String {
        let displayed = isCountdownMode ? remainingSeconds : elapsedSeconds
        return clock(from: displayed)
    }

    func liveElapsed(at now: Date) -> TimeInterval {
        guard let startedAt else { return TimeInterval(max(0, elapsedSeconds)) }

        let pausedWhileCurrentlyPaused: TimeInterval
        if phase == .paused, let pauseBeganAt {
            pausedWhileCurrentlyPaused = max(0, now.timeIntervalSince(pauseBeganAt))
        } else {
            pausedWhileCurrentlyPaused = 0
        }

        let elapsed = now.timeIntervalSince(startedAt) - pausedAccumulated - pausedWhileCurrentlyPaused
        return max(0, elapsed)
    }

    func liveRemaining(at now: Date) -> TimeInterval {
        guard isCountdownMode else { return 0 }
        let total = TimeInterval(max(0, targetMinutes * 60))
        return max(0, total - liveElapsed(at: now))
    }

    func liveProgress(at now: Date) -> Double {
        guard isCountdownMode else { return 0 }
        let total = max(1.0, Double(targetMinutes * 60))
        let elapsed = min(total, max(0, liveElapsed(at: now)))
        return elapsed / total
    }

    func liveDisplayTime(at now: Date) -> String {
        if isCountdownMode {
            return clock(from: Int(liveRemaining(at: now).rounded(.down)))
        }
        return clock(from: Int(liveElapsed(at: now).rounded(.down)))
    }

    func configure(modelContext: ModelContext, existingSession: FocusSession?) {
        self.modelContext = modelContext

        guard let existingSession, existingSession.endDate == nil else {
            if activeSession == nil, phase == .setup {
                targetMinutes = clampMinutes(targetMinutes)
                remainingSeconds = targetMinutes * 60
            }
            return
        }

        if activeSession?.id == existingSession.id {
            if phase == .running {
                syncTime(now: .now, finalizeIfNeeded: true)
                persistIfNeeded()
            }
            return
        }

        attach(to: existingSession)
    }

    func start() {
        guard phase == .setup else { return }
        guard let modelContext else { return }

        let clampedMinutes = clampMinutes(targetMinutes)
        targetMinutes = clampedMinutes
        let durationSeconds = clampedMinutes > 0 ? clampedMinutes * 60 : nil

        let session = FocusSession(
            startDate: .now,
            durationSeconds: durationSeconds,
            elapsedSeconds: 0,
            isPaused: false,
            taskId: selectedTaskID,
            label: nil
        )

        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(session)
            return
        }

        activeSession = session
        phase = .running
        startedAt = session.startDate
        pauseBeganAt = nil
        pausedAccumulated = 0
        elapsedSeconds = 0
        remainingSeconds = durationSeconds ?? 0
        lastSavedElapsed = 0
        beginTicker()
    }

    func pause() {
        guard phase == .running else { return }
        let now = Date()
        syncTime(now: now, finalizeIfNeeded: false)
        phase = .paused
        pauseBeganAt = now
        activeSession?.isPaused = true
        activeSession?.elapsedSeconds = elapsedSeconds
        stopTicker()
        persistIfNeeded(force: true)
    }

    func resume() {
        guard phase == .paused else { return }
        let now = Date()
        if let pauseBeganAt {
            pausedAccumulated += max(0, now.timeIntervalSince(pauseBeganAt))
        }
        self.pauseBeganAt = nil
        phase = .running
        activeSession?.isPaused = false
        syncTime(now: now, finalizeIfNeeded: true)
        beginTicker()
        persistIfNeeded(force: true)
    }

    @discardableResult
    func end() -> Int {
        finalizeSession(notifyCompletion: false)
    }

    func handleViewDisappear() {
        if phase == .running {
            syncTime(now: .now, finalizeIfNeeded: false)
        }
        stopTicker()
        persistIfNeeded(force: true)
    }

    func clearCompletedSessionMarker() {
        lastCompletedSessionMinutes = nil
    }

    func selectTask(_ taskID: UUID?) {
        selectedTaskID = taskID
    }

    func selectNoneTarget() {
        selectedTaskID = nil
    }

    private func attach(to session: FocusSession) {
        activeSession = session
        targetMinutes = clampMinutes((session.durationSeconds ?? 0) / 60)
        selectedTaskID = session.taskId

        let now = Date()
        startedAt = session.startDate
        elapsedSeconds = max(0, session.elapsedSeconds)
        remainingSeconds = max(0, targetMinutes * 60 - elapsedSeconds)
        lastSavedElapsed = elapsedSeconds
        lastCompletedSessionMinutes = nil

        let inferredPaused = max(0, now.timeIntervalSince(session.startDate) - Double(elapsedSeconds))
        pausedAccumulated = inferredPaused

        if session.isPaused {
            phase = .paused
            pauseBeganAt = now
            stopTicker()
        } else {
            phase = .running
            pauseBeganAt = nil
            syncTime(now: now, finalizeIfNeeded: true)
            beginTicker()
        }
    }

    private func beginTicker() {
        stopTicker()
        guard phase == .running else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleTick()
            }
        }

        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func handleTick() {
        guard phase == .running else { return }
        syncTime(now: .now, finalizeIfNeeded: true)
        persistIfNeeded()
    }

    private func syncTime(now: Date, finalizeIfNeeded: Bool) {
        guard let startedAt else { return }

        let pausedWhileCurrentlyPaused: TimeInterval
        if phase == .paused, let pauseBeganAt {
            pausedWhileCurrentlyPaused = max(0, now.timeIntervalSince(pauseBeganAt))
        } else {
            pausedWhileCurrentlyPaused = 0
        }

        let elapsed = max(0, Int((
            now.timeIntervalSince(startedAt)
            - pausedAccumulated
            - pausedWhileCurrentlyPaused
        ).rounded(.down)))

        elapsedSeconds = elapsed
        activeSession?.elapsedSeconds = elapsed

        if targetMinutes > 0 {
            let total = targetMinutes * 60
            remainingSeconds = max(0, total - elapsed)
            if finalizeIfNeeded, elapsed >= total {
                _ = finalizeSession(notifyCompletion: true, completionDate: now)
            }
        } else {
            remainingSeconds = 0
        }
    }

    @discardableResult
    private func finalizeSession(notifyCompletion: Bool, completionDate: Date = .now) -> Int {
        stopTicker()

        if phase == .running {
            syncTime(now: completionDate, finalizeIfNeeded: false)
        }

        let loggedMinutes = elapsedSeconds > 0 ? max(1, elapsedSeconds / 60) : 0

        if let activeSession {
            activeSession.elapsedSeconds = elapsedSeconds
            activeSession.isPaused = true
            activeSession.finalize(at: completionDate)
            applyTaskCreditIfNeeded(taskID: activeSession.taskId, elapsedSeconds: elapsedSeconds)
        }

        persistIfNeeded(force: true)

        phase = .setup
        startedAt = nil
        pauseBeganAt = nil
        pausedAccumulated = 0
        elapsedSeconds = 0
        remainingSeconds = targetMinutes * 60
        activeSession = nil
        lastSavedElapsed = 0

        if notifyCompletion {
            lastCompletedSessionMinutes = loggedMinutes
        }

        return loggedMinutes
    }

    private func applyTaskCreditIfNeeded(taskID: UUID?, elapsedSeconds: Int) {
        guard elapsedSeconds > 0 else { return }
        guard let taskID, let modelContext else { return }

        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.id == taskID }
        )
        descriptor.fetchLimit = 1

        guard let task = try? modelContext.fetch(descriptor).first else { return }
        task.focusSeconds += elapsedSeconds
    }

    private func persistIfNeeded(force: Bool = false) {
        guard let modelContext else { return }
        guard force || abs(elapsedSeconds - lastSavedElapsed) >= 5 else { return }

        do {
            try modelContext.save()
            lastSavedElapsed = elapsedSeconds
        } catch {
            // Keep focus UI responsive even if persistence fails.
        }
    }

    private func clampMinutes(_ value: Int) -> Int {
        min(max(value, 0), 60)
    }

    private func clock(from seconds: Int) -> String {
        let safe = max(0, seconds)
        let minutes = safe / 60
        let remainder = safe % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
