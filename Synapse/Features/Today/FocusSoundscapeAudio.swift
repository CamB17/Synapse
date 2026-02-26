import Foundation
import AVFoundation
import Combine

enum FocusSoundscape: String, CaseIterable, Identifiable {
    case none
    case lofi
    case rain
    case ocean
    case brownNoise
    case whiteNoise
    case fireplace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No music"
        case .lofi: return "Lo-Fi"
        case .rain: return "Rain"
        case .ocean: return "Ocean"
        case .brownNoise: return "Brown noise"
        case .whiteNoise: return "White noise"
        case .fireplace: return "Fireplace"
        }
    }

    var fileName: String? {
        switch self {
        case .none: return nil
        case .lofi: return "focus_lofi"
        case .rain: return "focus_rain"
        case .ocean: return "focus_ocean"
        case .brownNoise: return "focus_brown_noise"
        case .whiteNoise: return "focus_white_noise"
        case .fireplace: return "focus_fireplace"
        }
    }
}

enum FocusSoundVolumeLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }

    var gain: Float {
        switch self {
        case .low: return 0.28
        case .medium: return 0.5
        case .high: return 0.75
        }
    }
}

@MainActor
final class FocusSoundscapePlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activeSoundscape: FocusSoundscape = .none

    private var player: AVAudioPlayer?

    func play(soundscape: FocusSoundscape, volume: FocusSoundVolumeLevel) {
        guard soundscape != .none else {
            stop()
            return
        }

        guard let fileName = soundscape.fileName else {
            stop()
            return
        }

        guard let url = resolveSoundscapeURL(named: fileName) else {
            stop()
            return
        }

        do {
            try configureAudioSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = volume.gain
            player.prepareToPlay()
            player.play()

            self.player = player
            activeSoundscape = soundscape
            isPlaying = true
        } catch {
            stop()
        }
    }

    func setVolume(_ level: FocusSoundVolumeLevel) {
        player?.volume = level.gain
    }

    func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard let player else { return }
        guard activeSoundscape != .none else { return }
        player.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        activeSoundscape = .none
        isPlaying = false
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
    }

    private func resolveSoundscapeURL(named name: String) -> URL? {
        let extensions = ["m4a", "mp3", "wav", "aac"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
