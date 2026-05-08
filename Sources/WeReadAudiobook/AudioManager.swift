import AVFoundation
import Foundation

protocol AudioManagerDelegate: AnyObject {
    func audioManagerDidFinishPlaying(_ manager: AudioManager)
    func audioManager(_ manager: AudioManager, didEncounterError error: Error)
}

final class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    weak var delegate: AudioManagerDelegate?

    @Published var isPlaying = false
    @Published var isPaused = false

    @Published private(set) var playbackRate: Float = 1.0

    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [Data] = []
    private var isProcessingQueue = false
    private var queueDrainContinuations: [CheckedContinuation<Void, Never>] = []

    private override init() {
        super.init()
        // Load playback rate from saved settings
        let savedRate = UserDefaults.standard.double(forKey: "playbackRate")
        if savedRate > 0 {
            playbackRate = Self.normalizedPlaybackRate(Float(savedRate))
        }
    }

    static func normalizedPlaybackRate(_ rate: Float) -> Float {
        min(max(rate, 0.5), 2.0)
    }

    func setPlaybackRate(_ rate: Float) {
        let normalized = Self.normalizedPlaybackRate(rate)
        playbackRate = normalized
        UserDefaults.standard.set(Double(normalized), forKey: "playbackRate")

        if let audioPlayer {
            audioPlayer.enableRate = true
            audioPlayer.rate = normalized
        }
    }

    /// Enqueue audio data for playback
    func enqueue(_ audioData: Data) {
        audioQueue.append(audioData)
        processQueue()
    }

    func playPage(_ audioItems: [Data]) async {
        guard !audioItems.isEmpty else { return }

        for audioData in audioItems {
            enqueue(audioData)
        }

        await waitUntilQueueDrained()
    }

    /// Play audio data immediately (clears queue)
    func playImmediately(_ audioData: Data) {
        stop()
        do {
            try startPlayback(audioData)
        } catch {
            delegate?.audioManager(self, didEncounterError: error)
        }
    }

    @discardableResult
    func pause() -> Bool {
        guard let audioPlayer, audioPlayer.isPlaying else { return false }
        audioPlayer.pause()
        isPaused = true
        isPlaying = false
        return true
    }

    @discardableResult
    func resume() -> Bool {
        guard let audioPlayer, isPaused else { return false }
        audioPlayer.rate = playbackRate
        audioPlayer.play()
        isPaused = false
        isPlaying = true
        return true
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioQueue.removeAll()
        isPlaying = false
        isPaused = false
        isProcessingQueue = false
        resumeQueueDrainContinuations()
    }

    private func processQueue() {
        guard !isProcessingQueue else { return }
        guard !audioQueue.isEmpty else { return }
        guard !isPlaying else { return }

        isProcessingQueue = true
        let nextData = audioQueue.removeFirst()

        do {
            try startPlayback(nextData)
        } catch {
            isProcessingQueue = false
            delegate?.audioManager(self, didEncounterError: error)
            resumeQueueDrainContinuationsIfNeeded()
        }
    }

    private func startPlayback(_ data: Data) throws {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.enableRate = true
        player.rate = playbackRate
        player.prepareToPlay()
        self.audioPlayer = player
        player.play()
        isPlaying = true
        isPaused = false
    }

    private var isQueueDrained: Bool {
        audioQueue.isEmpty && !isProcessingQueue && !isPlaying && !isPaused
    }

    private func waitUntilQueueDrained() async {
        if isQueueDrained {
            return
        }

        await withCheckedContinuation { continuation in
            queueDrainContinuations.append(continuation)
            resumeQueueDrainContinuationsIfNeeded()
        }
    }

    private func resumeQueueDrainContinuationsIfNeeded() {
        if isQueueDrained {
            resumeQueueDrainContinuations()
        }
    }

    private func resumeQueueDrainContinuations() {
        let continuations = queueDrainContinuations
        queueDrainContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if !flag {
                self.delegate?.audioManager(self, didEncounterError: NSError(
                    domain: "AudioManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "音频播放未完成"]
                ))
            }

            self.isPlaying = false
            self.isProcessingQueue = false

            if self.audioQueue.isEmpty {
                self.delegate?.audioManagerDidFinishPlaying(self)
                self.resumeQueueDrainContinuationsIfNeeded()
            } else {
                self.processQueue()
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.isProcessingQueue = false
            if let error {
                self.delegate?.audioManager(self, didEncounterError: error)
            }
            self.resumeQueueDrainContinuationsIfNeeded()
        }
    }
}
