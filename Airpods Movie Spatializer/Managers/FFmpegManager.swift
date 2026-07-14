import Foundation
import AppKit

// MARK: - FFmpeg Manager

@Observable
@MainActor
class FFmpegManager {
    static let shared = FFmpegManager()

    // MARK: - State

    var isProbing = false
    var isConverting = false
    var progress: Double = 0        // 0.0 – 1.0
    var logLines: [String] = []
    var currentPhase: String = ""
    var errorMessage: String?

    private var conversionProcess: Process?
    private var duration: Double = 0

    // MARK: - Probe

    func probe(url: URL) async throws -> MediaInfo {
        isProbing = true
        defer { isProbing = false }

        let settings = AppSettings.shared
        let probePath = settings.ffprobePath.isEmpty ? settings.ffmpegPath : settings.ffprobePath

        guard !probePath.isEmpty else {
            throw FFmpegError.ffmpegNotConfigured
        }

        let probeExec = probePath.hasSuffix("ffprobe") ? probePath :
            (probePath as NSString).deletingLastPathComponent + "/ffprobe"

        let execURL: URL
        if FileManager.default.fileExists(atPath: probeExec) {
            execURL = URL(fileURLWithPath: probeExec)
        } else {
            execURL = URL(fileURLWithPath: probePath)
        }

        let args = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_streams",
            "-show_format",
            url.path
        ]

        let output = try await runProcess(executableURL: execURL, arguments: args)

        guard let data = output.data(using: .utf8) else {
            throw FFmpegError.probeFailed("Unable to read ffprobe output")
        }

