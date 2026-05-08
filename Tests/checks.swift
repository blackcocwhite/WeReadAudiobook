import CoreGraphics
import Foundation
@testable import WeReadAudiobook

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("check failed: \(message)\n", stderr)
        exit(1)
    }
}

func expectEqual(_ actual: CGFloat, _ expected: CGFloat, _ message: String) {
    let tolerance: CGFloat = 0.001
    expect(abs(actual - expected) <= tolerance, "\(message): expected \(expected), got \(actual)")
}

let cropRect = ScreenCapture.contentCropRect(forImageWidth: 1000, height: 1000)
expectEqual(cropRect.origin.x, 0, "crop must keep the full window width from the left edge")
expectEqual(cropRect.origin.y, 70, "crop starts below tabs and chapter title")
expectEqual(cropRect.width, 1000, "crop must not trim the left or right sides")
expectEqual(cropRect.height, 905, "crop keeps only the reading content area")
expectEqual(cropRect.maxY, 975, "crop stops before the page number line")

let tallWeReadCropRect = ScreenCapture.contentCropRect(forImageWidth: 1024, height: 1792)
expectEqual(tallWeReadCropRect.origin.x, 0, "tall window crop keeps the full left edge")
expectEqual(tallWeReadCropRect.origin.y, 125, "tall window crop starts below the chapter title")
expectEqual(tallWeReadCropRect.width, 1024, "tall window crop must not trim the sides")
expectEqual(tallWeReadCropRect.maxY, 1747, "tall window crop excludes the pager band")

expect(AudioManager.normalizedPlaybackRate(0.1) == 0.5, "low playback rates are clamped")
expect(AudioManager.normalizedPlaybackRate(1.4) == 1.4, "valid playback rates are preserved")
expect(AudioManager.normalizedPlaybackRate(3.0) == 2.0, "high playback rates are clamped")

expect(!ReadingState.idle.acceptsPauseRequest, "idle is not pausable")
expect(ReadingState.capturing.acceptsPauseRequest, "capturing is pausable")
expect(ReadingState.recognizing.acceptsPauseRequest, "recognizing is pausable")
expect(ReadingState.synthesizing.acceptsPauseRequest, "synthesizing is pausable")
expect(ReadingState.playing.acceptsPauseRequest, "playing is pausable")
expect(ReadingState.turningPage.acceptsPauseRequest, "turning page is pausable")
expect(!ReadingState.paused.acceptsPauseRequest, "paused is already paused")
expect(!ReadingState.error("failed").acceptsPauseRequest, "error is not pausable")

expect(WeReadAppMatcher.isWeReadAppName("微信读书"), "Chinese WeRead app name is accepted")
expect(WeReadAppMatcher.isWeReadAppName("WeRead"), "English WeRead app name is accepted")
expect(WeReadAppMatcher.isWeReadAppName("Weread"), "case variation is accepted")
expect(!WeReadAppMatcher.isWeReadAppName("WeReadAudiobook"), "this app must not be treated as WeRead")
expect(!WeReadAppMatcher.isWeReadAppName("WeReadAudiobook Helper"), "helper windows must not be treated as WeRead")
expect(!WeReadAppMatcher.isWeReadProcess(named: "WeRead", pid: ProcessInfo.processInfo.processIdentifier), "own process must be excluded")
expect(WeReadAppMatcher.isWeReadProcess(named: "WeRead", pid: ProcessInfo.processInfo.processIdentifier + 1000), "other WeRead process is accepted")

expect(
    ReadingPageFlow.lookaheadOrder == [.playing, .turningPage, .capturing, .recognizing, .synthesizing],
    "page flow must prepare the next page while the current page is playing"
)
expect(ReadingPageFlow.maxEmptyPageRetries == 2, "empty OCR should retry the current page before turning")
expect(TextRecognition.backend == .paddleOCR, "PaddleOCR must be the default OCR backend")
expect(PaddleOCRClient.workerScriptURL.lastPathComponent == "paddle_ocr_worker.py", "PaddleOCR worker script is used")
expect(
    FileManager.default.fileExists(atPath: ProjectPaths.root.appendingPathComponent("Package.swift").path),
    "project root should resolve to the repository directory"
)

let textProcessor = TextProcessor.shared
textProcessor.clearReadHistory()
let correctedQuoteSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "“请把测试结果保存下来。99",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.1),
        confidence: 0.9
    )
])
expect(
    correctedQuoteSegments == ["“请把测试结果保存下来。”"],
    "sentence-ending 99 should be corrected to a closing quote"
)

textProcessor.clearReadHistory()
let numericSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "他在 1999 年离开。",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.1),
        confidence: 0.9
    )
])
expect(numericSegments == ["他在 1999 年离开。"], "normal numbers must be preserved")

textProcessor.clearReadHistory()
let isolatedMarkSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "”",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.02, height: 0.02),
        confidence: 0.6
    )
])
expect(isolatedMarkSegments.isEmpty, "isolated quote artifacts should not be spoken")

textProcessor.clearReadHistory()
let lowConfidenceArtifactSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "o",
        boundingBox: CGRect(x: 0.92, y: 0.81, width: 0.02, height: 0.02),
        confidence: 0.42
    )
])
expect(lowConfidenceArtifactSegments.isEmpty, "low-confidence tiny OCR artifacts should not be spoken")

textProcessor.clearReadHistory()
let highConfidenceLatinSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "AI",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.08, height: 0.05),
        confidence: 0.95
    )
])
expect(highConfidenceLatinSegments == ["AI"], "high-confidence Latin text should be preserved")

textProcessor.clearReadHistory()
let wrappedChineseSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "这是一段测",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.08),
        confidence: 0.95
    ),
    RecognizedTextBlock(
        text: "试文字，用来检查换行合并和标点处",
        boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.08),
        confidence: 0.95
    ),
    RecognizedTextBlock(
        text: "理结果。",
        boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.8, height: 0.08),
        confidence: 0.95
    )
])
expect(
    wrappedChineseSegments == ["这是一段测试文字，用来检查换行合并和标点处理结果。"],
    "Chinese line wraps should not add spoken spaces inside words"
)

textProcessor.clearReadHistory()
let sentenceBreakSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "第一句已经结束。",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.08),
        confidence: 0.95
    ),
    RecognizedTextBlock(
        text: "第二句应该保留自然停顿。",
        boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.08),
        confidence: 0.95
    )
])
expect(
    sentenceBreakSegments == ["第一句已经结束。 第二句应该保留自然停顿。"],
    "sentence-ending line wraps should keep a natural separator"
)

textProcessor.clearReadHistory()
let latinWrapSegments = textProcessor.process(blocks: [
    RecognizedTextBlock(
        text: "OpenAI",
        boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.08),
        confidence: 0.95
    ),
    RecognizedTextBlock(
        text: "Model",
        boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.3, height: 0.08),
        confidence: 0.95
    )
])
expect(latinWrapSegments == ["OpenAI Model"], "Latin line wraps should keep a separating space")

print("checks passed")
