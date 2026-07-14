import Foundation
import Combine

// MARK: - App Settings
// Uses ObservableObject (macOS 12 compatible) instead of @Observable (macOS 14+)

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private let ffmpegPathKey  = "ffmpegPath"
    private let ffprobePathKey = "ffprobePath"

    // Stored backing values so @Published triggers properly
    @Published var ffmpegPath: String {
        didSet { defaults.set(ffmpegPath, forKey: ffmpegPathKey) }
    }
    @Published var ffprobePath: String {
        didSet { defaults.set(ffprobePath, forKey: ffprobePathKey) }
    }

    private init() {
        ffmpegPath  = defaults.string(forKey: ffmpegPathKey)  ?? ""
        ffprobePath = defaults.string(forKey: ffprobePathKey) ?? ""
    }

    var isConfigured: Bool {
        !ffmpegPath.isEmpty && FileManager.default.fileExists(atPath: ffmpegPath)
    }

    var ffmpegVersion: String? {
        guard isConfigured else { return nil }
        return try? runSynchronously(path: ffmpegPath, args: ["-version"])
            .components(separatedBy: "\n").first?
            .replacingOccurrences(of: "ffmpeg version ", with: "")
            .components(separatedBy: " ").first
    }

    // MARK: - Auto-detect ffprobe

    func autoDetectFFprobe() {
        guard !ffmpegPath.isEmpty else { return }
        let dir      = (ffmpegPath as NSString).deletingLastPathComponent
        let probePath = (dir as NSString).appendingPathComponent("ffprobe")
        if FileManager.default.fileExists(atPath: probePath) {
            ffprobePath = probePath
        }
    }

    // MARK: - Helpers

    private func runSynchronously(path: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
