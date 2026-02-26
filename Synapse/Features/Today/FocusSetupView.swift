import SwiftUI
import SwiftData
import UIKit

enum FocusTargetSelection: Equatable {
    case none
    case task(UUID)
}

struct FocusFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<FocusSession> { $0.endDate == nil },
        sort: [SortDescriptor(\FocusSession.startDate, order: .reverse)]
    )
    private var activeSessions: [FocusSession]

    let tasks: [TaskItem]
    let onSessionLogged: (Int) -> Void
    let onCancel: () -> Void

    @StateObject private var focus = FocusSessionController()
    @State private var showingTargetPicker = false
    @State private var showingThemePicker = false
    @State private var showingTuneInSheet = false
    @State private var showingEndConfirmation = false

    @State private var displayPhase: FocusScreenState = .setup
    @State private var isStartTransitioning = false

    @State private var isDialDragging = false
    @State private var setupDialOpacity = 1.0
    @State private var setupDialScale: CGFloat = 1.0
    @State private var setupDialBlur: CGFloat = 0
    @State private var setupTimeScale: CGFloat = 1.0
    @State private var startButtonScale: CGFloat = 1.0

    @State private var runningTimeOpacity = 1.0
    @State private var runningTimeScale: CGFloat = 1.0
    @State private var runningControlsIntroOpacity = 1.0
    @State private var runningProgressIntroOpacity = 1.0
    @State private var runningProgressIntroScaleX: CGFloat = 1.0
    @State private var pauseResumeBlinkToken = 0

    @State private var lastInteractionDate = Date()
    @State private var isIdle = false
    @State private var idleMonitorTask: Task<Void, Never>?

    @State private var completionGlowOpacity = 0.06
    @State private var showCompletionText = false
    @State private var frozenRunningTime: String?
    @State private var showingCompletionOverlay = false
    @State private var completionAutoDismissTask: Task<Void, Never>?

    @StateObject private var soundscapePlayer = FocusSoundscapePlayer()

    @Namespace private var timeNamespace

    @AppStorage("focus_theme") private var focusThemeRaw: String = FocusBackgroundTheme.clean.rawValue
    @AppStorage("focusTheme") private var legacyFocusThemeRaw: String = ""
    @AppStorage("did_set_initial_focus_duration") private var didSetInitialFocusDuration = false
    @AppStorage("focus_last_duration") private var focusLastDuration = 15
    @AppStorage("focus_has_saved_duration") private var hasSavedFocusDuration = false
    @AppStorage("focus_soundscape") private var focusSoundscapeRaw: String = FocusSoundscape.none.rawValue
    @AppStorage("focus_music_autoplay") private var focusMusicAutoplay = true
    @AppStorage("focus_music_volume") private var focusMusicVolumeRaw: String = FocusSoundVolumeLevel.medium.rawValue

    private var latestActiveSession: FocusSession? {
        activeSessions.first
    }

    private var activeSessionIdentifier: UUID? {
        latestActiveSession?.id
    }

    private var focusTheme: FocusBackgroundTheme {
        FocusBackgroundTheme(rawValue: focusThemeRaw) ?? .clean
    }

    private var themeBinding: Binding<FocusBackgroundTheme> {
        Binding(
            get: { focusTheme },
            set: { focusThemeRaw = $0.rawValue }
        )
    }

    private var tokens: FocusThemeTokens {
        focusTheme.tokens
    }

    private var setupTargetTitle: String {
        if let selectedTaskID = focus.selectedTaskID,
           let selectedTask = tasks.first(where: { $0.id == selectedTaskID }) {
            return selectedTask.title
        }
        return "None"
    }

    private var runningFocusTitle: String {
        if let selectedTaskID = focus.selectedTaskID,
           let selectedTask = tasks.first(where: { $0.id == selectedTaskID }) {
            return selectedTask.title
        }
        return "Just focusing"
    }

    private var setupTimeTitle: String {
        if focus.targetMinutes == 0 { return "No timer" }
        return String(format: "%02d:00", focus.targetMinutes)
    }

    private var setupTimeCaption: String {
        focus.targetMinutes == 0 ? "Open-ended" : "min"
    }

    private var selectedSoundscape: FocusSoundscape {
        FocusSoundscape(rawValue: focusSoundscapeRaw) ?? .none
    }

    private var selectedVolumeLevel: FocusSoundVolumeLevel {
        FocusSoundVolumeLevel(rawValue: focusMusicVolumeRaw) ?? .medium
    }

    private var tuneInSubtitle: String {
        if selectedSoundscape == .none {
            return "Off"
        }
        return selectedSoundscape.displayName
    }

    private var isTuneInEnabled: Bool {
        selectedSoundscape != .none
    }

    private func runningAccessibilityValue(at now: Date) -> String {
        let displayedSeconds = focus.isCountdownMode
            ? Int(focus.liveRemaining(at: now).rounded(.down))
            : Int(focus.liveElapsed(at: now).rounded(.down))
        let minutes = displayedSeconds / 60
        let seconds = displayedSeconds % 60

        if focus.isCountdownMode {
            return "\(minutes) minutes \(seconds) seconds remaining"
        }

        return "\(minutes) minutes \(seconds) seconds elapsed"
    }

    private var timerMode: FocusTimerMode {
        focus.isCountdownMode ? .countdown : .stopwatch
    }

    private var focusedMinuteCount: Int {
        guard focus.elapsedSeconds > 0 else { return 0 }
        return max(1, focus.elapsedSeconds / 60)
    }

    private var endFocusMessage: String {
        let minutes = focusedMinuteCount
        let unit = minutes == 1 ? "minute" : "minutes"
        return "You focused for \(minutes) \(unit)."
    }

    private var isRunningPresentation: Bool {
        displayPhase != .setup
    }

    private func displayedRunningTime(at now: Date) -> String {
        frozenRunningTime ?? focus.liveDisplayTime(at: now)
    }

    private func displayedRunningProgress(at now: Date) -> Double {
        focus.liveProgress(at: now)
    }

    private var pauseControlOpacity: Double {
        (isIdle ? 0.40 : 1.0) * runningControlsIntroOpacity
    }

    private var endControlOpacity: Double {
        (isIdle ? 0.35 : 1.0) * runningControlsIntroOpacity
    }

    var body: some View {
        ZStack {
            FocusAmbientBackground(
                theme: focusTheme,
                intensity: isDialDragging ? 1.08 : 1.0,
                isRunning: isRunningPresentation,
                isPaused: focus.phase == .paused
            )

            RadialGradient(
                colors: [
                    Theme.accent.opacity(completionGlowOpacity),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                topBar

                ZStack {
                    if displayPhase == .setup {
                        FocusSetupView(
                            targetTitle: setupTargetTitle,
                            tuneInSubtitle: tuneInSubtitle,
                            tuneInEnabled: isTuneInEnabled,
                            targetMinutes: $focus.targetMinutes,
                            timeTitle: setupTimeTitle,
                            timeCaption: setupTimeCaption,
                            textPrimary: tokens.textPrimary,
                            textSecondary: tokens.textSecondary,
                            controlSurface: tokens.controlSurface,
                            controlStroke: tokens.controlStroke,
                            dialTrackColor: tokens.dialTrack,
                            dialProgressColor: tokens.dialProgress,
                            dialKnobColor: tokens.dialKnob,
                            dialKnobStrokeColor: tokens.dialKnobStroke,
                            dialOpacity: setupDialOpacity,
                            dialScale: setupDialScale,
                            dialBlur: setupDialBlur,
                            timeScale: setupTimeScale,
                            startButtonScale: startButtonScale,
                            timeNamespace: timeNamespace,
                            onDialDragChanged: { isDragging in
                                isDialDragging = isDragging
                                let targetScale: CGFloat = isDragging ? 1.04 : 1.0
                                let dragAnimation = reduceMotion
                                    ? Animation.linear(duration: 0)
                                    : (isDragging ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.18))

                                withAnimation(dragAnimation) {
                                    setupTimeScale = targetScale
                                }
                            },
                            onTargetTap: {
                                showingTargetPicker = true
                            },
                            onTuneInTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingTuneInSheet = true
                            },
                            onStartTap: {
                                startFocusTransition()
                            }
                        )
                        .transition(.opacity)
                    }

                    if isRunningPresentation {
                        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
                            FocusRunningView(
                                timeText: displayedRunningTime(at: timeline.date),
                                accessibilityTimeValue: runningAccessibilityValue(at: timeline.date),
                                focusLabel: runningFocusTitle,
                                isPaused: focus.phase == .paused,
                                mode: timerMode,
                                progress: displayedRunningProgress(at: timeline.date),
                                timeOpacity: runningTimeOpacity,
                                timeScale: runningTimeScale,
                                pauseControlOpacity: pauseControlOpacity,
                                endControlOpacity: endControlOpacity,
                                progressIntroOpacity: runningProgressIntroOpacity,
                                progressIntroScaleX: runningProgressIntroScaleX,
                                showCompletionText: showCompletionText,
                                blinkToken: pauseResumeBlinkToken,
                                textPrimary: tokens.textPrimary,
                                textSecondary: tokens.textSecondary,
                                controlSurface: tokens.controlSurface,
                                controlStroke: tokens.controlStroke,
                                onPauseTap: {
                                    guard focus.phase != .paused else { return }
                                    focus.pause()
                                    soundscapePlayer.pause()
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    pauseResumeBlinkToken &+= 1
                                    registerRunningInteraction()
                                },
                                onResumeTap: {
                                    guard focus.phase == .paused else { return }
                                    focus.resume()
                                    refreshSoundscapePlaybackForCurrentState()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    pauseResumeBlinkToken &+= 1
                                    registerRunningInteraction()
                                },
                                onEndTap: {
                                    showingEndConfirmation = true
                                    registerRunningInteraction()
                                },
                                timeNamespace: timeNamespace
                            )
                            .transition(.opacity)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            if showingEndConfirmation {
                FocusEndConfirmationOverlay(
                    message: endFocusMessage,
                    textPrimary: tokens.textPrimary,
                    textSecondary: tokens.textSecondary,
                    controlSurface: tokens.controlSurface,
                    controlStroke: tokens.controlStroke,
                    onKeepGoing: {
                        withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                            showingEndConfirmation = false
                        }
                        registerRunningInteraction()
                    },
                    onEndFocus: {
                        let minutes = focus.end()
                        if minutes > 0 {
                            onSessionLogged(minutes)
                        }
                        soundscapePlayer.stop()
                        dismiss()
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }

            if showingCompletionOverlay {
                FocusCompletionOverlay(
                    message: endFocusMessage,
                    textPrimary: tokens.textPrimary,
                    textSecondary: tokens.textSecondary,
                    controlSurface: tokens.controlSurface,
                    controlStroke: tokens.controlStroke,
                    onClose: {
                        closeCompletionOverlay()
                    }
                )
                .transition(.opacity)
                .zIndex(11)
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard isRunningPresentation else { return }
                    registerRunningInteraction()
                }
        )
        .onAppear {
            migrateLegacyThemeIfNeeded()
            focus.configure(modelContext: modelContext, existingSession: latestActiveSession)
            applyInitialDurationIfNeeded()
            displayPhase = focus.phase
            startIdleMonitorIfNeeded()
        }
        .onChange(of: activeSessionIdentifier) { _, _ in
            focus.configure(modelContext: modelContext, existingSession: latestActiveSession)
            applyInitialDurationIfNeeded()
        }
        .onChange(of: focus.phase) { _, phase in
            handlePhaseChange(phase)
        }
        .onChange(of: focus.targetMinutes) { _, minutes in
            focusLastDuration = min(60, max(0, minutes))
            hasSavedFocusDuration = true
        }
        .onChange(of: focusSoundscapeRaw) { _, _ in
            refreshSoundscapePlaybackForCurrentState()
        }
        .onChange(of: focusMusicAutoplay) { _, _ in
            refreshSoundscapePlaybackForCurrentState()
        }
        .onChange(of: focusMusicVolumeRaw) { _, _ in
            soundscapePlayer.setVolume(selectedVolumeLevel)
        }
        .onChange(of: focus.lastCompletedSessionMinutes) { _, minutes in
            guard let minutes else { return }
            handleCompletion(minutes: minutes)
        }
        .onDisappear {
            idleMonitorTask?.cancel()
            idleMonitorTask = nil
            completionAutoDismissTask?.cancel()
            completionAutoDismissTask = nil
            soundscapePlayer.stop()
            focus.handleViewDisappear()
        }
        .sheet(isPresented: $showingThemePicker) {
            FocusThemePickerSheet(selectedTheme: themeBinding)
                .presentationDetents([.fraction(0.48), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTuneInSheet) {
            FocusTuneInSheet(
                selectedSoundscape: Binding(
                    get: { selectedSoundscape },
                    set: { focusSoundscapeRaw = $0.rawValue }
                ),
                autoplay: $focusMusicAutoplay,
                selectedVolume: Binding(
                    get: { selectedVolumeLevel },
                    set: { focusMusicVolumeRaw = $0.rawValue }
                )
            )
            .presentationDetents([.fraction(0.50), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTargetPicker) {
            FocusTargetPickerView(
                tasks: tasks,
                selectedTaskId: focus.selectedTaskID
            ) { selection in
                withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                    applyTargetSelection(selection)
                    showingTargetPicker = false
                }
            } onClose: {
                withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                    showingTargetPicker = false
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            soundscapePlayer.stop()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if displayPhase == .setup {
                    focus.handleViewDisappear()
                    dismiss()
                    onCancel()
                } else {
                    showingEndConfirmation = true
                    registerRunningInteraction()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Typography.iconCard)
                    .foregroundStyle(tokens.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(tokens.controlSurface)
                    )
                    .overlay {
                        Circle()
                            .stroke(tokens.controlStroke, lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text("Focus")
                .font(Theme.Typography.bodySmallStrong)
                .foregroundStyle(tokens.textPrimary)

            Spacer(minLength: 0)

            if displayPhase == .setup {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingThemePicker = true
                } label: {
                    Image(systemName: "paintpalette")
                        .font(Theme.Typography.iconCompact)
                        .foregroundStyle(tokens.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(tokens.controlSurface)
                        )
                        .overlay {
                            Circle()
                                .stroke(tokens.controlStroke, lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select background theme")
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingTuneInSheet = true
                    registerRunningInteraction()
                } label: {
                    Image(systemName: soundscapePlayer.isPlaying ? "music.note" : "music.note.slash")
                        .font(Theme.Typography.iconCompact)
                        .foregroundStyle(soundscapePlayer.isPlaying ? Theme.accent : tokens.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(tokens.controlSurface.opacity(0.88))
                        )
                        .overlay {
                            Circle()
                                .stroke(tokens.controlStroke.opacity(0.9), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tune in")
            }
        }
    }

    private func applyInitialDurationIfNeeded() {
        guard focus.phase == .setup else { return }

        if !didSetInitialFocusDuration {
            focus.targetMinutes = 15
            focusLastDuration = 15
            hasSavedFocusDuration = true
            didSetInitialFocusDuration = true
            return
        }

        guard hasSavedFocusDuration else { return }
        focus.targetMinutes = min(60, max(0, focusLastDuration))
    }

    private func migrateLegacyThemeIfNeeded() {
        guard !legacyFocusThemeRaw.isEmpty else { return }
        if focusThemeRaw == FocusBackgroundTheme.clean.rawValue,
           let legacyTheme = FocusBackgroundTheme(rawValue: legacyFocusThemeRaw) {
            focusThemeRaw = legacyTheme.rawValue
        }
        legacyFocusThemeRaw = ""
    }

    private func startFocusTransition() {
        guard !isStartTransitioning else { return }
        guard focus.phase == .setup else { return }

        isStartTransitioning = true

        withAnimation(FocusAnim.springedPress(reduceMotion: reduceMotion)) {
            startButtonScale = 0.985
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.08)) {
            withAnimation(FocusAnim.springedPress(reduceMotion: reduceMotion)) {
                startButtonScale = 1.0
            }
        }

        let dialExitAnimation = reduceMotion
            ? Animation.linear(duration: 0)
            : .easeInOut(duration: 0.35)

        withAnimation(dialExitAnimation) {
            setupDialOpacity = 0
            setupDialScale = 0.92
            setupDialBlur = 3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.30)) {
            focus.start()

            guard focus.phase == .running else {
                resetSetupVisualState()
                isStartTransitioning = false
                return
            }

            if focusMusicAutoplay {
                soundscapePlayer.play(soundscape: selectedSoundscape, volume: selectedVolumeLevel)
            } else {
                soundscapePlayer.stop()
            }

            runningTimeOpacity = 0
            runningTimeScale = 0.98
            runningControlsIntroOpacity = 0
            runningProgressIntroOpacity = 0
            runningProgressIntroScaleX = 0.98

            withAnimation(FocusAnim.springedEnter(reduceMotion: reduceMotion)) {
                displayPhase = .running
            }

            let timeFadeAnimation = reduceMotion
                ? Animation.linear(duration: 0)
                : .easeInOut(duration: 0.26)

            withAnimation(timeFadeAnimation) {
                runningTimeOpacity = 1
            }
            withAnimation(FocusAnim.springedEnter(reduceMotion: reduceMotion)) {
                runningTimeScale = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) {
                let progressAnimation = reduceMotion
                    ? Animation.linear(duration: 0)
                    : .easeInOut(duration: 0.24)

                withAnimation(progressAnimation) {
                    runningProgressIntroOpacity = 1
                    runningProgressIntroScaleX = 1
                }

                let controlsAnimation = reduceMotion
                    ? Animation.linear(duration: 0)
                    : .easeInOut(duration: 0.24)

                withAnimation(controlsAnimation) {
                    runningControlsIntroOpacity = 1
                }
                registerRunningInteraction()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.45)) {
                resetSetupVisualState()
                isStartTransitioning = false
            }
        }
    }

    private func handlePhaseChange(_ phase: FocusScreenState) {
        switch phase {
        case .setup:
            guard focus.lastCompletedSessionMinutes == nil else { return }

            withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                displayPhase = .setup
            }
            soundscapePlayer.stop()
            resetSetupVisualState()
            runningControlsIntroOpacity = 1
            runningProgressIntroOpacity = 1
            runningProgressIntroScaleX = 1
            runningTimeOpacity = 1
            runningTimeScale = 1
            showCompletionText = false
            frozenRunningTime = nil

        case .running:
            guard !isStartTransitioning else { return }
            withAnimation(FocusAnim.springedEnter(reduceMotion: reduceMotion)) {
                displayPhase = .running
            }
            runningControlsIntroOpacity = 1
            runningProgressIntroOpacity = 1
            runningProgressIntroScaleX = 1
            runningTimeOpacity = 1
            runningTimeScale = 1
            registerRunningInteraction()

        case .paused:
            withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                displayPhase = .paused
            }
            soundscapePlayer.pause()
            registerRunningInteraction()
        }
    }

    private func handleCompletion(minutes: Int) {
        if minutes > 0 {
            onSessionLogged(minutes)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        frozenRunningTime = "00:00"
        displayPhase = .running

        pulseCompletionGlow()

        withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
            showCompletionText = true
            showingCompletionOverlay = true
        }

        completionAutoDismissTask?.cancel()
        completionAutoDismissTask = Task {
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                closeCompletionOverlay()
            }
        }
    }

    private func closeCompletionOverlay() {
        completionAutoDismissTask?.cancel()
        completionAutoDismissTask = nil

        withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
            showCompletionText = false
            showingCompletionOverlay = false
        }

        soundscapePlayer.stop()
        focus.clearCompletedSessionMarker()
        frozenRunningTime = nil
        completionGlowOpacity = 0.06

        withAnimation(FocusAnim.springedEnter(reduceMotion: reduceMotion)) {
            displayPhase = .setup
        }
        resetSetupVisualState()
    }

    private func pulseCompletionGlow() {
        guard !reduceMotion else {
            completionGlowOpacity = 0.06
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            completionGlowOpacity = 0.14
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.25)) {
                completionGlowOpacity = 0.06
            }
        }
    }

    private func registerRunningInteraction() {
        guard isRunningPresentation else { return }
        lastInteractionDate = Date()
        if isIdle {
            withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                isIdle = false
            }
        }
    }

    private func startIdleMonitorIfNeeded() {
        guard idleMonitorTask == nil else { return }

        idleMonitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run {
                    let shouldIdle = isRunningPresentation
                        && !showingEndConfirmation
                        && Date().timeIntervalSince(lastInteractionDate) >= 5

                    guard shouldIdle != isIdle else { return }
                    withAnimation(FocusAnim.easedMed(reduceMotion: reduceMotion)) {
                        isIdle = shouldIdle
                    }
                }
            }
        }
    }

    private func resetSetupVisualState() {
        setupDialOpacity = 1
        setupDialScale = 1
        setupDialBlur = 0
        setupTimeScale = 1
        startButtonScale = 1
        isDialDragging = false
    }

    private func applyTargetSelection(_ selection: FocusTargetSelection) {
        switch selection {
        case .none:
            focus.selectNoneTarget()
        case .task(let taskID):
            focus.selectTask(taskID)
        }
    }

    private func refreshSoundscapePlaybackForCurrentState() {
        guard isRunningPresentation else {
            soundscapePlayer.stop()
            return
        }

        guard focusMusicAutoplay else {
            soundscapePlayer.stop()
            return
        }

        if focus.phase == .paused {
            if soundscapePlayer.activeSoundscape != selectedSoundscape {
                soundscapePlayer.play(soundscape: selectedSoundscape, volume: selectedVolumeLevel)
            } else {
                soundscapePlayer.setVolume(selectedVolumeLevel)
            }
            soundscapePlayer.pause()
            return
        }

        if soundscapePlayer.activeSoundscape == selectedSoundscape, selectedSoundscape != .none {
            soundscapePlayer.setVolume(selectedVolumeLevel)
            if !soundscapePlayer.isPlaying {
                soundscapePlayer.resume()
            }
        } else {
            soundscapePlayer.play(soundscape: selectedSoundscape, volume: selectedVolumeLevel)
        }
    }
}

