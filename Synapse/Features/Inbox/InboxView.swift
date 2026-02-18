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
                VStack(spacing: 12) {
                    captureRow

                    if inbox.isEmpty {
                        emptyInboxState
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                    } else {
                        List {
                            Section {
                                ForEach(inbox) { item in
                                    HStack(spacing: 10) {
                                        Text(item.title)
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
                                    .padding(14)
                                    .background(
                                        Theme.surface,
                                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                                    )
                                    .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
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
                                HStack(spacing: 8) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 12, weight: .semibold))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Theme.accent.opacity(0.45))

                                    Text("INBOX (\(inbox.count))")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                        .tracking(0.8)
                                }
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
        HStack(spacing: 10) {
            TextField("Capture something…", text: $text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text)
                .submitLabel(.done)
                .onSubmit(add)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                )
                .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)

            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var emptyInboxState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Illustration(symbol: "tray", style: .line, size: 34)

            Text("Inbox empty.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)

            Text("Capture things as they pop up.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        )
        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
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
