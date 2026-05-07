import SwiftUI

@main
struct WeReadAudiobookApp: App {
    @StateObject private var engine = ReadingEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(engine)
        } label: {
            Label("微信读书朗读", systemImage: "book.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(engine)
        }
    }
}
