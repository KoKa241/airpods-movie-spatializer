import SwiftUI

// MARK: - Conversion Settings View

struct ConversionSettingsView: View {
    let mediaInfo: MediaInfo
    @Binding var audioJobs: [AudioStreamJob]
    @Binding var showCommandPreview: Bool
    let onConvert: () -> Void

    private var job: ConversionJob {
        ConversionJob(inputURL: mediaInfo.url, audioJobs: audioJobs)
    }

    private var enabledCount: Int { audioJobs.filter(\.isEnabled).count }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Conversion Settings", icon: "slider.horizontal.3")

                Divider().opacity(0.3)

                // Audio tracks header
                HStack {
                    Image(systemName: "music.note.list")
                        .font(.caption)
                        .foregroundColor(.accent1)
                    Text("Audio Tracks")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(enabledCount) / \(audioJobs.count) included")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                // Track list — compact
                VStack(spacing: 4) {
                    ForEach(0..<audioJobs.count, id: \.self) { i in
                        CompactAudioTrackRow(
                            stream: mediaInfo.audioStreams[audioJobs[i].index],
                            trackNumber: i + 1,
                            audioJob: $audioJobs[i],
                            isOnlyTrack: audioJobs.count == 1,
                            onMakePrimary: { makePrimary(index: i) }
                        )
                    }
                }

                Divider().opacity(0.3)

                // Output path preview
                outputPathRow

                Divider().opacity(0.3)

                // Command preview
                commandPreviewSection

                // Convert button
                GradientButton(
                    title: "Convert to Spatial Audio",
                    icon: "sparkles",
                    action: onConvert,
                    isDisabled: !audioJobs.contains(where: \.isEnabled)
                )
            }
        }
    }

    // MARK: - Actions

    private func makePrimary(index: Int) {
        withAnimation(.spring(response: 0.3)) {
            let wasSingleTrack = enabledCount <= 1
            for i in 0..<audioJobs.count {
                if i == index {
                    audioJobs[i].isDefault = true
                    audioJobs[i].isEnabled = true
                } else {
                    audioJobs[i].isDefault = false
                    if wasSingleTrack {
                        audioJobs[i].isEnabled = false
                    }
                }
            }
        }
    }

    // MARK: - Output Path Row

    private var outputPathRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.accent2.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.accent2)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Output File")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                Text(job.outputURL.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accent2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
    }

    // MARK: - Command Preview Section

    private var commandPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showCommandPreview.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.textSecondary.opacity(0.6))
                        .rotationEffect(.degrees(showCommandPreview ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: showCommandPreview)
                    Text("FFmpeg Command Preview")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Image(systemName: "terminal.fill")
                        .font(.caption)
                        .foregroundColor(.textSecondary.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            if showCommandPreview {
                let command = FFmpegManager.shared.buildCommandPreview(for: job, mediaInfo: mediaInfo)
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Text(command)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: 140)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                        removal: .opacity
                    )
                )
            }
        }
    }
}

// MARK: - Compact Audio Track Row

struct CompactAudioTrackRow: View {
    let stream: MediaStream
    let trackNumber: Int
    @Binding var audioJob: AudioStreamJob
    let isOnlyTrack: Bool
    let onMakePrimary: () -> Void

    private var isDeleted: Bool { !audioJob.isEnabled }
    private var canSpatialize: Bool { audioJob.strategy.canForceSpatial }

    var body: some View {
        HStack(spacing: 10) {

            // ── Left: Radio button for Primary track selection ───────
            Button(action: onMakePrimary) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            audioJob.isDefault
                                ? Color.accent1
                                : Color.white.opacity(0.25),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)
                    
                    if audioJob.isDefault {
                        Circle()
                            .fill(Color.accent1)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(audioJob.isDefault ? "Primary Track (Default)" : "Set as Primary Track")

            // ── Flag / Codec Badge ──────────────────────────────────
            ZStack {
                Circle()
                    .fill(isDeleted
                          ? Color.white.opacity(0.04)
                          : (audioJob.isDefault ? Color.accent1.opacity(0.2) : Color.white.opacity(0.07)))
                    .frame(width: 28, height: 28)
                Text(languageEmoji)
                    .font(.system(size: 14))
            }
            .animation(.spring(response: 0.25), value: audioJob.isDefault)
            .animation(.spring(response: 0.25), value: isDeleted)

            // ── Center: Track info ────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                // Row 1: Track N  +  language badge  +  PRIMARY badge
                HStack(spacing: 5) {
                    Text("Track \(trackNumber)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDeleted ? .textSecondary.opacity(0.35) : .textPrimary)

                    // Language pill — always visible
                    HStack(spacing: 3) {
                        Text(languageEmoji)
                            .font(.system(size: 10))
                        Text(languageDisplayName ?? "Unknown")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(isDeleted ? .textSecondary.opacity(0.3) : .textSecondary.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isDeleted
                            ? Color.white.opacity(0.03)
                            : Color.white.opacity(0.08),
                        in: Capsule()
                    )

                    // PRIMARY badge
                    if audioJob.isDefault {
                        Text("PRIMARY")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.accent1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.accent1.opacity(0.15), in: Capsule())
                    }

                    // ATMOS badge
                    if stream.isAtmos {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 7, weight: .bold))
                            Text("ATMOS")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.cyan.opacity(0.18), in: Capsule())
                    }
                }

