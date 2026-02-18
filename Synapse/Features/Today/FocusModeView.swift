import SwiftUI
import SwiftData

struct FocusModeView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var task: TaskItem

    let namespace: Namespace.ID
    let heroId: UUID
    let onClose: () -> Void
    let onSessionLogged: ((Int) -> Void)?

    @State private var isRunning = false
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.35))
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: Theme.Spacing.cardInset) {
                heroCard

                timerBlock

                controls

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.cardInset)
        }
        .onDisappear { timer?.invalidate() }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Focus")
                    .font(Theme.Typography.labelSmallStrong)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Button {
                    let haptic = UIImpactFeedbackGenerator(style: .soft)
                    haptic.impactOccurred()
                    withAnimation(.snappy(duration: 0.18)) {
                        onClose()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.Typography.iconXL)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(task.title)
                .font(Theme.Typography.titleMedium)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(Theme.Spacing.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.surface2,
            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        )
        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
        .matchedGeometryEffect(id: heroId, in: namespace)
    }

    private var timerBlock: some View {
        VStack(spacing: Theme.Spacing.compact) {
            Text(timeString(elapsedSeconds))
                .font(Theme.Typography.timerDisplay)
                .contentTransition(.numericText())

            Text("Total on this task: \(formatMinutes(task.focusSeconds))")
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, Theme.Spacing.compact)
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                if isRunning { pause() } else { start() }
            } label: {
                Text(isRunning ? "Pause" : "Start")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.cardInset)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)

            Button {
                endSession()
            } label: {
                Text("End")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.cardInset)
            }
            .buttonStyle(.bordered)
            .disabled(elapsedSeconds == 0)
        }
        .padding(.top, Theme.Spacing.compact)
    }

    private func start() {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        isRunning = true
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
    }

    private func endSession() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        isRunning = false
        timer?.invalidate()
        timer = nil

        let session = FocusSession(taskId: task.id, startedAt: .now)
        session.endedAt = .now
        session.durationSeconds = elapsedSeconds

        modelContext.insert(session)

        task.focusSeconds += elapsedSeconds

        try? modelContext.save()
        onSessionLogged?(max(1, elapsedSeconds / 60))

        withAnimation(.snappy(duration: 0.18)) {
            onClose()
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
