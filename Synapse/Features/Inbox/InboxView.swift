import SwiftUI
import SwiftData

struct InboxView: View {
    let taskNamespace: Namespace.ID
    let onCommitToToday: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "inbox" },
           sort: [SortDescriptor(\TaskItem.createdAt, order: .reverse)])
    private var inbox: [TaskItem]

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "today" })
    private var todayTasks: [TaskItem]

    @State private var text: String = ""
    @State private var voiceSeedText = ""
    @State private var showCapAlert = false
    @State private var committingTaskIDs: Set<UUID> = []
    @StateObject private var voiceCapture = VoiceCaptureController()

    private let todayCap = 5
    private var todayAssignedCount: Int {
        todayTasks.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(spacing: Theme.Spacing.sm) {
                    captureRow

                    if inbox.isEmpty {
                        emptyInboxState
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.xxs)
                        Spacer(minLength: 0)
                    } else {
                        List {
                            Section {
                                ForEach(inbox) { item in
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Text(item.title)
                                            .font(Theme.Typography.itemTitle)
                                            .foregroundStyle(Theme.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button {
                                            commitToToday(item)
                                        } label: {
                                            Label("Today", systemImage: "arrow.up.circle.fill")
                                                .labelStyle(.titleAndIcon)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(Theme.Spacing.cardInset)
                                    .surfaceCard()
                                    .matchedGeometryEffect(id: item.id, in: taskNamespace)
                                    .opacity(committingTaskIDs.contains(item.id) ? 0.55 : 1)
                                    .scaleEffect(committingTaskIDs.contains(item.id) ? 0.96 : 1)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button("Today") { commitToToday(item) }
                                            .tint(Theme.accent)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { delete(item) } label: {
                                            Text("Delete")
                                        }
                                    }
                                }
                            } header: {
                                SectionLabel(icon: "tray", title: "Inbox (\(inbox.count))")
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbarColorScheme(.light, for: .navigationBar)
            .alert("Today is full", isPresented: $showCapAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Clear something first (max \(todayCap)).")
            }
            .onDisappear {
                voiceCapture.stop()
            }
        }
    }

    private var captureRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xs) {
                TextField("Capture something…", text: $text)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.text)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 10)
                    .surfaceCard(cornerRadius: Theme.radiusSmall)

                Button {
                    toggleVoiceCapture()
                } label: {
                    Image(systemName: voiceCapture.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(Theme.Typography.iconXL)
                        .foregroundStyle(voiceCapture.isRecording ? Theme.accent2 : Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(voiceCapture.isRecording ? "Stop voice capture" : "Start voice capture")

                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(Theme.Typography.iconXL)
                        .foregroundStyle(Theme.accent)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let error = voiceCapture.errorMessage {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
    }
    
    private var emptyInboxState: some View {
        EmptyStatePanel(
            symbol: "tray",
            title: "Inbox empty.",
            subtitle: "Capture things as they pop up."
        )
    }

    private func add() {
        voiceCapture.stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(TaskItem(title: trimmed, state: .inbox))
        text = ""
        try? modelContext.save()
    }

    private func toggleVoiceCapture() {
        voiceSeedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        voiceCapture.toggle { spoken in
            text = mergedText(base: voiceSeedText, spoken: spoken)
        }
    }

    private func mergedText(base: String, spoken: String) -> String {
        let cleanedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSpoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSpoken.isEmpty else { return cleanedBase }
        guard !cleanedBase.isEmpty else { return cleanedSpoken }
        return "\(cleanedBase) \(cleanedSpoken)"
    }

    private func commitToToday(_ item: TaskItem) {
        guard todayAssignedCount < todayCap else {
            showCapAlert = true
            return
        }
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.impactOccurred()

        withAnimation(.snappy(duration: 0.18)) {
            _ = committingTaskIDs.insert(item.id)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.snappy(duration: 0.22)) {
                item.state = .today
                item.createdAt = .now
                onCommitToToday?()
            }
            try? modelContext.save()
            committingTaskIDs.remove(item.id)
        }
    }

    private func delete(_ item: TaskItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}
