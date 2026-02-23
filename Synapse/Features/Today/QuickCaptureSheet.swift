import SwiftUI
import SwiftData

struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var addToToday = false
    @State private var voiceSeedText = ""
    @StateObject private var voiceCapture = VoiceCaptureController()
    let placeholder: String
    let canAddToToday: Bool
    let onAdded: ((TaskItem, Bool) -> Void)?

    var body: some View {
        NavigationStack {
            ScreenCanvas {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                        TextField(placeholder, text: $text, axis: .vertical)
                            .font(Theme.Typography.itemTitle)
                            .foregroundStyle(Theme.text)
                            .lineLimit(4, reservesSpace: true)
                            .textInputAutocapitalization(.sentences)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            toggleVoiceCapture()
                        } label: {
                            Image(systemName: voiceCapture.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                .font(Theme.Typography.iconXL)
                                .foregroundStyle(voiceCapture.isRecording ? Theme.accent2 : Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(voiceCapture.isRecording ? "Stop voice capture" : "Start voice capture")
                    }
                    .padding(Theme.Spacing.cardInset)
                    .surfaceCard()
                    .padding(.top, Theme.Spacing.xs)

                    if let error = voiceCapture.errorMessage {
                        Text(error)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, Theme.Spacing.xs)
                    }

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
                        .padding(Theme.Spacing.cardInset)
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
            .onDisappear {
                voiceCapture.stop()
            }
        }
    }

    private func add() {
        voiceCapture.stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let state: TaskState = addToToday ? .today : .inbox
        let task = TaskItem(title: trimmed, state: state)
        modelContext.insert(task)
        try? modelContext.save()
        onAdded?(task, addToToday)
        dismiss()
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
}
