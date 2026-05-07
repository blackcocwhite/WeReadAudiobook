import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: ReadingEngine
    @AppStorage("mimoApiKey") private var apiKey: String = ""
    @AppStorage("mimoEndpoint") private var endpoint: String = TTSConfiguration.defaultEndpoint
    @AppStorage("mimoVoiceId") private var voiceId: String = "mimo_default"
    @AppStorage("ttsSpeed") private var speed: Double = 1.0
    @AppStorage("playbackRate") private var playbackRate: Double = 1.0
    @AppStorage("pageTurnDelay") private var pageTurnDelay: Double = 1.0
    @AppStorage("maxSegmentLength") private var maxSegmentLength: Int = 500

    @State private var apiKeyVisible = false

    var body: some View {
        TabView {
            apiSettingsTab
                .tabItem {
                    Label("API 设置", systemImage: "key.fill")
                }

            readingSettingsTab
                .tabItem {
                    Label("朗读设置", systemImage: "speaker.wave.2.fill")
                }

            permissionsTab
                .tabItem {
                    Label("权限", systemImage: "lock.shield.fill")
                }
        }
        .frame(width: 450, height: 350)
        .onAppear {
            applySettings()
        }
        .onChange(of: playbackRate) { _ in
            applySettings()
        }
        .onChange(of: speed) { _ in
            applySettings()
        }
        .onChange(of: pageTurnDelay) { _ in
            applySettings()
        }
        .onChange(of: maxSegmentLength) { _ in
            applySettings()
        }
    }

    // MARK: - API Settings Tab

    private var apiSettingsTab: some View {
        Form {
            Section("MiMo TTS API") {
                HStack {
                    if apiKeyVisible {
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { apiKeyVisible.toggle() }) {
                        Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                TextField("API 端点", text: $endpoint)
                    .textFieldStyle(.roundedBorder)

                Picker("音色", selection: $voiceId) {
                    ForEach(TTSConfiguration.availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
            }

            HStack {
                Spacer()
                Button("保存并应用") {
                    applySettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Reading Settings Tab

    private var readingSettingsTab: some View {
        Form {
            Section("语音参数") {
                HStack {
                    Text("TTS 语速")
                    Slider(value: $speed, in: 0.5...2.0, step: 0.1) {
                        Text("语速")
                    }
                    Text("\(String(format: "%.1f", speed))x")
                        .monospacedDigit()
                        .frame(width: 40)
                }

                HStack {
                    Text("播放倍速")
                    Slider(value: $playbackRate, in: 0.5...2.0, step: 0.1) {
                        Text("播放倍速")
                    }
                    Text("\(String(format: "%.1f", playbackRate))x")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("朗读参数") {
                HStack {
                    Text("翻页延迟")
                    Slider(value: $pageTurnDelay, in: 0.5...3.0, step: 0.5) {
                        Text("翻页延迟")
                    }
                    Text("\(String(format: "%.1f", pageTurnDelay))s")
                        .monospacedDigit()
                        .frame(width: 40)
                }

                Stepper("每段最大字数: \(maxSegmentLength)", value: $maxSegmentLength, in: 200...1000, step: 100)
            }

            HStack {
                Spacer()
                Button("保存并应用") {
                    applySettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Permissions Tab

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("所需权限")
                .font(.headline)

            PermissionRow(
                title: "屏幕录制",
                description: "用于截取微信读书窗口内容",
                isGranted: ScreenCapture.shared.checkScreenRecordingPermission(),
                onRequest: {
                    ScreenCapture.shared.openScreenRecordingSettings()
                }
            )

            PermissionRow(
                title: "辅助功能",
                description: "用于模拟键盘操作自动翻页",
                isGranted: PageTurner.shared.checkAccessibilityPermission(),
                onRequest: {
                    PageTurner.shared.requestAccessibilityPermission()
                }
            )

            Spacer()

            Text("提示：授权后可能需要重启应用才能生效")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Helpers

    private func applySettings() {
        TTSService.shared.configuration.apiKey = apiKey
        TTSService.shared.configuration.apiEndpoint = endpoint
        TTSService.shared.configuration.voiceId = voiceId
        TTSService.shared.configuration.speed = speed
        AudioManager.shared.setPlaybackRate(Float(playbackRate))
        playbackRate = Double(AudioManager.shared.playbackRate)
        PageTurner.shared.pageTurnDelay = pageTurnDelay
        TextProcessor.shared.maxSegmentLength = maxSegmentLength
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isGranted ? .green : .red)
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("授权") {
                    onRequest()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}
