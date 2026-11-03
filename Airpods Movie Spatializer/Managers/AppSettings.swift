import Foundation
import Combine
import SwiftUI
import AppKit

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - App Settings
// Uses ObservableObject (macOS 12 compatible) instead of @Observable (macOS 14+)

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private let ffmpegPathKey  = "ffmpegPath"
    private let ffprobePathKey = "ffprobePath"
    private let appLanguageKey = "appLanguage"
    private let appThemeKey    = "appTheme"

    // Common locations where ffmpeg is usually installed
    static let commonFFmpegPaths = [
        "/opt/homebrew/bin/ffmpeg",      // Apple Silicon Homebrew
        "/usr/local/bin/ffmpeg",          // Intel Homebrew / manual install
        "/usr/bin/ffmpeg",                // System
        "/opt/local/bin/ffmpeg",          // MacPorts
    ]

    @Published var ffmpegPath: String {
        didSet {
            defaults.set(ffmpegPath, forKey: ffmpegPathKey)
            autoDetectFFprobe()
        }
    }
    @Published var ffprobePath: String {
        didSet { defaults.set(ffprobePath, forKey: ffprobePathKey) }
    }
    @Published var appLanguage: String {
        didSet { defaults.set(appLanguage, forKey: appLanguageKey) }
    }
    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: appThemeKey)
            applyTheme()
        }
    }

    private init() {
        ffmpegPath  = defaults.string(forKey: ffmpegPathKey)  ?? ""
        ffprobePath = defaults.string(forKey: ffprobePathKey) ?? ""
        appLanguage = defaults.string(forKey: appLanguageKey) ?? "system"

        if let savedTheme = defaults.string(forKey: appThemeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            appTheme = theme
        } else {
            appTheme = .system
        }

        // On first launch, try to auto-detect from common locations
        if ffmpegPath.isEmpty {
            autoDetectFFmpeg()
        } else if ffprobePath.isEmpty {
            autoDetectFFprobe()
        }

        applyTheme()
    }

    func applyTheme() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.appTheme {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    // MARK: - Validation

    var isConfigured: Bool {
        !ffmpegPath.isEmpty && isExecutable(at: ffmpegPath)
    }

    var isFFprobeConfigured: Bool {
        !ffprobePath.isEmpty && isExecutable(at: ffprobePath)
    }

    var isFFprobeNextToFFmpeg: Bool {
        guard !ffmpegPath.isEmpty else { return false }
        let dir = (ffmpegPath as NSString).deletingLastPathComponent
        let probePath = (dir as NSString).appendingPathComponent("ffprobe")
        return isExecutable(at: probePath)
    }

    /// Check file exists AND is executable (not just present)
    func isExecutable(at path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return false }
        return fm.isExecutableFile(atPath: path)
    }

    var ffmpegVersion: String? {
        guard isConfigured else { return nil }
        return try? runSynchronously(path: ffmpegPath, args: ["-version"])
            .components(separatedBy: "\n").first?
            .replacingOccurrences(of: "ffmpeg version ", with: "")
            .components(separatedBy: " ").first
    }

    // MARK: - Auto-detect

    /// Search common installation paths for ffmpeg
    func autoDetectFFmpeg() {
        for path in Self.commonFFmpegPaths {
            if isExecutable(at: path) {
                ffmpegPath = path
                autoDetectFFprobe()
                return
            }
        }
    }

    /// Look for ffprobe in the same directory as ffmpeg
    func autoDetectFFprobe() {
        guard !ffmpegPath.isEmpty else { return }
        let dir       = (ffmpegPath as NSString).deletingLastPathComponent
        let probePath = (dir as NSString).appendingPathComponent("ffprobe")
        if isExecutable(at: probePath) {
            ffprobePath = probePath
        }
    }

    // MARK: - Quarantine removal

    /// Remove macOS quarantine flag from a downloaded binary.
    /// Required for binaries downloaded from the internet that aren't code-signed for Gatekeeper.
    @discardableResult
    func removeQuarantine(from path: String) -> Bool {
        // xattr -d com.apple.quarantine <path>
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-d", "com.apple.quarantine", path]
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - Helpers

    private func runSynchronously(path: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        let queue = DispatchQueue(label: "com.ffmpeg.runSync")
        var outputData = Data()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            queue.async {
                outputData.append(data)
            }
        }

        try process.run()
        process.waitUntilExit()

        pipe.fileHandleForReading.readabilityHandler = nil
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        
        queue.sync {
            outputData.append(remaining)
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