struct FocusSetupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasAnimatedEntrance = false
    @State private var headerVisible = false
    @State private var dialVisible = false

    let targetTitle: String
    let tuneInSubtitle: String
    let tuneInEnabled: Bool
    @Binding var targetMinutes: Int
    let timeTitle: String
    let timeCaption: String

    let textPrimary: Color
    let textSecondary: Color
    let controlSurface: Color
    let controlStroke: Color

    let dialTrackColor: Color
    let dialProgressColor: Color
    let dialKnobColor: Color
    let dialKnobStrokeColor: Color

    let dialOpacity: Double
    let dialScale: CGFloat
    let dialBlur: CGFloat
    let timeScale: CGFloat
    let startButtonScale: CGFloat

    let timeNamespace: Namespace.ID

    let onDialDragChanged: (Bool) -> Void
    let onTargetTap: () -> Void
    let onTuneInTap: () -> Void
    let onStartTap: () -> Void

    var body: some View {
        let effectiveDialOpacity = dialOpacity * (dialVisible ? 1 : 0)
        let effectiveDialScale = dialScale * (dialVisible ? 1 : 0.985)

        VStack(spacing: Theme.Spacing.md) {
            VStack(spacing: Theme.Spacing.xxxs) {
                Text("Choose one thing.")
                    .font(.system(size: 52, weight: .semibold, design: .serif))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.center)

                Text("Or just set a timer.")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(textSecondary)
            }
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 8)
            .padding(.top, Theme.Spacing.xs)

            VStack(spacing: Theme.Spacing.xs) {
                Button(action: onTuneInTap) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "music.note")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(textSecondary)

                        Text("Tune in")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(textPrimary.opacity(0.95))

                        if tuneInEnabled {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 7, height: 7)
                            Text(tuneInSubtitle)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(textSecondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.9))
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(controlSurface)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(controlStroke, lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)

                Button(action: onTargetTap) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Focusing on")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(textSecondary)

                        Text(targetTitle)
                            .font(Theme.Typography.bodySmallStrong)
                            .foregroundStyle(textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.9))
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(controlSurface)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(controlStroke, lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }
            .opacity(headerVisible ? 1 : 0)

            ZStack {
                FocusRingDialView(
                    targetMinutes: $targetMinutes,
                    maxMinutes: 60,
                    snapIncrement: 1,
                    hapticIncrement: 5,
                    trackColor: dialTrackColor,
                    progressColor: dialProgressColor,
                    knobColor: dialKnobColor,
                    knobStrokeColor: dialKnobStrokeColor,
                    detailColor: textSecondary.opacity(0.18),
                    onDragActiveChanged: onDialDragChanged
                )

                VStack(spacing: Theme.Spacing.xxxs) {
                    Text(timeTitle)
                        .font(.system(size: 70, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                        .scaleEffect(timeScale)
                        .matchedGeometryEffect(id: "focus-time", in: timeNamespace)

                    Text(timeCaption)
                        .font(Theme.Typography.bodySmall)
                        .foregroundStyle(textSecondary)
                }
                .accessibilityElement()
                .accessibilityLabel(
                    targetMinutes == 0
                    ? "No timer selected"
                    : "\(targetMinutes) minutes selected"
                )
            }
            .overlay(alignment: .topLeading) {
                Text("Focus")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(textSecondary)
                    .offset(y: -12)
            }
            .frame(height: 360)
            .opacity(effectiveDialOpacity)
            .scaleEffect(effectiveDialScale)
            .blur(radius: dialBlur)

            Spacer(minLength: 0)

            Button("Start focus", action: onStartTap)
                .buttonStyle(FocusPrimaryButtonStyle(externalScale: startButtonScale))
                .frame(maxWidth: .infinity)
        }
        .padding(.top, Theme.Spacing.sm)
        .onAppear {
            guard !hasAnimatedEntrance else { return }
            hasAnimatedEntrance = true

            if reduceMotion {
                headerVisible = true
                dialVisible = true
                return
            }

            withAnimation(.easeOut(duration: 0.35)) {
                headerVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.35)) {
                    dialVisible = true
                }
            }
        }
    }
}

