import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var engine: ReadingEngine
    @StateObject private var audioManager = AudioManager.shared
    @State private var isShowingSettings = false

    var body: some View {
        if isShowingSettings {
            settingsPanel
        } else {
            controlsPanel
        }
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(engine.state.displayText)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Current text preview
            if !engine.currentPageText.isEmpty {
                Text(engine.currentPageText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Error message
            if let error = engine.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            // Pages read counter
            if engine.pagesRead > 0 {
                Text("已读 \(engine.pagesRead) 页")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("播放倍速 \(String(format: "%.1f", audioManager.playbackRate))x")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Controls
            HStack(spacing: 8) {
                switch engine.state {
                case .idle, .error:
                    Button("开始朗读") {
                        engine.startReading()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s")

                case .playing, .capturing, .recognizing, .synthesizing, .turningPage:
                    Button("暂停") {
                        engine.pauseReading()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("p")

                    Button("停止") {
                        engine.stopReading()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("x")

                case .paused:
                    Button("继续") {
                        engine.resumeReading()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("r")

                    Button("停止") {
                        engine.stopReading()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("x")
                }
            }

            Divider()

            // Settings and Quit
            HStack {
                Button("设置") {
                    isShowingSettings = true
                }
                .font(.caption)

                Spacer()

                Button("退出") {
                    engine.stopReading()
                    NSApp.terminate(nil)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("返回") {
                    isShowingSettings = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("设置")
                    .font(.headline)

                Spacer()
            }

            SettingsView()
                .environmentObject(engine)
        }
        .padding(16)
        .frame(width: 480, height: 430)
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle:
            return .gray
        case .playing:
            return .green
        case .paused:
            return .orange
        case .error:
            return .red
        default:
            return .blue
        }
    }
}
