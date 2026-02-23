import AVFoundation
import Combine
import Speech

@MainActor
final class VoiceCaptureController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isAuthorizing = false
    @Published private(set) var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onTranscript: ((String) -> Void)?
    private var hasInstalledTap = false
    private var shouldAbortCapture = false

    override init() {
        recognizer = SFSpeechRecognizer(locale: .current)
        super.init()
        recognizer?.delegate = self
    }

    func toggle(onTranscript: @escaping (String) -> Void) {
        if isRecording {
            stop()
            return
        }
        start(onTranscript: onTranscript)
    }

    func start(onTranscript: @escaping (String) -> Void) {
        guard !isRecording, !isAuthorizing else { return }
        self.onTranscript = onTranscript
        errorMessage = nil
        shouldAbortCapture = false
        isAuthorizing = true
        Task {
            await beginCapture()
        }
    }

    func stop() {
        shouldAbortCapture = true
        onTranscript = nil
        isAuthorizing = false
        if isRecording || recognitionTask != nil || hasInstalledTap {
            teardownCapture()
        }
    }

    private func beginCapture() async {
        defer { isAuthorizing = false }
        guard let recognizer else {
            errorMessage = "Voice capture isn't available on this device."
            return
        }
        guard recognizer.isAvailable else {
            errorMessage = "Voice capture is temporarily unavailable."
            return
        }

        guard await ensurePermissions() else { return }
        guard !shouldAbortCapture else { return }

        do {
            try configureAudioSession()
            try startRecognition(using: recognizer)
            guard !shouldAbortCapture else {
                teardownCapture()
                return
            }
            isRecording = true
        } catch {
            errorMessage = "Couldn't start voice capture. Please try again."
            teardownCapture()
        }
    }

    private func ensurePermissions() async -> Bool {
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            errorMessage = speechPermissionMessage(for: speechStatus)
            return false
        }

        let microphoneAllowed = await requestMicrophonePermission()
        guard microphoneAllowed else {
            errorMessage = "Microphone permission is required for voice capture."
            return false
        }

        return true
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition(using recognizer: SFSpeechRecognizer) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.onTranscript?(spoken)
                    if result.isFinal {
                        self.teardownCapture()
                    }
                }
            }

            if error != nil {
                Task { @MainActor in
                    if self.isRecording {
                        self.errorMessage = "Voice capture ended unexpectedly. Try again."
                    }
                    self.teardownCapture()
                }
            }
        }
    }

    private func teardownCapture() {
        audioEngine.stop()
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func speechPermissionMessage(for status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .denied:
            return "Speech recognition permission was denied."
        case .restricted:
            return "Speech recognition is restricted on this device."
        case .notDetermined:
            return "Speech recognition permission wasn't granted."
        case .authorized:
            return ""
        @unknown default:
            return "Speech recognition permission is unavailable."
        }
    }
}

extension VoiceCaptureController: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && self.isRecording {
                self.errorMessage = "Voice capture became unavailable."
                self.teardownCapture()
            }
        }
    }
}
