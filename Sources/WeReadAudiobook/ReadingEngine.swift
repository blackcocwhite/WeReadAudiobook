import Foundation
import AppKit
import Combine

enum ReadingState: Equatable {
    case idle
    case capturing
    case recognizing
    case synthesizing
    case playing
    case turningPage
    case paused
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "就绪"
        case .capturing: return "截屏中..."
        case .recognizing: return "识别文字中..."
        case .synthesizing: return "合成语音中..."
        case .playing: return "朗读中"
        case .turningPage: return "翻页中..."
        case .paused: return "已暂停"
        case .error(let msg): return "错误: \(msg)"
        }
    }

    var acceptsPauseRequest: Bool {
        switch self {
        case .capturing, .recognizing, .synthesizing, .playing, .turningPage:
            return true
        case .idle, .paused, .error:
            return false
        }
    }
}

enum ReadingPageFlow {
    static let lookaheadOrder: [ReadingState] = [.playing, .turningPage, .capturing, .recognizing, .synthesizing]
    static let maxEmptyPageRetries = 2
}

struct PreparedPage {
    let number: Int
    let segments: [String]
    let audioItems: [Data]
}

@MainActor
final class ReadingEngine: ObservableObject {
    static let shared = ReadingEngine()

    @Published var state: ReadingState = .idle
    @Published var currentPageText: String = ""
    @Published var pagesRead: Int = 0
    @Published var errorMessage: String?

    private let screenCapture = ScreenCapture.shared
    private let textRecognition = TextRecognition.shared
    private let textProcessor = TextProcessor.shared
    private let ttsService = TTSService.shared
    private let audioManager = AudioManager.shared
    private let pageTurner = PageTurner.shared

    private var isRunning = false
    private var shouldStop = false
    private var isPaused = false
    private var stateBeforePause: ReadingState?
    private var currentTask: Task<Void, Never>?
    private var audioFileCounter = 0
    private var emptyPageRetryCount = 0
    private var audioSaveDirectory: URL?
    private var logFileURL: URL?

    private init() {
        audioManager.delegate = self
    }

    func startReading() {
        guard !isRunning else { return }

        // Check permissions
        if !screenCapture.checkScreenRecordingPermission() {
            state = .error("需要屏幕录制权限")
            screenCapture.openScreenRecordingSettings()
            return
        }

        if !pageTurner.checkAccessibilityPermission() {
            state = .error("需要辅助功能权限")
            pageTurner.requestAccessibilityPermission()
            return
        }

        guard ttsService.isConfigured else {
            state = .error("请先配置 MiMo TTS API Key")
            return
        }

        isRunning = true
        shouldStop = false
        isPaused = false
        stateBeforePause = nil
        textProcessor.clearReadHistory()
        pagesRead = 0
        audioFileCounter = 0
        emptyPageRetryCount = 0
        setupAudioSaveDirectory()
        setupLogFile()

        currentTask = Task {
            await readingLoop()
        }
    }

    func stopReading() {
        shouldStop = true
        isRunning = false
        isPaused = false
        stateBeforePause = nil
        audioManager.stop()
        currentTask?.cancel()
        currentTask = nil
        state = .idle
        currentPageText = ""
        emptyPageRetryCount = 0
    }

    func pauseReading() {
        guard isRunning, state.acceptsPauseRequest else { return }
        isPaused = true
        stateBeforePause = state
        audioManager.pause()
        state = .paused
    }

    func resumeReading() {
        guard isRunning, isPaused else { return }
        isPaused = false

        if audioManager.resume() {
            state = .playing
        } else if let stateBeforePause {
            state = stateBeforePause
        }
        stateBeforePause = nil
    }

