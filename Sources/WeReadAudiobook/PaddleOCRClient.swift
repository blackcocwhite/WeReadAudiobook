import AppKit
import Foundation

enum OCRBackend: Equatable {
    case paddleOCR
}

struct PaddleOCRResponse: Decodable {
    let ok: Bool
    let ready: Bool?
    let imageSize: [Double]?
    let blocks: [PaddleOCRBlock]?
    let error: String?
    let traceback: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case ready
        case imageSize = "image_size"
        case blocks
        case error
        case traceback
    }

    var recognizedImageSize: CGSize? {
        guard let imageSize,
              imageSize.count == 2,
              imageSize[0] > 0,
              imageSize[1] > 0 else {
            return nil
        }

        return CGSize(width: imageSize[0], height: imageSize[1])
    }
}

struct PaddleOCRBlock: Decodable {
    let text: String
    let confidence: Float
    let box: [Double]
}

final class PaddleOCRClient {
    static let shared = PaddleOCRClient()

    static let workerScriptURL = ProjectPaths.root.appendingPathComponent("scripts/paddle_ocr_worker.py")
    static let pythonURL = ProjectPaths.root.appendingPathComponent(".venv-ocr/bin/python")

    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private let lock = NSLock()

    private init() {}

    deinit {
        process?.terminate()
    }

    func recognize(image: NSImage) throws -> [RecognizedTextBlock] {
        let imageURL = try writeTemporaryPNG(image)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let sourceImageSize = try pngPixelSize(at: imageURL)
        let response = try send(imagePath: imageURL.path)

        guard response.ok else {
            throw OCRError.recognitionFailed(response.error ?? "PaddleOCR 识别失败")
        }

        let imageSize = response.recognizedImageSize ?? sourceImageSize
        let blocks = response.blocks ?? []
        return TextRecognition.sortByReadingOrder(
            blocks.compactMap { block in
                recognizedTextBlock(from: block, imageSize: imageSize)
            }
        )
    }

    private func send(imagePath: String) throws -> PaddleOCRResponse {
        lock.lock()
        defer { lock.unlock() }

        try startIfNeeded()

        guard let inputHandle, let outputHandle else {
            throw OCRError.recognitionFailed("PaddleOCR worker 未启动")
        }

        let request = ["image_path": imagePath]
        let data = try JSONSerialization.data(withJSONObject: request)
        inputHandle.write(data)
        inputHandle.write(Data([0x0A]))

        let line = try readLine(from: outputHandle)
        guard let payload = line.data(using: .utf8) else {
            throw OCRError.recognitionFailed("PaddleOCR 返回内容不是 UTF-8")
        }

        do {
            return try JSONDecoder().decode(PaddleOCRResponse.self, from: payload)
        } catch {
            throw OCRError.recognitionFailed("PaddleOCR 返回内容无法解析: \(line)")
        }
    }

    private func startIfNeeded() throws {
        if let process, process.isRunning {
            return
        }

        guard FileManager.default.isExecutableFile(atPath: Self.pythonURL.path) else {
            throw OCRError.recognitionFailed("未找到 PaddleOCR 环境，请先运行 scripts/setup-paddleocr.sh")
        }

        guard FileManager.default.fileExists(atPath: Self.workerScriptURL.path) else {
            throw OCRError.recognitionFailed("未找到 PaddleOCR worker: \(Self.workerScriptURL.path)")
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.executableURL = Self.pythonURL
        process.arguments = [Self.workerScriptURL.path]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.currentDirectoryURL = ProjectPaths.root

        try process.run()

        self.process = process
        self.inputHandle = stdinPipe.fileHandleForWriting
        self.outputHandle = stdoutPipe.fileHandleForReading

        let readyLine = try readLine(from: stdoutPipe.fileHandleForReading)
        guard let readyData = readyLine.data(using: .utf8),
              let response = try? JSONDecoder().decode(PaddleOCRResponse.self, from: readyData),
              response.ok,
              response.ready == true else {
            throw OCRError.recognitionFailed("PaddleOCR worker 启动失败: \(readyLine)")
        }
    }

    private func readLine(from handle: FileHandle) throws -> String {
        var data = Data()

        while true {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                throw OCRError.recognitionFailed("PaddleOCR worker 已退出")
            }
            if byte.first == 0x0A {
                break
            }
            data.append(byte)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func writeTemporaryPNG(_ image: NSImage) throws -> URL {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw OCRError.imageConversionFailed
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "WeReadAudiobookOCR",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func pngPixelSize(at url: URL) throws -> CGSize {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    private func recognizedTextBlock(from block: PaddleOCRBlock, imageSize: CGSize) -> RecognizedTextBlock? {
        guard block.box.count == 4, imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }

        let minX = block.box[0]
        let minY = block.box[1]
        let maxX = block.box[2]
        let maxY = block.box[3]

        let rect = CGRect(
            x: minX / imageSize.width,
            y: 1.0 - (maxY / imageSize.height),
            width: max(0, maxX - minX) / imageSize.width,
            height: max(0, maxY - minY) / imageSize.height
        )

        return RecognizedTextBlock(
            text: block.text,
            boundingBox: rect,
            confidence: block.confidence
        )
    }
}
