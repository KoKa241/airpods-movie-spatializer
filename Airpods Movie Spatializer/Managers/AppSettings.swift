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

    // Common locations where ffmpeg is usually installed
    static let commonFFmpegPaths = [
        "/opt/homebrew/bin/ffmpeg",      // Apple Silicon Homebrew
        "/usr/local/bin/ffmpeg",          // Intel Homebrew / manual install
        "/usr/bin/ffmpeg",                // System
        "/opt/local/bin/ffmpeg",          // MacPorts
    ]

    @Published var ffmpegPath: String {
        didSet { defaults.set(ffmpegPath, forKey: ffmpegPathKey) }
    }
    @Published var ffprobePath: String {
        didSet { defaults.set(ffprobePath, forKey: ffprobePathKey) }
    }

    private init() {
        ffmpegPath  = defaults.string(forKey: ffmpegPathKey)  ?? ""
        ffprobePath = defaults.string(forKey: ffprobePathKey) ?? ""

        // On first launch, try to auto-detect from common locations
        if ffmpegPath.isEmpty {
            autoDetectFFmpeg()
        }
    }

    // MARK: - Validation

    var isConfigured: Bool {
        !ffmpegPath.isEmpty && isExecutable(at: ffmpegPath)
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

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