                // Row 2: codec · channels · bitrate [· title]
                HStack(spacing: 4) {
                    Text(codecLabel)
                        .font(.system(size: 10))
                        .foregroundColor(isDeleted ? .textSecondary.opacity(0.25) : .textSecondary.opacity(0.55))

                    if let title = stream.title, !title.isEmpty {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.textSecondary.opacity(0.3))
                        Text("\"\(title)\"")
                            .font(.system(size: 10))
                            .foregroundColor(isDeleted ? .textSecondary.opacity(0.2) : .textSecondary.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onMakePrimary()
            }

            Spacer()

            // ── Right: Controls ───────────────────────────────────────
            HStack(spacing: 6) {

                if !isDeleted {
                    // Spatializer toggle — interactive when track supports it
                    if canSpatialize {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                audioJob.useSpatializer.toggle()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: audioJob.useSpatializer ? "sparkles" : "sparkle")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(audioJob.useSpatializer ? "Spatial ON" : "Spatial OFF")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(audioJob.useSpatializer ? .accent1 : .textSecondary.opacity(0.45))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                audioJob.useSpatializer
                                    ? Color.accent1.opacity(0.14)
                                    : Color.white.opacity(0.05),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    audioJob.useSpatializer
                                        ? Color.accent1.opacity(0.4)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 0.5
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: audioJob.useSpatializer)
                        .help(audioJob.useSpatializer
                              ? "Spatial Upmix is ON — stereo will be upmixed to 5.1 surround for AirPods Spatial Audio"
                              : "Spatial Upmix is OFF — stream will be processed normally")
                    } else {
                        // Non-interactive mode info pill
                        HStack(spacing: 3) {
                            Image(systemName: modeBadgeIcon(audioJob.strategy.audioMode))
                                .font(.system(size: 9))
                            Text(modeBadgeLabel(audioJob.strategy.audioMode))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.accent2.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.accent2.opacity(0.08), in: Capsule())
                        .help(audioJob.strategy.explanation)
                    }

                    // Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 14)
                }

