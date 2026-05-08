import AppKit
import Foundation

struct RecognizedTextBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

enum OCRError: LocalizedError {
    case imageConversionFailed
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "图片转换失败"
        case .recognitionFailed(let msg):
            return "文字识别失败: \(msg)"
        }
    }
}

final class TextRecognition: @unchecked Sendable {
    static let shared = TextRecognition()
    static let backend: OCRBackend = .paddleOCR

    private init() {}

    func recognizeText(from image: NSImage) throws -> [RecognizedTextBlock] {
        try PaddleOCRClient.shared.recognize(image: image)
    }

    /// Sort text blocks by reading order: top-to-bottom, then left-to-right within each line
    static func sortByReadingOrder(_ blocks: [RecognizedTextBlock]) -> [RecognizedTextBlock] {
        guard !blocks.isEmpty else { return [] }

        // Group blocks into approximate rows based on vertical position
        let lineHeightThreshold: CGFloat = 0.02 // normalized coordinates
        let sorted = blocks.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

        // Group into rows
        var rows: [[RecognizedTextBlock]] = []
        var currentRow: [RecognizedTextBlock] = [sorted[0]]

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]

            if abs(prev.boundingBox.origin.y - curr.boundingBox.origin.y) < lineHeightThreshold {
                currentRow.append(curr)
            } else {
                rows.append(currentRow)
                currentRow = [curr]
            }
        }
        rows.append(currentRow)

        // Sort each row left-to-right
        return rows.flatMap { row in
            row.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
        }
    }

    /// Concatenate blocks into a single string, joining adjacent blocks on the same line
    func concatenateText(from blocks: [RecognizedTextBlock]) -> String {
        guard !blocks.isEmpty else { return "" }

        var result = ""
        var lastY: CGFloat = -1
        let lineHeightThreshold: CGFloat = 0.02

        for block in blocks {
            if lastY >= 0 && abs(block.boundingBox.origin.y - lastY) > lineHeightThreshold {
                result += "\n"
            } else if !result.isEmpty && !result.hasSuffix("\n") {
                result += ""
            }
            result += block.text
            lastY = block.boundingBox.origin.y
        }

        return result
    }
}
