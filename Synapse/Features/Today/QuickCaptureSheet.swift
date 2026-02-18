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
            ScreenCanvas {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .font(Theme.Typography.itemTitle)
                        .foregroundStyle(Theme.text)
                        .lineLimit(4, reservesSpace: true)
                        .textInputAutocapitalization(.sentences)
                        .padding(14)
                        .surfaceCard()
                        .padding(.top, Theme.Spacing.xs)

                    if canAddToToday {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("Add directly to Today")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundStyle(Theme.text)

                            Spacer(minLength: Theme.Spacing.xs)

                            Toggle("", isOn: $addToToday)
                                .labelsHidden()
                                .tint(Theme.accent)
                        }
                        .padding(14)
                        .surfaceCard(cornerRadius: Theme.radiusSmall)
                    }

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Capture")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Theme.accent)
                        .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .tint(Theme.accent)
                        .buttonStyle(.plain)
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
