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
                VStack(alignment: .leading, spacing: 14) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(4, reservesSpace: true)
                        .textInputAutocapitalization(.sentences)
                        .padding(14)
                        .background(
                            Theme.surface,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        )
                        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
                        .padding(.top, 8)

                    if canAddToToday {
                        HStack(spacing: 12) {
                            Text("Add directly to Today")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.text)

                            Spacer(minLength: 8)

                            Toggle("", isOn: $addToToday)
                                .labelsHidden()
                                .tint(Theme.accent)
                        }
                        .padding(14)
                        .background(
                            Theme.surface,
                            in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        )
                        .shadow(color: Theme.cardShadow(), radius: Theme.shadowRadius, y: Theme.shadowY)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
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
