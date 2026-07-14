import SwiftUI
import UserNotifications

@main
struct Airpods_Movie_SpatializerApp: App {

    init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
        }
    }
}
