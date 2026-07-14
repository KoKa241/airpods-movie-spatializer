import SwiftUI
import UserNotifications

@main
struct Airpods_Movie_SpatializerApp: App {
    @StateObject private var settings = AppSettings.shared

    init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, settings.appLanguage == "system" ? .current : Locale(identifier: settings.appLanguage))
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environment(\.locale, settings.appLanguage == "system" ? .current : Locale(identifier: settings.appLanguage))
        }
    }
}
