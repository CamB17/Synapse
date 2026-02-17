import SwiftUI
import SwiftData

struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var addToToday = false
    let placeholder: String
    let canAddToToday: Bool
    let onAdded: ((TaskItem, Bool) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
                    .padding(.top, 8)

                if canAddToToday {
                    Toggle("Add directly to Today", isOn: $addToToday)
                        .toggleStyle(.switch)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Capture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func add() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let state: TaskState = addToToday ? .today : .inbox
        let task = TaskItem(title: trimmed, state: state)
        modelContext.insert(task)
        try? modelContext.save()
        onAdded?(task, addToToday)
        dismiss()
    }
}
