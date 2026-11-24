import AVFoundation
import Combine
import Foundation

final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPreparing = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var samples: [UInt8] = []
    private var permissionTicket = UUID()
    private var ownsSession = false

    func start() {
        guard !isRecording && !isPreparing else { return }
        error = nil
        isPreparing = true
        let ticket = UUID()
        permissionTicket = ticket
        let handlePermission: (Bool) -> Void = { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self, self.permissionTicket == ticket else { return }
                self.isPreparing = false
                if allowed {
                    self.beginRecording()
                } else {
                    self.error = "Разрешите Whogram доступ к микрофону в Настройках iOS."
                }
            }
        }
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: handlePermission)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(handlePermission)
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        do {
            AudioPlayer.shared.stop()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            ownsSession = true
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000
            ])
            guard recorder.record() else {
                cancel()
                try? FileManager.default.removeItem(at: url)
                error = "Не удалось начать запись."
                return
            }
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            self.recorder = recorder
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
                guard let self, let recorder = self.recorder else { return }
                self.duration = recorder.currentTime
                recorder.updateMeters()
                let level = min(max((Double(recorder.peakPower(forChannel: 0)) + 48) / 48, 0), 1)
                self.samples.append(UInt8((level * 31).rounded()))
            }
        } catch {
            cancel()
            try? FileManager.default.removeItem(at: url)
            self.error = "Не удалось начать запись: \(error.localizedDescription)"
        }
    }

    func finish() -> VoiceNoteDraft? {
        guard let recorder else { return nil }
        let elapsed = recorder.currentTime
        let url = recorder.url
        let waveform = VoiceWaveform.pack(VoiceWaveform.resample(samples, count: 64))
        clear()
        guard elapsed >= 0.5 else {
            try? FileManager.default.removeItem(at: url)
            error = "Запишите не менее полусекунды."
            return nil
        }
        return VoiceNoteDraft(url: url, duration: max(1, Int(elapsed.rounded())), waveform: waveform)
    }

    func cancel() {
        let url = recorder?.url
        clear()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    private func clear() {
        permissionTicket = UUID()
        timer?.invalidate()
        timer = nil
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        samples.removeAll(keepingCapacity: true)
        duration = 0
        isPreparing = false
        isRecording = false
        if ownsSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsSession = false
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard self.recorder === recorder else { return }
        cancel()
        error = flag ? "Запись была прервана." : "Не удалось сохранить запись."
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        guard self.recorder === recorder else { return }
        cancel()
        self.error = error?.localizedDescription ?? "Ошибка кодирования голосового сообщения."
    }
}

struct VoiceNoteDraft {
    let url: URL
    let duration: Int
    let waveform: Data
}
