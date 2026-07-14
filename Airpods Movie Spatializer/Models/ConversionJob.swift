import Foundation

// MARK: - Audio Stream Job

struct AudioStreamJob: Equatable {
    let index: Int
    var isEnabled: Bool
    var forceSpatialUpmix: Bool
    let strategy: ConversionStrategy
}

// MARK: - Conversion Job

struct ConversionJob {
    let inputURL: URL
    let audioJobs: [AudioStreamJob]

    var outputURL: URL {
        let dir = inputURL.deletingLastPathComponent()
        let stem = inputURL.deletingPathExtension().lastPathComponent
        return dir.appendingPathComponent("\(stem)_spatial.mp4")
    }
}

// MARK: - Audio Conversion Mode

enum AudioConversionMode: String, CaseIterable {
    case copy           = "Copy (lossless)"
    case toEAC3         = "Transcode → E-AC3 (Dolby Digital+)"
    case toAC3          = "Transcode → AC3 (Dolby Digital 5.1)"
    case toAACStereo    = "Transcode → AAC Stereo"
    case spatialUpmix   = "Stereo → 5.1 Spatial Upmix"

    var ffmpegCodecArg: String {
        switch self {
        case .copy:         return "copy"
        case .toEAC3:       return "eac3"
        case .toAC3:        return "ac3"
        case .toAACStereo:  return "aac"
        case .spatialUpmix: return "eac3"
        }
    }

    var description: String {
        switch self {
        case .copy:
            return String(localized: "Audio stream is copied without re-encoding. Maximum quality.")
        case .toEAC3:
            return String(localized: "Transcoded to Dolby Digital Plus. Supports Spatial Audio on AirPods.")
        case .toAC3:
            return String(localized: "Transcoded to Dolby Digital 5.1. Compatible with Spatial Audio.")
        case .toAACStereo:
            return String(localized: "Transcoded to stereo AAC. Spatial Audio is unavailable.")
        case .spatialUpmix:
            return String(localized: "Stereo upmix → 5.1 via FFmpeg surround filter. Enables Spatial Audio on AirPods.")
        }
    }
}

// MARK: - Recommended Conversion Strategy

struct ConversionStrategy: Equatable {
    let audioMode: AudioConversionMode
    let canForceSpatial: Bool
    let explanation: String

    static func recommend(for info: MediaInfo, audioStreamIndex: Int) -> ConversionStrategy {
        let audioStreams = info.audioStreams
        guard audioStreamIndex < audioStreams.count else {
            return ConversionStrategy(
                audioMode: .copy,
                canForceSpatial: false,
                explanation: String(localized: "Audio stream not found — only video will be copied.")
            )
        }

        let stream = audioStreams[audioStreamIndex]
        let codec = stream.codecName.lowercased()
        let channels = stream.channels ?? 0

        switch codec {
        case "eac3":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: false,
                    explanation: String(localized: "E-AC3 (Dolby Digital+) already supports Spatial Audio — remuxing without re-encoding.")
                )
            } else {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: true,
                    explanation: String(localized: "E-AC3 stereo — you can enable Force Spatial Upmix for 5.1.")
                )
            }

        case "ac3":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: false,
                    explanation: String(localized: "AC3 5.1 is compatible with Spatial Audio — remuxing without re-encoding.")
                )
            } else {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: true,
                    explanation: String(localized: "AC3 stereo — you can enable Force Spatial Upmix for 5.1.")
                )
            }

        case "aac":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: false,
                    explanation: String(localized: "Multichannel AAC is compatible with Spatial Audio — remuxing.")
                )
            } else {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: true,
                    explanation: String(localized: "AAC stereo — you can enable Force Spatial Upmix to activate Spatial Audio.")
                )
            }

        case "truehd":
            return ConversionStrategy(
                audioMode: .toEAC3,
                canForceSpatial: false,
                explanation: String(localized: "TrueHD is not supported in MP4. Will be transcoded to E-AC3 (Dolby Digital+) retaining 5.1/7.1 quality.")
            )

        case "dts", "dts-hd", "dts_hd", "dtshd":
            return ConversionStrategy(
                audioMode: .toEAC3,
                canForceSpatial: false,
                explanation: String(localized: "DTS is not supported in MP4. Will be transcoded to E-AC3 for Spatial Audio compatibility.")
            )

        case "mp3", "mp2", "flac", "vorbis", "opus", "pcm_s16le", "pcm_s24le":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .toEAC3,
                    canForceSpatial: false,
                    explanation: String(localized: "Multichannel codec will be transcoded to E-AC3 for Spatial Audio.")
                )
            } else {
                return ConversionStrategy(
                    audioMode: .toAACStereo,
                    canForceSpatial: true,
                    explanation: String(localized: "Stereo codec — you can enable Force Spatial Upmix or keep stereo AAC.")
                )
            }

        default:
            return ConversionStrategy(
                audioMode: channels >= 6 ? .toEAC3 : .toAACStereo,
                canForceSpatial: channels < 6,
                explanation: String(localized: "Unknown codec will be transcoded for maximum compatibility.")
            )
        }
    }
}
