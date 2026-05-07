import CoreGraphics
import Foundation
import AppKit

enum ScreenCaptureError: LocalizedError {
    case windowNotFound
    case captureFailed
    case screenRecordingPermissionDenied

    var errorDescription: String? {
        switch self {
        case .windowNotFound:
            return "未找到微信读书窗口，请确认微信读书已打开"
        case .captureFailed:
            return "截屏失败，请检查屏幕录制权限"
        case .screenRecordingPermissionDenied:
            return "缺少屏幕录制权限，请在系统设置中授权"
        }
    }
}

final class ScreenCapture {
    static let shared = ScreenCapture()
    private static let topCropRatio: CGFloat = 0.07
    private static let bottomPagerCropRatio: CGFloat = 0.025

    private init() {}

    func findWeReadWindow() -> CGWindowID? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            let ownerPID = WeReadAppMatcher.processIdentifier(from: window[kCGWindowOwnerPID as String])

            if WeReadAppMatcher.isWeReadProcess(named: ownerName, pid: ownerPID) {
                let layer = window[kCGWindowLayer as String] as? Int ?? 0
                if layer == 0 {
                    return windowID
                }
            }
        }

        // Fallback: return any matching window regardless of layer
        for window in windowList {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            let ownerPID = WeReadAppMatcher.processIdentifier(from: window[kCGWindowOwnerPID as String])

            if WeReadAppMatcher.isWeReadProcess(named: ownerName, pid: ownerPID) {
                return windowID
            }
        }

        return nil
    }

    func captureWeReadWindow() throws -> NSImage {
        guard let windowID = findWeReadWindow() else {
            throw ScreenCaptureError.windowNotFound
        }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw ScreenCaptureError.captureFailed
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropRect = Self.contentCropRect(forImageWidth: width, height: height)

        guard let croppedImage = cgImage.cropping(to: cropRect) else {
            // Fallback: return uncropped
            let size = NSSize(width: width / 2.0, height: height / 2.0)
            return NSImage(cgImage: cgImage, size: size)
        }

        let size = NSSize(
            width: CGFloat(croppedImage.width) / 2.0,
            height: CGFloat(croppedImage.height) / 2.0
        )
        return NSImage(cgImage: croppedImage, size: size)
    }

    static func contentCropRect(forImageWidth width: CGFloat, height: CGFloat) -> CGRect {
        let topInset = floor(height * topCropRatio)
        let bottomInset = ceil(height * bottomPagerCropRatio)
        let contentHeight = max(1, height - topInset - bottomInset)

        return CGRect(
            x: 0,
            y: topInset,
            width: width,
            height: contentHeight
        )
    }

    func checkScreenRecordingPermission() -> Bool {
        // CGWindowListCreateImage with .optionIncludingWindow requires screen recording permission
        // This is a lightweight check
        let testImage = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenAboveWindow,
            kCGNullWindowID,
            [.boundsIgnoreFraming]
        )
        return testImage != nil
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
