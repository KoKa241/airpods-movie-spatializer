import Foundation

// MARK: - Media Stream

struct MediaStream: Identifiable {
    let id: Int
    let codecType: StreamType
    let codecName: String
    let codecLongName: String

    // Video-specific
    let width: Int?
    let height: Int?
    let frameRate: Double?

    // Audio-specific
    let channels: Int?
    let sampleRate: Int?
    let channelLayout: String?

    // Common
    let bitRate: Int?
    let language: String?
    let title: String?
    let isDefault: Bool

    enum StreamType: String {
        case video
        case audio
        case subtitle
        case data
        case unknown
    }
}

// MARK: - Media Info

struct MediaInfo {
    let url: URL
    let streams: [MediaStream]
    let duration: Double
    let fileSize: Int64
    let formatName: String
    let overallBitRate: Int?

    var videoStreams: [MediaStream] { streams.filter { $0.codecType == .video } }
    var audioStreams: [MediaStream] { streams.filter { $0.codecType == .audio } }
    var subtitleStreams: [MediaStream] { streams.filter { $0.codecType == .subtitle } }

    var primaryVideo: MediaStream? { videoStreams.first }
    var primaryAudio: MediaStream? { audioStreams.first }

    // MARK: - Audio Analysis

    var audioCompatibility: AudioCompatibility {
        guard let audio = primaryAudio else { return .noAudio }
        return AudioCompatibility(codec: audio.codecName, channels: audio.channels ?? 0)
    }

    var isAlreadyMP4: Bool {
        formatName.contains("mp4") || formatName.contains("mov")
    }
}

// MARK: - Audio Compatibility

enum AudioCompatibility {
    case spatialReady        // EAC3 with Atmos or 5.1+
    case surroundCompatible  // AC3 5.1, AAC 5.1/7.1 — triggers Spatial on AirPods
    case stereoOnly          // Stereo — needs upmix for Spatial
    case needsTranscode      // TrueHD, DTS — needs transcode
    case noAudio

    init(codec: String, channels: Int) {
        let codec = codec.lowercased()
        switch codec {
        case "eac3":
            self = channels >= 6 ? .spatialReady : .stereoOnly
        case "ac3":
            self = channels >= 6 ? .surroundCompatible : .stereoOnly
        case "aac":
            self = channels >= 6 ? .surroundCompatible : .stereoOnly
        case "truehd", "dts", "dts-hd", "dts_hd", "dtshd":
            self = .needsTranscode
        default:
            self = channels >= 6 ? .surroundCompatible : .stereoOnly
        }
    }

    var displayName: String {
        switch self {
        case .spatialReady: return "Spatial Audio Ready"
        case .surroundCompatible: return "Surround (Spatial Compatible)"
        case .stereoOnly: return "Stereo"
        case .needsTranscode: return "Needs Transcoding"
        case .noAudio: return "No Audio"
        }
    }

    var systemImage: String {
        switch self {
        case .spatialReady: return "headphones.circle.fill"
        case .surroundCompatible: return "hifispeaker.2.fill"
        case .stereoOnly: return "headphones"
        case .needsTranscode: return "arrow.triangle.2.circlepath"
        case .noAudio: return "speaker.slash.fill"
        }
    }

    var badgeColor: String {
        switch self {
        case .spatialReady: return "spatialReady"
        case .surroundCompatible: return "surroundCompatible"
        case .stereoOnly: return "stereoOnly"
        case .needsTranscode: return "needsTranscode"
        case .noAudio: return "noAudio"
        }
    }
}

// MARK: - FFprobe JSON Parsing

struct FFprobeOutput: Codable {
    let streams: [FFprobeStream]
    let format: FFprobeFormat
}

struct FFprobeStream: Codable {
    let index: Int
    let codecName: String?
    let codecLongName: String?
    let codecType: String?
    let width: Int?
    let height: Int?
    let rFrameRate: String?
    let sampleRate: String?
    let channels: Int?
    let channelLayout: String?
    let bitRate: String?
    let disposition: FFprobeDisposition?
    let tags: FFprobeTags?

    enum CodingKeys: String, CodingKey {
        case index
        case codecName = "codec_name"
        case codecLongName = "codec_long_name"
        case codecType = "codec_type"
        case width, height
        case rFrameRate = "r_frame_rate"
        case sampleRate = "sample_rate"
        case channels
        case channelLayout = "channel_layout"
        case bitRate = "bit_rate"
        case disposition, tags
    }
}

struct FFprobeDisposition: Codable {
    let `default`: Int?
}

struct FFprobeTags: Codable {
    let language: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case language = "LANGUAGE"
        case title = "TITLE"
    }
}

struct FFprobeFormat: Codable {
    let filename: String?
    let formatName: String?
    let duration: String?
    let size: String?
    let bitRate: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case formatName = "format_name"
        case duration, size
        case bitRate = "bit_rate"
    }
}

// MARK: - FFprobeOutput → MediaInfo conversion

extension MediaInfo {
    init(url: URL, ffprobeOutput: FFprobeOutput) {
        self.url = url
        self.formatName = ffprobeOutput.format.formatName ?? ""
        self.duration = Double(ffprobeOutput.format.duration ?? "0") ?? 0
        self.fileSize = Int64(ffprobeOutput.format.size ?? "0") ?? 0
        self.overallBitRate = Int(ffprobeOutput.format.bitRate ?? "0")

        self.streams = ffprobeOutput.streams.map { s in
            let fps: Double?
            if let rFPS = s.rFrameRate, rFPS.contains("/") {
                let parts = rFPS.split(separator: "/").compactMap { Double($0) }
                fps = parts.count == 2 && parts[1] != 0 ? parts[0] / parts[1] : nil
            } else {
                fps = nil
            }

            return MediaStream(
                id: s.index,
                codecType: MediaStream.StreamType(rawValue: s.codecType ?? "unknown") ?? .unknown,
                codecName: s.codecName ?? "unknown",
                codecLongName: s.codecLongName ?? "",
                width: s.width,
                height: s.height,
                frameRate: fps,
                channels: s.channels,
                sampleRate: Int(s.sampleRate ?? "0"),
                channelLayout: s.channelLayout,
                bitRate: Int(s.bitRate ?? "0"),
                language: s.tags?.language,
                title: s.tags?.title,
                isDefault: s.disposition?.default == 1
            )
        }
    }
}
