import AVFoundation
import Foundation

final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayer()

    @Published var playingMessageID: Int64?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    private override init() {
        super.init()
    }

    func toggle(messageID: Int64, url: URL) {
        if playingMessageID == messageID {
            stop()
            return
        }
        play(messageID: messageID, url: url)
    }

    func play(messageID: Int64, url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()

            self.player = player
            playingMessageID = messageID
            isPlaying = true
            duration = player.duration
            progress = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        } catch {
            stop()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        playingMessageID = nil
        isPlaying = false
        progress = 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}
