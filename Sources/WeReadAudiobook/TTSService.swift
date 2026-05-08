import Foundation

enum TTSError: LocalizedError {
    case notConfigured
    case invalidURL
    case requestFailed(String)
    case noAudioData
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中配置 MiMo TTS API Key"
        case .invalidURL:
            return "API 地址无效"
        case .requestFailed(let msg):
            return "TTS 请求失败: \(msg)"
        case .noAudioData:
            return "未返回音频数据"
        case .decodingFailed:
            return "音频数据解析失败"
        }
    }
}

struct TTSConfiguration {
    static let defaultEndpoint = "https://token-plan-cn.xiaomimimo.com/v1/chat/completions"

    var apiEndpoint: String = defaultEndpoint
    var apiKey: String = ""
    var voiceId: String = "mimo_default"
    var speed: Double = 1.0
    var format: AudioFormat = .mp3

    static let availableVoices = ["mimo_default", "冰糖", "茉莉", "苏打", "白桦", "Mia", "Chloe", "Milo", "Dean"]

    enum AudioFormat: String {
        case mp3
        case wav
        case opus
        case aac

        var mimeType: String {
            switch self {
            case .mp3: return "audio/mpeg"
            case .wav: return "audio/wav"
            case .opus: return "audio/opus"
            case .aac: return "audio/aac"
            }
        }
    }
}

final class TTSService {
    static let shared = TTSService()

    var configuration = TTSConfiguration()

    private let session: URLSession
    private var isSynthesizing = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        loadSavedConfiguration()
    }

    private func loadSavedConfiguration() {
        let defaults = UserDefaults.standard
        configuration.apiKey = defaults.string(forKey: "mimoApiKey") ?? ""
        configuration.apiEndpoint = defaults.string(forKey: "mimoEndpoint") ?? TTSConfiguration.defaultEndpoint
        configuration.voiceId = defaults.string(forKey: "mimoVoiceId") ?? "mimo_default"

        let savedSpeed = defaults.double(forKey: "ttsSpeed")
        if savedSpeed > 0 {
            configuration.speed = savedSpeed
        }
    }

    var isConfigured: Bool {
        !configuration.apiKey.isEmpty
    }

    /// Synthesize text to audio data via MiMo TTS API (chat completions format)
    func synthesize(text: String) async throws -> Data {
        guard isConfigured else {
            throw TTSError.notConfigured
        }

        guard let url = URL(string: configuration.apiEndpoint) else {
            throw TTSError.invalidURL
        }

        isSynthesizing = true
        defer { isSynthesizing = false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // MiMo TTS uses chat completions format with user + assistant messages
        let body: [String: Any] = [
            "model": "mimo-v2.5-tts",
            "messages": [
                ["role": "user", "content": text],
                ["role": "assistant", "content": text]
            ],
            "stream": false,
            "audio": [
                "voice": configuration.voiceId,
                "format": configuration.format.rawValue
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TTSError.requestFailed("无效的服务器响应")
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "未知错误"
                throw TTSError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
            }

            // Parse JSON response: audio data is in choices[0].message.audio.data (base64)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let audio = message["audio"] as? [String: Any],
                  let audioBase64 = audio["data"] as? String,
                  let audioData = Data(base64Encoded: audioBase64) else {
                throw TTSError.decodingFailed
            }

            return audioData

        } catch let error as TTSError {
            throw error
        } catch {
            throw TTSError.requestFailed(error.localizedDescription)
        }
    }

    func cancelCurrentSynthesis() {
        session.invalidateAndCancel()
    }
}
