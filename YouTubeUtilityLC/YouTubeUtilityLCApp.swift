import SwiftUI

@main
struct YouTubeUtilityLCApp: App {
    @StateObject private var settings = AppSettings()

    init() {
        AudioSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .tint(settings.themeColor)
        }
    }
}