    private func waitIfPaused() async {
        while isPaused && !shouldStop {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func setupAudioSaveDirectory() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let folderName = "WeReadAudio_\(formatter.string(from: Date()))"

        let dir = ProjectPaths.root.appendingPathComponent(folderName)

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        audioSaveDirectory = dir
        print("[Audio] 音频保存目录: \(dir.path)")
    }

    private func setupLogFile() {
        guard let dir = audioSaveDirectory else { return }
        logFileURL = dir.appendingPathComponent("log.txt")
        let header = "=== WeRead Audio Log ===\n\n"
        try? header.write(to: logFileURL!, atomically: true, encoding: .utf8)
        print("[Log] 日志文件: \(logFileURL!.path)")
    }

    private func appendLog(_ text: String) {
        guard let url = logFileURL else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = text.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }

    private func saveAudio(_ data: Data) {
        guard let dir = audioSaveDirectory else { return }
        audioFileCounter += 1
        let fileURL = dir.appendingPathComponent("\(audioFileCounter).mp3")
        do {
            try data.write(to: fileURL)
            print("[Audio] 已保存: \(fileURL.lastPathComponent)")
        } catch {
            print("[Audio] 保存失败: \(error.localizedDescription)")
        }
    }

    private func synthesizeWithRetries(_ segment: String) async throws -> Data {
        var retryCount = 0
        let maxRetries = 3
        var lastError: Error?

        while retryCount < maxRetries && !shouldStop {
            do {
                return try await ttsService.synthesize(text: segment)
            } catch {
                lastError = error
                retryCount += 1
                print("[TTS] 合成失败 (第\(retryCount)次): \(error.localizedDescription)")
                if retryCount < maxRetries {
                    state = .error("合成失败，重试中 (\(retryCount)/\(maxRetries))...")
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        throw lastError ?? TTSError.requestFailed("合成已停止")
    }

    private func handleEmptyPage() async -> Bool {
        emptyPageRetryCount += 1

        if emptyPageRetryCount <= ReadingPageFlow.maxEmptyPageRetries {
            let message = "[OCR] 当前页未识别到可朗读文字，重试 \(emptyPageRetryCount)/\(ReadingPageFlow.maxEmptyPageRetries)"
            print(message)
            appendLog("\(message)\n")
            try? await Task.sleep(nanoseconds: 800_000_000)
            return true
        }

        let message = "当前页连续识别为空，已停止以避免跳页"
        state = .error(message)
        errorMessage = message
        shouldStop = true
        return false
    }

    private func prepareCurrentVisiblePage(number: Int, updatesPreview: Bool) async throws -> PreparedPage? {
        while !shouldStop {
            await waitIfPaused()
            if shouldStop { return nil }

            state = .capturing
            let image = try screenCapture.captureWeReadWindow()
            await waitIfPaused()
            if shouldStop { return nil }

            state = .recognizing
            let blocks = try await recognizeTextInBackground(from: image)
            await waitIfPaused()
            if shouldStop { return nil }

            let segments = textProcessor.process(blocks: blocks)
            let rawText = TextRecognition.shared.concatenateText(from: blocks)
            print("[OCR] 原始文本:\n\(rawText)\n---")
            appendLog("\n--- Page \(number) ---\n[OCR 原文]\n\(rawText)\n")

            print("[OCR] 最终段落: \(segments)")

            if segments.isEmpty {
                let shouldRetry = await handleEmptyPage()
                if shouldRetry {
                    continue
                }
                return nil
            }

            emptyPageRetryCount = 0

            var pageAudioItems: [Data] = []
            for segment in segments {
                await waitIfPaused()
                if shouldStop { return nil }

                if updatesPreview {
                    currentPageText = segment
                }
                state = .synthesizing

                let data = try await synthesizeWithRetries(segment)

                await waitIfPaused()
                if shouldStop { return nil }

                saveAudio(data)
                pageAudioItems.append(data)
            }

            guard !pageAudioItems.isEmpty else {
                return nil
            }

            return PreparedPage(number: number, segments: segments, audioItems: pageAudioItems)
        }

        return nil
    }

    private func readingLoop() async {
        do {
            guard var preparedPage = try await prepareCurrentVisiblePage(number: 1, updatesPreview: true) else {
                isRunning = false
                return
            }

            while !shouldStop {
                let currentPage = preparedPage
                currentPageText = currentPage.segments.joined(separator: "\n")
                state = .playing

                async let playbackComplete: Void = audioManager.playPage(currentPage.audioItems)

                await waitIfPaused()
                if shouldStop {
                    await playbackComplete
                    break
                }

                state = .turningPage
                try await pageTurner.turnPage()
                await waitIfPaused()
                if shouldStop {
                    await playbackComplete
                    break
                }

                let nextPageNumber = currentPage.number + 1
                let nextPage = try await prepareCurrentVisiblePage(number: nextPageNumber, updatesPreview: false)

                if !shouldStop {
                    state = .playing
                }
                await playbackComplete
                if !shouldStop {
                    pagesRead += 1
                }

                guard let nextPage else {
                    break
                }

                preparedPage = nextPage
            }
        } catch {
            if !shouldStop {
                state = .error(error.localizedDescription)
                errorMessage = error.localizedDescription
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .error = state {
                    state = .idle
                }
            }
        }

        isRunning = false
    }

    private func recognizeTextInBackground(from image: NSImage) async throws -> [RecognizedTextBlock] {
        let textRecognition = self.textRecognition

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let blocks = try textRecognition.recognizeText(from: image)
                    continuation.resume(returning: blocks)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension ReadingEngine: AudioManagerDelegate {
    nonisolated func audioManagerDidFinishPlaying(_ manager: AudioManager) {
        Task { @MainActor in
            if !self.isRunning {
                self.state = .idle
            }
        }
    }

    nonisolated func audioManager(_ manager: AudioManager, didEncounterError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
