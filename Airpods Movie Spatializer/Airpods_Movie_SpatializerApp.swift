import SwiftUI
import AppKit

@main
struct Airpods_Movie_SpatializerApp: App {
    @StateObject private var settings = AppSettings.shared


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, settings.appLanguage == "system" ? .current : Locale(identifier: settings.appLanguage))
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("About AirPods Movie Spatializer") {
                    openAboutPanel()
                }
            }
        }

        Settings {
            SettingsView()
                .environment(\.locale, settings.appLanguage == "system" ? .current : Locale(identifier: settings.appLanguage))
        }
    }

    private func openAboutPanel() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 8
        style.lineSpacing = 4

        let credits = NSMutableAttributedString()
        
        let devPrefix = NSAttributedString(
            string: "Developed by ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: style
            ]
        )
        credits.append(devPrefix)
        
        if let url = URL(string: "https://github.com/KoKa241") {
            let devLink = NSAttributedString(
                string: "KoKa241",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 11),
                    .link: url,
                    .foregroundColor: NSColor.linkColor,
                    .paragraphStyle: style
                ]
            )
            credits.append(devLink)
        }
        
        if let mailURL = URL(string: "mailto:vlad74985@gmail.com") {
            let emailStr = NSAttributedString(
                string: "\n\nContact: vlad74985@gmail.com",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .link: mailURL,
                    .foregroundColor: NSColor.linkColor,
                    .paragraphStyle: style
                ]
            )
            credits.append(emailStr)
        }

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "AirPods Movie Spatializer"
        ])
    }
}
