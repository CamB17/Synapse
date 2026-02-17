import SwiftUI
import SwiftData

struct FocusModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: TaskItem
    let onClose: (() -> Void)?

    @State private var isRunning = false
    @State private var elapsedSeconds: Int = 0
    @State private var startDate: Date?
    @State private var timer: Timer?

    init(task: TaskItem, onClose: (() -> Void)? = nil) {
        self.task = task
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Capsule()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 44, height: 5)

                Spacer()

                Button {
                    close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Text(task.title)
                    .font(.system(size: 20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                Text("Focus mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Text(timeString(elapsedSeconds))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .padding(.top, 6)

            HStack(spacing: 12) {
                Button {
                    if isRunning { pause() } else { start() }
                } label: {
                    Text(isRunning ? "Pause" : "Start")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    endSession()
                } label: {
                    Text("End")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(elapsedSeconds == 0)
            }
            .padding(.horizontal, 18)

            VStack(alignment: .leading, spacing: 8) {
                Text("Total on this task: \(formatMinutes(task.focusSeconds))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Spacer()
        }
        .presentationDetents([.medium, .large])
        .onDisappear { timer?.invalidate() }
        .background(.regularMaterial)
    }

    private func start() {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        isRunning = true
        startDate = .now

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func pause() {
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        isRunning = false
        timer?.invalidate()
        timer = nil
        startDate = nil
    }

    private func endSession() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        // Stop timer
        isRunning = false
        timer?.invalidate()
        timer = nil

        // Persist session
        let session = FocusSession(taskId: task.id, startedAt: .now)
        session.endedAt = .now
        session.durationSeconds = elapsedSeconds

        modelContext.insert(session)

        // Accumulate on task
        task.focusSeconds += elapsedSeconds

        try? modelContext.save()
        close()
    }

    private func close() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        startDate = nil

        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let mins = max(0, seconds) / 60
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return "\(h)h \(m)m"
    }
}