                // Enable / Exclude toggle button
                if !isOnlyTrack {
                    if isDeleted {
                        TrackActionButton(
                            icon: "plus.circle.fill",
                            label: "Include",
                            color: .green,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    audioJob.isEnabled = true
                                }
                            }
                        )
                    } else {
                        TrackActionButton(
                            icon: "xmark.circle.fill",
                            label: "Exclude",
                            color: .secondary,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    audioJob.isEnabled = false
                                    if audioJob.isDefault {
                                        audioJob.isDefault = false
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    isDeleted
                        ? Color.white.opacity(0.02)
                        : (audioJob.isDefault
                           ? Color.accent1.opacity(0.06)
                           : Color.white.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isDeleted
                        ? Color.white.opacity(0.04)
                        : (audioJob.isDefault
                           ? Color.accent1.opacity(0.25)
                           : Color.white.opacity(0.07)),
                    lineWidth: 0.5
                )
        )
        .animation(.spring(response: 0.3), value: audioJob.isEnabled)
        .animation(.spring(response: 0.3), value: audioJob.isDefault)
        .opacity(isDeleted ? 0.5 : 1.0)
    }

    // MARK: - Helpers


    /// Full human-readable language name from ISO 639-2 code
    private var languageDisplayName: String? {
        guard let code = stream.language?.lowercased(), !code.isEmpty, code != "und" else { return nil }
        // Common ISO 639-2 codes
        switch code {
        case "eng", "en": return "English"
        case "rus", "ru": return "Russian"
        case "ukr", "uk": return "Ukrainian"
        case "deu", "ger", "de": return "German"
        case "fra", "fre", "fr": return "French"
        case "spa", "es": return "Spanish"
        case "ita", "it": return "Italian"
        case "jpn", "ja": return "Japanese"
        case "zho", "chi", "zh": return "Chinese"
        case "kor", "ko": return "Korean"
        case "pol", "pl": return "Polish"
        case "por", "pt": return "Portuguese"
        case "ara", "ar": return "Arabic"
        case "tur", "tr": return "Turkish"
        case "nld", "dut", "nl": return "Dutch"
        case "swe", "sv": return "Swedish"
        case "nor", "nb", "no": return "Norwegian"
        case "dan", "da": return "Danish"
        case "fin", "fi": return "Finnish"
        case "ces", "cze", "cs": return "Czech"
        case "hun", "hu": return "Hungarian"
        case "ron", "rum", "ro": return "Romanian"
        case "hin", "hi": return "Hindi"
        case "heb", "he": return "Hebrew"
        case "vie", "vi": return "Vietnamese"
        case "tha", "th": return "Thai"
        case "ind", "id": return "Indonesian"
        case "msa", "may", "ms": return "Malay"
        case "cat", "ca": return "Catalan"
        case "hrv", "hr": return "Croatian"
        case "srp", "sr": return "Serbian"
        case "slk", "slo", "sk": return "Slovak"
        case "bul", "bg": return "Bulgarian"
        case "ell", "gre", "el": return "Greek"
        default: return code.uppercased()  // fallback to uppercase code
        }
    }

    /// Flag emoji for common languages
    private var languageEmoji: String {
        guard let code = stream.language?.lowercased(), !code.isEmpty, code != "und" else {
            return "🎵"
        }
        switch code {
        case "eng", "en": return "🇬🇧"
        case "rus", "ru": return "🇷🇺"
        case "ukr", "uk": return "🇺🇦"
        case "deu", "ger", "de": return "🇩🇪"
        case "fra", "fre", "fr": return "🇫🇷"
        case "spa", "es": return "🇪🇸"
        case "ita", "it": return "🇮🇹"
        case "jpn", "ja": return "🇯🇵"
        case "zho", "chi", "zh": return "🇨🇳"
        case "kor", "ko": return "🇰🇷"
        case "pol", "pl": return "🇵🇱"
        case "por", "pt": return "🇵🇹"
        case "ara", "ar": return "🇸🇦"
        case "tur", "tr": return "🇹🇷"
        case "nld", "dut", "nl": return "🇳🇱"
        case "swe", "sv": return "🇸🇪"
        case "nor", "nb", "no": return "🇳🇴"
        case "dan", "da": return "🇩🇰"
        case "fin", "fi": return "🇫🇮"
        case "ces", "cze", "cs": return "🇨🇿"
        case "hun", "hu": return "🇭🇺"
        case "ron", "rum", "ro": return "🇷🇴"
        case "hin", "hi": return "🇮🇳"
        case "heb", "he": return "🇮🇱"
        case "vie", "vi": return "🇻🇳"
        case "tha", "th": return "🇹🇭"
        case "ind", "id": return "🇮🇩"
        case "msa", "may", "ms": return "🇲🇾"
        case "cat", "ca": return "🏳️"
        case "hrv", "hr": return "🇭🇷"
        case "srp", "sr": return "🇷🇸"
        case "slk", "slo", "sk": return "🇸🇰"
        case "bul", "bg": return "🇧🇬"
        case "ell", "gre", "el": return "🇬🇷"
        default: return "🎵"
        }
    }

    private var codecLabel: String {
        var parts: [String] = [stream.codecName.uppercased()]
        if let ch = stream.channels { parts.append(channelName(ch)) }
        if let br = stream.bitRate, br > 0 { parts.append("\(br / 1000) kbps") }
        return parts.joined(separator: " · ")
    }

    private func channelName(_ n: Int) -> String {
        switch n {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(n)ch"
        }
    }

    private func modeBadgeLabel(_ mode: AudioConversionMode) -> String {
        switch mode {
        case .copy:         return "Copy as-is"
        case .toEAC3:       return "→ E-AC3"
        case .toAC3:        return "→ AC3"
        case .toAACStereo:  return "→ AAC"
        case .spatialUpmix: return "⬆ Spatial"
        }
    }

    private func modeBadgeIcon(_ mode: AudioConversionMode) -> String {
        switch mode {
        case .copy:         return "doc.on.doc"
        case .toEAC3, .toAC3: return "waveform"
        case .toAACStereo:  return "headphones"
        case .spatialUpmix: return "sparkles"
        }
    }
}

// MARK: - Track Action Button

struct TrackActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                if isHovered {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }
            }
            .foregroundColor(isHovered ? color : color.opacity(0.45))
            .padding(.horizontal, isHovered ? 7 : 5)
            .padding(.vertical, 4)
            .background(
                isHovered ? color.opacity(0.15) : color.opacity(0.05),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isHovered ? color.opacity(0.4) : color.opacity(0.1),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
    }
}
