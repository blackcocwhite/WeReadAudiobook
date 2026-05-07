import Foundation

enum ProjectPaths {
    static let root: URL = {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment

        if let override = environment["WEREAD_AUDIOBOOK_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        if fileManager.fileExists(atPath: currentDirectory.appendingPathComponent("Package.swift").path) {
            return currentDirectory
        }

        if let executableURL = Bundle.main.executableURL?.resolvingSymlinksInPath(),
           let buildIndex = executableURL.pathComponents.firstIndex(of: ".build") {
            let rootComponents = executableURL.pathComponents.prefix(buildIndex)
            let rootPath = NSString.path(withComponents: Array(rootComponents))
            return URL(fileURLWithPath: rootPath, isDirectory: true)
        }

        return currentDirectory
    }()
}
