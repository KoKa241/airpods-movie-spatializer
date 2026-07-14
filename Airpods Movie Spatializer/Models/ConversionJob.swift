import Foundation

// MARK: - Conversion Job

struct ConversionJob {
    let inputURL: URL
    let selectedAudioStreamIndex: Int   // Index in MediaInfo.audioStreams
    let forceSpatialUpmix: Bool         // Upmix stereo → 5.1 via surround filter

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
            return "Audio stream копируется без перекодировки. Максимальное качество."
        case .toEAC3:
            return "Перекодировка в Dolby Digital Plus. Поддерживает Spatial Audio на AirPods."
        case .toAC3:
            return "Перекодировка в Dolby Digital 5.1. Совместим со Spatial Audio."
        case .toAACStereo:
            return "Перекодировка в стерео AAC. Spatial Audio недоступен."
        case .spatialUpmix:
            return "Стерео upmix → 5.1 через FFmpeg surround filter. Включает Spatial Audio на AirPods."
        }
    }
}

// MARK: - Recommended Conversion Strategy

struct ConversionStrategy {
    let audioMode: AudioConversionMode
    let canForceSpatial: Bool
    let explanation: String

    static func recommend(for info: MediaInfo, audioStreamIndex: Int) -> ConversionStrategy {
        let audioStreams = info.audioStreams
        guard audioStreamIndex < audioStreams.count else {
            return ConversionStrategy(
                audioMode: .copy,
                canForceSpatial: false,
                explanation: "Аудио поток не найден — только видео будет скопировано."
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
                    explanation: "E-AC3 (Dolby Digital+) уже поддерживает Spatial Audio — выполняется remux без перекодировки."
                )
            } else {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: true,
                    explanation: "E-AC3 стерео — можно включить Force Spatial Upmix для 5.1."
                )
            }

        case "ac3":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: false,
                    explanation: "AC3 5.1 совместим со Spatial Audio — выполняется remux без перекодировки."
                )
            } else {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: true,
                    explanation: "AC3 стерео — можно включить Force Spatial Upmix для 5.1."
                )
            }

        case "aac":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: false,
                    explanation: "AAC многоканальный совместим со Spatial Audio — выполняется remux."
                )
            } else {
                return ConversionStrategy(
                    audioMode: .copy,
                    canForceSpatial: true,
                    explanation: "AAC стерео — можно включить Force Spatial Upmix для активации Spatial Audio."
                )
            }

        case "truehd":
            return ConversionStrategy(
                audioMode: .toEAC3,
                canForceSpatial: false,
                explanation: "TrueHD не поддерживается в MP4. Будет перекодирован в E-AC3 (Dolby Digital+) с сохранением качества 5.1/7.1."
            )

        case "dts", "dts-hd", "dts_hd", "dtshd":
            return ConversionStrategy(
                audioMode: .toEAC3,
                canForceSpatial: false,
                explanation: "DTS не поддерживается в MP4. Будет перекодирован в E-AC3 для совместимости со Spatial Audio."
            )

        case "mp3", "mp2", "flac", "vorbis", "opus", "pcm_s16le", "pcm_s24le":
            if channels >= 6 {
                return ConversionStrategy(
                    audioMode: .toEAC3,
                    canForceSpatial: false,
                    explanation: "Многоканальный \(codec.uppercased()) будет перекодирован в E-AC3 для Spatial Audio."
                )
            } else {
                return ConversionStrategy(
                    audioMode: .toAACStereo,
                    canForceSpatial: true,
                    explanation: "\(codec.uppercased()) стерео — можно включить Force Spatial Upmix или оставить стерео AAC."
                )
            }

        default:
            return ConversionStrategy(
                audioMode: channels >= 6 ? .toEAC3 : .toAACStereo,
                canForceSpatial: channels < 6,
                explanation: "Неизвестный кодек \(codec) будет перекодирован для максимальной совместимости."
            )
        }
    }
}
