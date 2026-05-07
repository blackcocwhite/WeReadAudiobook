import Foundation

final class TextProcessor {
    static let shared = TextProcessor()

    /// Max characters per TTS request (MiMo TTS typical limit)
    var maxSegmentLength: Int = 500

    /// Store hashes of recently read text to avoid duplicates
    private var readTextHashes: Set<Int> = []
    private let maxHashCount = 100

    private init() {}

    /// Clean OCR output and split into TTS-ready segments
    func process(blocks: [RecognizedTextBlock]) -> [String] {
        let filteredBlocks = blocks.filter { shouldKeep(block: $0) }
        let raw = TextRecognition.shared.concatenateText(from: filteredBlocks)
        let cleaned = cleanText(raw)
        guard !cleaned.isEmpty else { return [] }

        // Check if this text is too similar to recently read content
        if isDuplicate(cleaned) {
            return []
        }

        let segments = splitIntoSegments(cleaned)
        if !segments.isEmpty {
            markAsRead(cleaned)
        }
        return segments
    }

    private func shouldKeep(block: RecognizedTextBlock) -> Bool {
        let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let hasChineseOrDigit = trimmed.range(of: #"[\p{Han}\d]"#, options: .regularExpression) != nil
        let isTinyLowConfidenceFragment = trimmed.count <= 2 && !hasChineseOrDigit && block.confidence < 0.75

        return !isTinyLowConfidenceFragment
    }

    /// Clean raw OCR text
    private func cleanText(_ text: String) -> String {
        var result = text

        // Remove common OCR artifacts
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ") // non-breaking space

        // Remove page numbers (standalone numbers on their own line)
        let lines = result.components(separatedBy: .newlines)
        let cleanedLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: #"^[\p{P}\p{S}]+$"#, options: .regularExpression) != nil {
                return false
            }
            // Skip lines that are just a page number
            if let _ = Int(trimmed) {
                return false
            }
            // Skip lines that look like "第X页" or "- X -"
            if trimmed.range(of: #"^第\s*\d+\s*页$"#, options: .regularExpression) != nil {
                return false
            }
            if trimmed.range(of: #"^[-–—]\s*\d+\s*[-–—]$"#, options: .regularExpression) != nil {
                return false
            }
            // Skip lines like "123/45678" (page number / total pages)
            if trimmed.range(of: #"^\d+/\d+$"#, options: .regularExpression) != nil {
                return false
            }
            // Skip chapter titles like "第一百四十五章 自问" or "第1章 xxx"
            if trimmed.range(of: #"^第[一二三四五六七八九十百千万零\d]+[章节回卷]"#, options: .regularExpression) != nil {
                return false
            }
            // Skip window title
            if trimmed == "微信读书" || trimmed == "WeRead" {
                return false
            }
            return !trimmed.isEmpty
        }

        result = cleanedLines.joined(separator: "\n")

        // Normalize whitespace and remove newlines (causes TTS pauses)
        result = result.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"([。！？!?\.])\s*99(?=$|[\s，。！？!?、“”‘’）】》」』])"#,
            with: "$1”",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Split text into segments suitable for TTS
    private func splitIntoSegments(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        if text.count <= maxSegmentLength {
            return [text]
        }

        // Text already has no newlines, split by sentences
        return splitLongParagraph(text)
    }

    /// Split a long paragraph by sentences
    private func splitLongParagraph(_ text: String) -> [String] {
        // Split on sentence-ending punctuation
        var sentences: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if "。！？.!?".contains(char) {
                sentences.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            sentences.append(current)
        }

        var segments: [String] = []
        var currentSegment = ""

        for sentence in sentences {
            if currentSegment.count + sentence.count > maxSegmentLength {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                currentSegment = sentence
            } else {
                currentSegment += sentence
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }

    /// Check if text is too similar to recently read content
    private func isDuplicate(_ text: String) -> Bool {
        let hash = text.hashValue

        // Check exact hash match
        if readTextHashes.contains(hash) {
            return true
        }

        // Check substring overlap with a sliding window approach
        let windowSize = 50
        if text.count > windowSize {
            let startIndex = text.index(text.startIndex, offsetBy: text.count / 3)
            let endIndex = text.index(startIndex, offsetBy: min(windowSize, text.count - text.count / 3))
            let sample = String(text[startIndex..<endIndex])
            let sampleHash = sample.hashValue
            if readTextHashes.contains(sampleHash) {
                return true
            }
        }

        return false
    }

    /// Mark text as read
    private func markAsRead(_ text: String) {
        readTextHashes.insert(text.hashValue)

        // Also insert a middle sample for substring matching
        let windowSize = 50
        if text.count > windowSize {
            let startIndex = text.index(text.startIndex, offsetBy: text.count / 3)
            let endIndex = text.index(startIndex, offsetBy: min(windowSize, text.count - text.count / 3))
            let sample = String(text[startIndex..<endIndex])
            readTextHashes.insert(sample.hashValue)
        }

        // Trim old hashes
        while readTextHashes.count > maxHashCount {
            if let first = readTextHashes.first {
                readTextHashes.remove(first)
            }
        }
    }

    func clearReadHistory() {
        readTextHashes.removeAll()
    }
}