struct FocusRunningView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinkOpacity: Double = 1.0

    let timeText: String
    let accessibilityTimeValue: String
    let focusLabel: String
    let isPaused: Bool
    let mode: FocusTimerMode
    let progress: Double

    let timeOpacity: Double
    let timeScale: CGFloat
    let pauseControlOpacity: Double
    let endControlOpacity: Double
    let progressIntroOpacity: Double
    let progressIntroScaleX: CGFloat
    let showCompletionText: Bool
    let blinkToken: Int

    let textPrimary: Color
    let textSecondary: Color
    let controlSurface: Color
    let controlStroke: Color

    let onPauseTap: () -> Void
    let onResumeTap: () -> Void
    let onEndTap: () -> Void

    let timeNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer(minLength: 44)

            Text(timeText)
                .font(.system(size: 84, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.34)
                .lineLimit(1)
                .contentTransition(.numericText())
                .accessibilityLabel(accessibilityTimeValue)
                .opacity((isPaused ? 0.82 : 1.0) * timeOpacity * blinkOpacity)
                .scaleEffect(timeScale)
                .matchedGeometryEffect(id: "focus-time", in: timeNamespace)

            Group {
                if showCompletionText {
                    Text("Nice work.")
                        .font(Theme.Typography.bodySmallStrong)
                        .foregroundStyle(textSecondary)
                        .transition(.opacity)
                } else {
                    Color.clear
                }
            }
            .frame(height: 20)

            Text(focusLabel)
                .font(Theme.Typography.bodySmall)
                .foregroundStyle(textSecondary)
                .lineLimit(1)

            FocusHorizonProgress(
                progress: progress,
                mode: mode,
                isRunning: !isPaused,
                trackColor: textSecondary.opacity(0.30),
                fillColor: Theme.accent
            )
            .opacity(isPaused ? 0.55 : 1)
            .animation(FocusAnim.easedMed(reduceMotion: reduceMotion), value: isPaused)
            .opacity(progressIntroOpacity)
            .scaleEffect(x: progressIntroScaleX, y: 1, anchor: .center)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.top, Theme.Spacing.xxxs)

            Spacer(minLength: 36)

            FocusPlaybackControl(
                isPaused: isPaused,
                pauseAction: onPauseTap,
                resumeAction: onResumeTap,
                textPrimary: textPrimary,
                controlSurface: controlSurface,
                controlStroke: controlStroke
            )
            .opacity(pauseControlOpacity)

            Spacer(minLength: 0)

            Button("End session", action: onEndTap)
                .buttonStyle(
                    FocusSecondaryButtonStyle(
                        background: controlSurface.opacity(0.92),
                        foreground: textPrimary,
                        stroke: controlStroke
                    )
                )
                .frame(maxWidth: 220)
                .opacity(endControlOpacity)
                .padding(.bottom, Theme.Spacing.md)
        }
        .onChange(of: blinkToken) { _, _ in
            triggerTimeBlink()
        }
        .onAppear {
            blinkOpacity = 1.0
        }
    }

    private func triggerTimeBlink() {
        guard !reduceMotion else {
            blinkOpacity = 1.0
            return
        }

        withAnimation(.easeOut(duration: 0.08)) {
            blinkOpacity = 0.60
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.18)) {
                blinkOpacity = 1.0
            }
        }
    }
}

