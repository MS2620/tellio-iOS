import SwiftUI

@main
struct TellioApp: App {
    @StateObject private var settings = AppSettings()

    init() {
        // As early as possible, so a crash during launch is still caught.
        CrashReporting.apply(enabled: Preferences.load().crashReports)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
