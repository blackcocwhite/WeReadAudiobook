# WeReadAudiobook

## One-Line Description

WeReadAudiobook is a macOS menu bar app that reads WeRead pages aloud by combining local PaddleOCR, text cleanup, MiMo TTS, sequential audio playback, and automatic page turning.

## Purpose

The app solves a practical reading problem: WeRead has visible page text, but the user wants hands-free spoken playback in page order. WeReadAudiobook converts the visible page into speech without parsing book files or uploading screenshots to a cloud OCR provider.

## Core Features

- Captures the current WeRead window.
- Crops the screenshot to the reading body area.
- Runs local PaddleOCR through a Python worker.
- Cleans OCR output before speech.
- Sends cleaned text to MiMo TTS.
- Saves generated MP3 files.
- Plays each page in order.
- Turns the page automatically.
- Prepares the next page while the current page plays.
- Supports pause, resume, stop, playback speed, TTS speed, page delay, and segment length settings.
- Packages into a macOS `.app`.

## Architecture

The app is a Swift Package executable target.

Important components:

- `App.swift`: SwiftUI menu bar app entry.
- `MenuBarView.swift`: menu bar controls and inline settings panel.
- `ReadingEngine.swift`: main page reading orchestration.
- `ScreenCapture.swift`: WeRead window discovery and screenshot cropping.
- `TextRecognition.swift`: OCR facade.
- `PaddleOCRClient.swift`: long-running local OCR worker integration.
- `TextProcessor.swift`: OCR cleanup and speech segmentation.
- `TTSService.swift`: MiMo TTS request handling.
- `AudioManager.swift`: audio queue and playback control.
- `PageTurner.swift`: accessibility-based page turning.
- `scripts/paddle_ocr_worker.py`: PaddleOCR worker process.
- `scripts/package-app.sh`: macOS `.app` packaging.

## OCR Strategy

The default OCR profile is `quality`, which uses mobile text detection and server text recognition. This keeps memory low while improving recognition quality over pure mobile OCR.

The full server detection profile was measured at around 7GB peak memory locally and is not the default.

OCR input images are preprocessed before recognition:

- resized,
- grayscaled,
- contrast enhanced,
- sharpened.

## Text Cleanup Strategy

Text cleanup is tuned for Chinese novel reading in WeRead:

- Chinese line wraps are merged without spaces.
- Sentence-ending line breaks keep a natural separator.
- Latin line wraps keep spaces.
- Page number lines are removed.
- Chapter title lines are removed.
- Isolated symbols and low-confidence tiny OCR fragments are filtered.
- Common quote recognition mistakes such as sentence-final `99` are corrected.

## Packaging

Run:

```bash
scripts/package-app.sh
```

Output:

```text
dist/WeReadAudiobook.app
```

The package includes the app executable, OCR scripts, and an OCR Python environment under `Contents/Resources`.

## Privacy and Credentials

OCR is local. Screenshots are not sent to a cloud OCR service.

TTS text is sent to the configured MiMo TTS endpoint. The API key is stored locally through app settings and must not be committed.

## Requirements

- macOS 13 or later.
- Screen Recording permission.
- Accessibility permission.
- Python 3.11 for OCR setup and packaging.
- MiMo TTS API key.