        let decoder = JSONDecoder()
        let ffprobeOutput = try decoder.decode(FFprobeOutput.self, from: data)
        return MediaInfo(url: url, ffprobeOutput: ffprobeOutput)
    }

    // MARK: - Build Command

    func buildArguments(for job: ConversionJob, mediaInfo: MediaInfo, mode: AudioConversionMode) -> [String] {
        var args = ["-y"]   // overwrite output

        // Input
        args += ["-i", job.inputURL.path]

        // Video: always copy
        args += ["-c:v", "copy"]

        // Map the correct audio stream
        let audioStreamIndex = mediaInfo.audioStreams.indices.contains(job.selectedAudioStreamIndex)
            ? mediaInfo.audioStreams[job.selectedAudioStreamIndex].id
            : 0

        args += ["-map", "0:v:0"]               // first video stream
        args += ["-map", "0:\(audioStreamIndex)"] // selected audio stream

        // Audio codec
        let effectiveMode = job.forceSpatialUpmix ? AudioConversionMode.spatialUpmix : mode

        switch effectiveMode {
        case .copy:
            args += ["-c:a", "copy"]

        case .toEAC3:
            args += ["-c:a", "eac3"]
            args += ["-b:a", "640k"]

        case .toAC3:
            args += ["-c:a", "ac3"]
            args += ["-b:a", "640k"]

        case .toAACStereo:
            args += ["-c:a", "aac"]
            args += ["-b:a", "256k"]
            args += ["-ac", "2"]

        case .spatialUpmix:
            // Upmix stereo → 5.1 using surround filter, then encode to E-AC3
            args += ["-af", "surround"]
            args += ["-c:a", "eac3"]
            args += ["-b:a", "640k"]
        }

        // Copy subtitle streams if present
        if !mediaInfo.subtitleStreams.isEmpty {
            args += ["-c:s", "mov_text"]
        }

        // Ensure moov atom is at the beginning for fast start
        args += ["-movflags", "+faststart"]

        // Output
        args += [job.outputURL.path]

        return args
    }

    func buildCommandPreview(for job: ConversionJob, mediaInfo: MediaInfo, mode: AudioConversionMode) -> String {
        let args = buildArguments(for: job, mediaInfo: mediaInfo, mode: mode)
        let ffmpegPath = AppSettings.shared.ffmpegPath
        return ([ffmpegPath] + args).map { arg in
            arg.contains(" ") ? "\"\(arg)\"" : arg
        }.joined(separator: " \\\n  ")
    }

    // MARK: - Convert

    func convert(job: ConversionJob, mediaInfo: MediaInfo, mode: AudioConversionMode) async throws {
        guard !isConverting else { return }

        isConverting = true
        progress = 0
        logLines = []
        errorMessage = nil
        duration = mediaInfo.duration
        currentPhase = "Preparing..."

        defer { isConverting = false }

        let settings = AppSettings.shared
        guard settings.isConfigured else {
            throw FFmpegError.ffmpegNotConfigured
        }

        let args = buildArguments(for: job, mediaInfo: mediaInfo, mode: mode)
        let execURL = URL(fileURLWithPath: settings.ffmpegPath)

        // Check if output already exists — remove it (we pass -y but just in case)
        if FileManager.default.fileExists(atPath: job.outputURL.path) {
            try? FileManager.default.removeItem(at: job.outputURL)
        }

        currentPhase = "Converting..."
        addLog("→ Starting conversion...")
        addLog("→ Output: \(job.outputURL.lastPathComponent)")

        try await runConversionProcess(executableURL: execURL, arguments: args)
    }

    // MARK: - Cancel

    func cancel() {
        conversionProcess?.terminate()
        conversionProcess = nil
        isConverting = false
        currentPhase = "Cancelled"
        addLog("⚠ Conversion cancelled by user.")
    }

    // MARK: - Private Helpers

    private func addLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 200 {
            logLines.removeFirst(logLines.count - 200)
        }
    }

    private func runProcess(executableURL: URL, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                process.terminationHandler = { p in
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let errOutput = String(data: errData, encoding: .utf8) ?? ""

                    if p.terminationStatus == 0 {
                        continuation.resume(returning: output.isEmpty ? errOutput : output)
                    } else {
                        continuation.resume(throwing: FFmpegError.probeFailed(errOutput))
                    }
                }

                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runConversionProcess(executableURL: URL, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments

                let errPipe = Pipe()
                process.standardOutput = errPipe
                process.standardError = errPipe

                self.conversionProcess = process

                // Read stderr in real time for progress
                errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let self else { return }
                    let text = String(data: data, encoding: .utf8) ?? ""

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        for line in text.components(separatedBy: "\r") {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                self.parseProgressLine(trimmed)
                            }
                        }
                    }
                }

                process.terminationHandler = { [weak self] p in
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.conversionProcess = nil
                        if p.terminationStatus == 0 {
                            self.progress = 1.0
                            self.currentPhase = "Done!"
                            self.addLog("✓ Conversion completed successfully.")
                            continuation.resume()
                        } else if p.terminationReason == .uncaughtSignal {
                            continuation.resume(throwing: FFmpegError.cancelled)
                        } else {
                            let msg = "FFmpeg exited with code \(p.terminationStatus)"
                            self.errorMessage = msg
                            self.addLog("✗ Error: \(msg)")
                            continuation.resume(throwing: FFmpegError.conversionFailed(msg))
                        }
                    }
                }

                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseProgressLine(_ line: String) {
        // Skip lines that are not progress lines
        if line.hasPrefix("frame=") || line.contains("time=") {
            addLog(line)

            // Parse time= to compute progress
            if let timeRange = line.range(of: "time=") {
                let timeStart = line.index(timeRange.upperBound, offsetBy: 0)
                let timeSubstr = String(line[timeStart...])
                if let spaceRange = timeSubstr.firstIndex(of: " ") {
                    let timeStr = String(timeSubstr[..<spaceRange])
                    if let currentTime = parseFFmpegTime(timeStr), duration > 0 {
                        progress = min(1.0, currentTime / duration)
                    }
                }
            }
        } else if line.hasPrefix("video:") || line.hasPrefix("audio:") || line.hasPrefix("Qavg:") {
            addLog(line)
        } else if line.lowercased().contains("error") || line.lowercased().contains("warning") {
            addLog("⚠ \(line)")
        } else if line.hasPrefix("  ") || line.hasPrefix("Stream") || line.hasPrefix("Output") || line.hasPrefix("Input") {
            addLog(line)
        }
    }

    private func parseFFmpegTime(_ timeStr: String) -> Double? {
        // Format: HH:MM:SS.ms
        let parts = timeStr.split(separator: ":").map { String($0) }
        guard parts.count == 3,
              let h = Double(parts[0]),
              let m = Double(parts[1]),
              let s = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}

// MARK: - Errors

enum FFmpegError: LocalizedError {
    case ffmpegNotConfigured
    case probeFailed(String)
    case conversionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .ffmpegNotConfigured:
            return "FFmpeg is not configured. Please set the path to the FFmpeg binary in Settings."
        case .probeFailed(let msg):
            return "Failed to analyze file: \(msg)"
        case .conversionFailed(let msg):
            return "Conversion failed: \(msg)"
        case .cancelled:
            return "Conversion was cancelled."
        }
    }
}
