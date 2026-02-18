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
    @State private var showCapAlert = false
    @State private var committingTaskIDs: Set<UUID> = []

    private let todayCap = 5

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
        }
    }

    private var captureRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TextField("Capture something…", text: $text)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.text)
                .submitLabel(.done)
                .onSubmit(add)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 10)
                .surfaceCard(cornerRadius: Theme.radiusSmall)

            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(Theme.Typography.iconXL)
                    .foregroundStyle(Theme.accent)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(TaskItem(title: trimmed, state: .inbox))
        text = ""
        try? modelContext.save()
    }

    private func commitToToday(_ item: TaskItem) {
        guard todayTasks.count < todayCap else {
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
