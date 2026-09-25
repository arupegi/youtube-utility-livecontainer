import AVFoundation
import Foundation

@MainActor
final class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()

    private init() {}

    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay]
            )
            try session.setActive(true)
        } catch {
            print("Audio session activation failed: \(error)")
        }
    }

    func reactivate() {
        activate()
    }
}