private struct FocusPlaybackControl: View {
    let isPaused: Bool
    let pauseAction: () -> Void
    let resumeAction: () -> Void
    let textPrimary: Color
    let controlSurface: Color
    let controlStroke: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            button(
                icon: "pause.fill",
                active: !isPaused,
                action: pauseAction,
                label: "Pause focus"
            )

            button(
                icon: "play.fill",
                active: isPaused,
                action: resumeAction,
                label: "Resume focus"
            )
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(controlSurface.opacity(0.92))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(controlStroke.opacity(0.9), lineWidth: 0.9)
        }
        .frame(width: 290)
    }

    private func button(icon: String, active: Bool, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(active ? Color.white : textPrimary.opacity(0.90))
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(active ? Theme.accent : Color.clear)
                )
                .overlay {
                    Circle()
                        .stroke(controlStroke.opacity(active ? 0.18 : 0.65), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct FocusThemePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selectedTheme: FocusBackgroundTheme

    var body: some View {
        NavigationStack {
            List {
                ForEach(FocusBackgroundTheme.allCases) { theme in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(
                            reduceMotion
                            ? .linear(duration: 0)
                            : .easeInOut(duration: 0.4)
                        ) {
                            selectedTheme = theme
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            FocusThemePreviewSwatch(theme: theme)

                            Text(theme.displayName)
                                .font(Theme.Typography.bodySmallStrong)
                                .foregroundStyle(Theme.text)

                            Spacer(minLength: 0)

                            if selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(Theme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FocusTuneInSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSoundscape: FocusSoundscape
    @Binding var autoplay: Bool
    @Binding var selectedVolume: FocusSoundVolumeLevel

    var body: some View {
        NavigationStack {
            List {
                Section("Soundscape") {
                    ForEach(FocusSoundscape.allCases) { soundscape in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedSoundscape = soundscape
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Text(soundscape.displayName)
                                    .font(Theme.Typography.bodySmall)
                                    .foregroundStyle(Theme.text)

                                Spacer(minLength: 0)

                                if selectedSoundscape == soundscape {
                                    Image(systemName: "checkmark")
                                        .font(Theme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Playback") {
                    Toggle("Autoplay music", isOn: $autoplay)

                    Picker("Volume", selection: $selectedVolume) {
                        ForEach(FocusSoundVolumeLevel.allCases) { level in
                            Text(level.displayName)
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tune in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FocusThemePreviewSwatch: View {
    let theme: FocusBackgroundTheme

    var body: some View {
        let tokens = theme.tokens

        Circle()
            .fill(tokens.base)
            .frame(width: 28, height: 28)
            .overlay {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tokens.radialGlow.opacity(tokens.radialGlowOpacity * 0.65),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
            }
            .overlay {
                Circle()
                    .stroke(Theme.textSecondary.opacity(0.18), lineWidth: 0.8)
            }
    }
}

private struct FocusEndConfirmationOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let message: String
    let textPrimary: Color
    let textSecondary: Color
    let controlSurface: Color
    let controlStroke: Color

    let onKeepGoing: () -> Void
    let onEndFocus: () -> Void

    @State private var blurIn = false
    @State private var modalIn = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(blurIn ? 0.14 : 0))
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("End session?")
                    .font(Theme.Typography.titleMedium)
                    .foregroundStyle(textPrimary)

                Text("You can start again anytime.")
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(textSecondary)

                VStack(spacing: Theme.Spacing.xs) {
                    Button("Keep going", action: onKeepGoing)
                        .buttonStyle(FocusPrimaryButtonStyle())

                    Button("End session", action: onEndFocus)
                        .buttonStyle(
                            FocusSecondaryButtonStyle(
                                background: controlSurface.opacity(0.92),
                                foreground: textPrimary,
                                stroke: controlStroke
                            )
                        )
                }
                .padding(.top, Theme.Spacing.xxs)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(controlStroke.opacity(0.95), lineWidth: 0.9)
            }
            .shadow(color: Theme.cardShadow().opacity(0.9), radius: 18, y: 10)
            .padding(.horizontal, Theme.Spacing.md)
            .scaleEffect(modalIn ? 1 : 0.98)
            .opacity(modalIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.18)) {
                blurIn = true
            }
            withAnimation(FocusAnim.springedEnter(reduceMotion: reduceMotion)) {
                modalIn = true
            }
        }
    }
}

private struct FocusCompletionOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let message: String
    let textPrimary: Color
    let textSecondary: Color
    let controlSurface: Color
    let controlStroke: Color
    let onClose: () -> Void

    @State private var blurIn = false
    @State private var modalIn = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(blurIn ? 0.12 : 0))
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.sm) {
                Text("Session complete")
                    .font(Theme.Typography.titleMedium)
                    .foregroundStyle(textPrimary)

                Text(message)
                    .font(Theme.Typography.bodySmall)
                    .foregroundStyle(textSecondary)
                    .multilineTextAlignment(.center)

                Button("Back to setup", action: onClose)
                    .buttonStyle(
                        FocusSecondaryButtonStyle(
                            background: controlSurface.opacity(0.94),
                            foreground: textPrimary,
                            stroke: controlStroke
                        )
                    )
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(controlStroke.opacity(0.95), lineWidth: 0.9)
            }
            .shadow(color: Theme.cardShadow().opacity(0.8), radius: 18, y: 10)
            .padding(.horizontal, Theme.Spacing.md)
            .scaleEffect(modalIn ? 1 : 0.98)
            .opacity(modalIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.18)) {
                blurIn = true
            }
            withAnimation(FocusAnim.springedEnter(reduceMotion: reduceMotion)) {
                modalIn = true
            }
        }
    }
}

private struct FocusPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var background: Color = Theme.accent
    var foreground: Color = .white
    var externalScale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodySmallStrong)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                background.opacity(configuration.isPressed ? 0.90 : 1.0),
                                background.opacity(configuration.isPressed ? 0.86 : 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.7)
            }
            .shadow(color: Theme.cardShadow().opacity(configuration.isPressed ? 0.18 : 0.36), radius: configuration.isPressed ? 2 : 10, y: configuration.isPressed ? 1 : 5)
            .scaleEffect((configuration.isPressed ? 0.985 : 1) * externalScale)
            .animation(FocusAnim.springedPress(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

private struct FocusSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let background: Color
    let foreground: Color
    let stroke: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.bodySmallStrong)
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.82 : 1.0))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background.opacity(configuration.isPressed ? 0.86 : 1.0))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(stroke.opacity(configuration.isPressed ? 0.55 : 0.82), lineWidth: 0.9)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(FocusAnim.springedPress(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct FocusTargetPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [TaskItem]
    let selectedTaskId: UUID?
    let onSelect: (FocusTargetSelection) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    pickerRow(title: "None", selection: .none)
                }
                Section("Tasks") {
                    if sortedTasks.isEmpty {
                        Text("No tasks in Today")
                            .font(Theme.Typography.bodySmall)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(sortedTasks) { task in
                            pickerRow(title: task.title, selection: .task(task.id))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Focusing on")
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

    private var selectedTargetSelection: FocusTargetSelection {
        if let selectedTaskId {
            return .task(selectedTaskId)
        }
        return .none
    }

    private func pickerRow(title: String, selection: FocusTargetSelection) -> some View {
        Button {
            onSelect(selection)
            dismiss()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: selectedTargetSelection == selection ? "checkmark.circle.fill" : "circle")
                    .font(Theme.Typography.iconCompact)
                    .foregroundStyle(selectedTargetSelection == selection ? Theme.accent : Theme.textSecondary.opacity(0.7))

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
