import AVFoundation
import Combine
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

    @discardableResult
    func toggle(messageID: Int64, url: URL) -> Bool {
        if playingMessageID == messageID, let player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                return true
            }
            isPlaying = player.play()
            return isPlaying
        }
        return play(messageID: messageID, url: url)
    }

    @discardableResult
    func play(messageID: Int64, url: URL) -> Bool {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { return false }

            self.player = player
            playingMessageID = messageID
            isPlaying = true
            duration = player.duration
            progress = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.player, player.duration > 0 else { return }
                let value = player.currentTime / player.duration
                if self.progress != value { self.progress = value }
            }
            return true
        } catch {
            stop()
            return false
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
        duration = 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}
