# WeReadAudiobook

## Project Context

- This is a macOS Swift Package executable for a menu bar app that turns WeRead pages into spoken audio.
- The main flow is: capture the WeRead window, run local PaddleOCR, clean and split text, synthesize audio, play it, save generated audio, then turn the page.
- Core code lives in `Sources/WeReadAudiobook`; generated audio folders use the `WeReadAudio_yyyyMMdd_HHmmss` naming pattern.

## Local Commands

- Build check: `swift build`
- Lightweight behavior checks: `scripts/run-checks.sh`
- OCR setup: `scripts/setup-paddleocr.sh`
- OCR smoke check: `scripts/run-ocr-smoke.sh`
- The local Command Line Tools install does not currently provide `XCTest`; keep small pure checks in `Tests/checks.swift` until the toolchain supports standard Swift tests.

## Runtime Notes

- Runtime use requires macOS Screen Recording permission for window capture and Accessibility permission for page turning.
- OCR uses a local Python 3.11 virtual environment at `.venv-ocr` and a long-running `scripts/paddle_ocr_worker.py` process so PaddleOCR models load once.
- PaddleOCR should default to the `quality` profile: mobile detection plus server recognition and worker-side preprocessing. The full `accurate` profile uses server detection too and measured around 7GB peak RSS locally, so do not make it the default.
- Do not assume WeRead is focused; page turning currently posts keyboard events to the WeRead process.
- Avoid hardcoded absolute paths when adding new output locations. If existing paths are touched, preserve current behavior unless the task is explicitly to make the app portable.
- WeRead window capture must keep the full left/right width, but crop the top down to the body text area so tabs, title bar, and chapter title do not reach OCR. Keep the crop regression checks in `Tests/checks.swift` aligned with this.

## Security And Privacy

- Do not hardcode API keys, tokens, or account data in source files.
- Keep MiMo API credentials in user settings or another local-only secret source.
- Do not log secrets or full request headers.
- Do not commit generated audio, logs, `.build`, `.swiftpm`, `.DS_Store`, or local environment files.

## Change Guidelines

- Keep changes small and aligned with the existing singleton-based service structure unless the requested task is a refactor.
- UI state updates for the reading flow should remain on the main actor.
- For changes touching capture, OCR, TTS, audio playback, permissions, file output, or external requests, run `swift build` and do a quick self-review for permission, privacy, and failure-state behavior before reporting back.
