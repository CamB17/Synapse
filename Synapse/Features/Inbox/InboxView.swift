import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "inbox" },
           sort: [SortDescriptor(\TaskItem.createdAt, order: .reverse)])
    private var inbox: [TaskItem]

    @Query(filter: #Predicate<TaskItem> { $0.stateRaw == "today" })
    private var todayTasks: [TaskItem]

    @State private var text: String = ""
    @State private var showCapAlert = false

    private let todayCap = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                captureRow

                List {
                    Section(header: Text("INBOX (\(inbox.count))")) {
                        ForEach(inbox) { item in
                            HStack(spacing: 10) {
                                Text(item.title)
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
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button("Today") { commitToToday(item) }
                                        .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { delete(item) } label: {
                                        Text("Delete")
                                    }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Inbox")
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
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(add)

            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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

        withAnimation(.snappy(duration: 0.22)) {
            item.state = .today
        }
        try? modelContext.save()
    }

    private func delete(_ item: TaskItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}
