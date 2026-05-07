import AppKit
import Foundation
@testable import WeReadAudiobook

func fail(_ message: String) -> Never {
    fputs("ocr smoke failed: \(message)\n", stderr)
    exit(1)
}

let image = NSImage(size: NSSize(width: 1440, height: 360))
image.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1440, height: 360).fill()

let font = NSFont.systemFont(ofSize: 72, weight: .regular)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black,
]

"这是微信读书第一页文字".draw(at: NSPoint(x: 80, y: 205), withAttributes: attributes)
"PaddleOCR 本地识别测试".draw(at: NSPoint(x: 80, y: 85), withAttributes: attributes)
image.unlockFocus()

do {
    let blocks = try PaddleOCRClient.shared.recognize(image: image)
    let text = blocks.map(\.text).joined()

    guard text.contains("微信读书") else {
        fail("missing 微信读书 in recognized text: \(text)")
    }

    guard text.contains("PaddleOCR") else {
        fail("missing PaddleOCR in recognized text: \(text)")
    }

    print("ocr smoke passed")
} catch {
    fail(error.localizedDescription)
}
