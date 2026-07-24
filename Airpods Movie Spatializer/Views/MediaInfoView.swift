import SwiftUI

// MARK: - Media Info View

struct MediaInfoView: View {
    let mediaInfo: MediaInfo

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    SectionHeader(title: "File Info", icon: "info.circle")
                    Spacer()
                    AudioCompatibilityBadge(compatibility: mediaInfo.audioCompatibility)
                }

                Divider().opacity(0.3)

                // File name
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.accent1)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mediaInfo.url.lastPathComponent)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(formattedFileSize(mediaInfo.fileSize) + " · " + formattedDuration(mediaInfo.duration))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }

                // Video & Audio columns
                HStack(alignment: .top, spacing: 12) {
                    // Video
                    if let video = mediaInfo.primaryVideo {
                        StreamCard(title: "Video", icon: "play.rectangle.fill", color: .accent2) {
                            InfoRow(label: "Codec", value: video.codecName.uppercased())
                            if let w = video.width, let h = video.height {
                                InfoRow(label: "Resolution", value: "\(w)×\(h)")
                            }
                            if let fps = video.frameRate {
                                InfoRow(label: "Frame Rate", value: String(format: "%.2f fps", fps))
                            }
                            if let br = video.bitRate, br > 0 {
                                InfoRow(label: "Bitrate", value: formattedBitrate(br))
                            }
                        }
                    }

                    // Audio streams
                    VStack(spacing: 8) {
                        ForEach(mediaInfo.audioStreams) { stream in
                            StreamCard(title: streamTitle(stream), icon: "waveform", color: .accent1) {
                                InfoRow(label: "Codec", value: stream.codecName.uppercased())
                                if let layout = stream.channelLayout, !layout.isEmpty {
                                    InfoRow(label: "Layout", value: layout)
                                }
                                if let sr = stream.sampleRate, sr > 0 {
                                    InfoRow(label: "Sample Rate", value: "\(sr / 1000) kHz")
                                }
                            }
                        }
                    }
                }

                // Subtitle streams notice
                if !mediaInfo.subtitleStreams.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "captions.bubble.fill")
                            .foregroundColor(.textSecondary)
                            .font(.caption)
                        Text("\(mediaInfo.subtitleStreams.count) subtitle track(s) found — will be included as mov_text")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Helpers

    private func streamTitle(_ stream: MediaStream) -> String {
        var parts: [String] = []
        if let lang = stream.language { parts.append(lang.uppercased()) }
        if let title = stream.title { parts.append(title) }
        if stream.isDefault { parts.append("Default") }
        return parts.isEmpty ? "Audio" : parts.joined(separator: " · ")
    }

    private func channelName(_ n: Int) -> String {
        switch n {
        case 1: return "1.0 Mono"
        case 2: return "2.0 Stereo"
        case 6: return "5.1 Surround"
        case 7: return "6.1 Surround"
        case 8: return "7.1 Surround"
        default: return "\(n) channels"
        }
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formattedBitrate(_ bps: Int) -> String {
        if bps >= 1_000_000 {
            return String(format: "%.1f Mbps", Double(bps) / 1_000_000)
        }
        return "\(bps / 1000) kbps"
    }
}

// MARK: - Stream Card

struct StreamCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }
}
