import CoreGraphics
import Foundation
import AppKit
import ApplicationServices

enum PageTurnerError: LocalizedError {
    case accessibilityPermissionDenied
    case eventCreationFailed
    case postEventFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "缺少辅助功能权限，请在系统设置中授权"
        case .eventCreationFailed:
            return "无法创建键盘事件"
        case .postEventFailed:
            return "无法发送键盘事件"
        }
    }
}

final class PageTurner {
    static let shared = PageTurner()

    /// Delay after page turn before the next screenshot (seconds)
    var pageTurnDelay: TimeInterval = 1.0

    private init() {}

    /// Check if the app has accessibility permission
    func checkAccessibilityPermission() -> Bool {
        // AXIsProcessTrusted() checks if the app is trusted for accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Prompt user to grant accessibility permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Simulate pressing the right arrow key to turn page (silent, no window activation)
    func turnPage() async throws {
        guard checkAccessibilityPermission() else {
            throw PageTurnerError.accessibilityPermissionDenied
        }

        guard let pid = findWeReadPID() else {
            throw PageTurnerError.postEventFailed
        }

        // Send right arrow key directly to WeRead's PID (no activate/focus)
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x7C, // kVK_RightArrow
            keyDown: true
        ) else {
            throw PageTurnerError.eventCreationFailed
        }

        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x7C, // kVK_RightArrow
            keyDown: false
        ) else {
            throw PageTurnerError.eventCreationFailed
        }

        keyDownEvent.postToPid(pid)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms between down and up
        keyUpEvent.postToPid(pid)

        // Wait for page to render
        try await Task.sleep(nanoseconds: UInt64(pageTurnDelay * 1_000_000_000))
    }

    /// Simulate pressing space bar to turn page (alternative, silent)
    func turnPageWithSpace() async throws {
        guard checkAccessibilityPermission() else {
            throw PageTurnerError.accessibilityPermissionDenied
        }

        guard let pid = findWeReadPID() else {
            throw PageTurnerError.postEventFailed
        }

        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x31, // kVK_Space
            keyDown: true
        ) else {
            throw PageTurnerError.eventCreationFailed
        }

        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x31, // kVK_Space
            keyDown: false
        ) else {
            throw PageTurnerError.eventCreationFailed
        }

        keyDownEvent.postToPid(pid)
        try await Task.sleep(nanoseconds: 50_000_000)
        keyUpEvent.postToPid(pid)

        try await Task.sleep(nanoseconds: UInt64(pageTurnDelay * 1_000_000_000))
    }

    /// Find WeRead's process ID
    private func findWeReadPID() -> pid_t? {
        let apps = NSWorkspace.shared.runningApplications
        for app in apps {
            if WeReadAppMatcher.isWeReadProcess(
                named: app.localizedName,
                pid: app.processIdentifier
            ) {
                return app.processIdentifier
            }
        }
        return nil
    }
}
