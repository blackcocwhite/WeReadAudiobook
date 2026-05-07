import Foundation

enum WeReadAppMatcher {
    static func isWeReadAppName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if trimmed.contains("微信读书") {
            return true
        }

        return lowercased == "weread"
    }

    static func isWeReadProcess(named name: String?, pid: pid_t?) -> Bool {
        guard let name else { return false }
        if pid == ProcessInfo.processInfo.processIdentifier {
            return false
        }
        return isWeReadAppName(name)
    }

    static func processIdentifier(from value: Any?) -> pid_t? {
        if let pid = value as? pid_t {
            return pid
        }
        if let pid = value as? Int {
            return pid_t(pid)
        }
        if let pid = value as? NSNumber {
            return pid_t(pid.int32Value)
        }
        return nil
    }
}
