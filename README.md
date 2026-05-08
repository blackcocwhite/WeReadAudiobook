# WeReadAudiobook

English | [中文](#中文)

WeReadAudiobook is a macOS menu bar app that turns the current WeRead page into spoken audio. It captures the visible WeRead reading area, runs local PaddleOCR, cleans OCR text for speech, sends the text to MiMo TTS, plays the generated audio, saves MP3 files, and turns pages in order.

The app is built for local, hands-free reading. OCR runs locally; screenshots are not sent to a cloud OCR service. OCR text is sent directly to TTS without LLM rewriting.

## Features

- **Menu bar app**: runs as a lightweight macOS menu bar utility.
- **WeRead window capture**: finds the WeRead window and captures the visible page.
- **Reading-area crop**: excludes title bars, chapter headers, and page numbers while keeping the full page width.
- **Local OCR**: uses PaddleOCR through a long-running local Python worker.
- **OCR preprocessing**: resizes, grayscales, sharpens, and improves contrast before recognition.
- **Speech-oriented cleanup**: removes OCR artifacts, merges Chinese line wraps, preserves English spacing, and avoids reading page noise.
- **MiMo TTS integration**: generates audio from cleaned OCR text.
- **Sequential playback**: plays one page at a time in order.
- **One-page lookahead**: prepares the next page while the current page is playing.
- **Playback controls**: start, pause, resume, stop, TTS speed, playback speed, page-turn delay, and max segment length.
- **Audio export**: saves generated MP3 files under `WeReadAudio_yyyyMMdd_HHmmss/`.
- **App packaging**: builds a double-clickable macOS `.app` under `dist/`.

## Requirements

- macOS 13 or later.
- Xcode Command Line Tools / Swift Package Manager.
- Python 3.11 for local OCR setup and packaging.
- Screen Recording permission for window capture.
- Accessibility permission for page turning.
- A MiMo TTS API key configured in the app settings.

## Setup

Clone the repository and enter the project directory:

```bash
git clone https://github.com/blackcocwhite/WeReadAudiobook.git
cd WeReadAudiobook
```

Install the local OCR runtime:

```bash
scripts/setup-paddleocr.sh
```

Build the app:

```bash
swift build
```

Run the local checks:

```bash
scripts/run-checks.sh
scripts/run-ocr-smoke.sh
```

## Usage

1. Open WeRead and navigate to the page you want to read.
2. Start WeReadAudiobook.
3. Grant macOS Screen Recording permission when prompted.
4. Grant macOS Accessibility permission when prompted.
5. Open settings from the menu bar panel.
6. Configure your MiMo TTS API key and optional voice/speed settings.
7. Click **Start Reading**.

The app will capture the current page, OCR the reading area, synthesize audio, play it, save MP3 files, turn the page, and continue.

## Packaging

To create a double-clickable macOS app:

```bash
scripts/package-app.sh
```

Output:

```text
dist/WeReadAudiobook.app
```

The packaged app includes the OCR scripts and a bundled Python OCR environment under `Contents/Resources`. The package is locally ad-hoc signed for personal use. It is not Apple-notarized for public distribution.

## Project Structure

```text
Sources/WeReadAudiobook/       Swift app source
scripts/paddle_ocr_worker.py   Local PaddleOCR worker
scripts/setup-paddleocr.sh     OCR environment setup
scripts/run-checks.sh          Lightweight behavior checks
scripts/run-ocr-smoke.sh       Swift-to-OCR smoke test
scripts/package-app.sh         macOS app packaging
Tests/checks.swift             Pure Swift regression checks
docs/                          Project reference files
```

## OCR Strategy

The default OCR profile is `quality`:

- Detection: `PP-OCRv5_mobile_det`
- Recognition: `PP-OCRv5_server_rec`

This profile avoids the high memory cost of full server detection while improving recognition quality compared with pure mobile OCR. The app preprocesses each image before OCR and reuses a long-running worker so models do not reload for every page.

## Privacy

- OCR runs locally.
- Screenshots are not sent to cloud OCR services.
- OCR text is sent to the configured MiMo TTS endpoint.
- MiMo API keys are stored locally in app settings.
- Generated audio, `.venv-ocr`, `.build`, and packaged `dist/` output are ignored by Git.

## License

No open-source license has been specified yet.

---

# 中文

[English](#wereadaudiobook) | 中文

WeReadAudiobook 是一个 macOS 菜单栏应用，用来把当前微信读书页面转换成语音朗读。它会截取微信读书阅读区域，使用本地 PaddleOCR 识别文字，清洗适合朗读的文本，发送到 MiMo TTS 生成音频，然后按页顺序播放、保存 MP3，并自动翻页。

这个项目面向本地阅读场景。OCR 在本机运行，不把截图上传到云端 OCR；OCR 识别出的文字直接进入 TTS，不经过大模型改写或润色。

## 功能

- **菜单栏常驻**：作为 macOS 菜单栏工具运行。
- **微信读书窗口截取**：自动寻找微信读书窗口并截取当前页。
- **正文区域裁剪**：去掉窗口标题、章节标题、页码区域，同时保留完整页面宽度。
- **本地 OCR**：通过本地 Python worker 调用 PaddleOCR。
- **OCR 图片预处理**：识别前会放大、灰度化、增强对比度和清晰度。
- **朗读前文本清洗**：过滤页码和残留符号，合并中文换行，保留英文空格，减少不自然停顿。
- **MiMo TTS**：把清洗后的文字合成为音频。
- **按页顺序播放**：一页一页串行播放。
- **提前准备下一页**：当前页播放时，后台准备下一页，减少等待。
- **播放控制**：开始、暂停、继续、停止、TTS 语速、播放倍速、翻页延迟、每段最大字数。
- **音频保存**：生成的 MP3 会保存到 `WeReadAudio_yyyyMMdd_HHmmss/`。
- **应用打包**：可以打包成可双击启动的 macOS `.app`。

## 运行要求

- macOS 13 或更高版本。
- Xcode Command Line Tools / Swift Package Manager。
- Python 3.11，用于本地 OCR 环境和打包。
- macOS 屏幕录制权限，用于截取微信读书窗口。
- macOS 辅助功能权限，用于自动翻页。
- 在应用设置里配置 MiMo TTS API Key。

## 安装和初始化

克隆项目：

```bash
git clone https://github.com/blackcocwhite/WeReadAudiobook.git
cd WeReadAudiobook
```

安装本地 OCR 环境：

```bash
scripts/setup-paddleocr.sh
```

构建应用：

```bash
swift build
```

运行检查：

```bash
scripts/run-checks.sh
scripts/run-ocr-smoke.sh
```

## 使用方法

1. 打开微信读书，并停在你想朗读的页面。
2. 启动 WeReadAudiobook。
3. 按提示授予屏幕录制权限。
4. 按提示授予辅助功能权限。
5. 在菜单栏面板里打开设置。
6. 配置 MiMo TTS API Key，以及可选的声音、语速、播放倍速等。
7. 点击 **开始朗读**。

应用会自动截取当前页、OCR 识别正文、合成语音、播放音频、保存 MP3、翻页并继续朗读。

## 打包成 macOS 软件

运行：

```bash
scripts/package-app.sh
```

输出：

```text
dist/WeReadAudiobook.app
```

打包后的 `.app` 内置 OCR 脚本和 Python OCR 环境，位置在 `Contents/Resources`。当前是本机自签名版本，适合个人本机使用；不是 Apple 公证后的公开分发版本。

## 项目结构

```text
Sources/WeReadAudiobook/       Swift 应用源码
scripts/paddle_ocr_worker.py   本地 PaddleOCR worker
scripts/setup-paddleocr.sh     OCR 环境初始化
scripts/run-checks.sh          轻量行为检查
scripts/run-ocr-smoke.sh       Swift 到 OCR 链路测试
scripts/package-app.sh         macOS 应用打包脚本
Tests/checks.swift             Swift 回归检查
docs/                          项目参考文档
```

## OCR 策略

默认 OCR 配置是 `quality`：

- 检测模型：`PP-OCRv5_mobile_det`
- 识别模型：`PP-OCRv5_server_rec`

这样避免完整 server 检测模型带来的高内存占用，同时比纯 mobile OCR 有更好的文字识别质量。应用会在 OCR 前预处理图片，并复用一个常驻 OCR worker，避免每页重复加载模型。

## 隐私说明

- OCR 在本机运行。
- 截图不会发送到云端 OCR 服务。
- OCR 文字会发送到你配置的 MiMo TTS 接口。
- MiMo API Key 保存在本地应用设置中。
- 生成音频、`.venv-ocr`、`.build`、`dist/` 都不会提交到 Git。

## 许可证

暂未指定开源许可证。
