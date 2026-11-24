import AVFoundation
import SwiftUI

/// Запись голосового сообщения через AVAudioRecorder.
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = VoiceRecorder()

    @Published var isRecording = false
    @Published var duration: Double = 0
    @Published var currentURL: URL?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var sendAction: ((VoiceNoteDraft) -> Void)?

    private override init() {
        super.init()
    }

    /// Начать запись в указанный файл. `onSent` вызывается после stop() с готовым черновиком.
    func start(
        url: URL,
        onSent: @escaping (VoiceNoteDraft) -> Void
    ) {
        sendAction = onSent

        let settings: [String: Any] = [
            AVFormatIDKey: Int32(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()

            self.recorder = recorder
            currentURL = url
            isRecording = true
            duration = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if let recorder = self.recorder {
                    self.duration = max(recorder.currentTime, 0)
                }
            }
        } catch {
            recorder = nil
            isRecording = false
            duration = 0
        }
    }

    /// Остановить запись. Если запись длится >= 0.4 сек — вернуть черновик через onSent.
    func stop() {
        timer?.invalidate()
        timer = nil

        let recordedDuration = recorder?.currentTime ?? 0
        let url = currentURL

        recorder?.stop()
        recorder = nil
        currentURL = nil
        isRecording = false
        duration = 0

        if let url, recordedDuration >= 0.4 {
            sendAction?(VoiceNoteDraft(url: url, duration: Int(recordedDuration)))
        } else if let url {
            try? FileManager.default.removeItem(at: url)
        }
        sendAction = nil
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentURL = nil
        isRecording = false
        duration = 0
        sendAction = nil
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidStopRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Ручное управление через stop()/cancel() — здесь нет действий
    }
}

/// Готовый черновик голосового сообщения.
struct VoiceNoteDraft {
    let url: URL
    let duration: Int
}
