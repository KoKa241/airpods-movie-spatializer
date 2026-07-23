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
            for i in 0..<audioJobs.count {
                audioJobs[i].isDefault = (i == index)
                if i == index { audioJobs[i].isEnabled = true }
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
    @Binding var audioJob: AudioStreamJob
    let isOnlyTrack: Bool
    let onMakePrimary: () -> Void

    @State private var showSpatializerInfo = false

    private var isDeleted: Bool { !audioJob.isEnabled }
    private var canSpatialize: Bool { audioJob.strategy.canForceSpatial }

    var body: some View {
        HStack(spacing: 8) {

            // ── Track icon + info ─────────────────────────────────────
            HStack(spacing: 8) {
                // Codec icon
                ZStack {
                    Circle()
                        .fill(isDeleted
                              ? Color.white.opacity(0.04)
                              : (audioJob.isDefault ? Color.accent1.opacity(0.2) : Color.white.opacity(0.07)))
                        .frame(width: 28, height: 28)
                    Image(systemName: trackIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isDeleted
                                         ? .textSecondary.opacity(0.3)
                                         : (audioJob.isDefault ? .accent1 : .textSecondary.opacity(0.7)))
                }
                .animation(.spring(response: 0.25), value: audioJob.isDefault)
                .animation(.spring(response: 0.25), value: isDeleted)

                // Title + subtitle
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(trackTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isDeleted ? .textSecondary.opacity(0.35) : .textPrimary)

                        if audioJob.isDefault {
                            Text("PRIMARY")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.accent1)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.accent1.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(trackSubtitle)
                        .font(.system(size: 10))
                        .foregroundColor(isDeleted ? .textSecondary.opacity(0.25) : .textSecondary.opacity(0.6))
                }
            }

            Spacer()

            // ── Controls ─────────────────────────────────────────────
            HStack(spacing: 6) {

                // Spatializer toggle (only when enabled and track supports it)
                if !isDeleted {
                    if canSpatialize {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                audioJob.useSpatializer.toggle()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: audioJob.useSpatializer ? "sparkles" : "sparkles")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Spatial")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(audioJob.useSpatializer ? .accent1 : .textSecondary.opacity(0.5))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                audioJob.useSpatializer
                                    ? Color.accent1.opacity(0.15)
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
                    } else {
                        // Strategy badge (non-interactive)
                        let effectiveMode = audioJob.strategy.audioMode
                        Text(modeBadgeLabel(effectiveMode))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accent2.opacity(0.8))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.accent2.opacity(0.1), in: Capsule())
                    }
                }

                // Separator
                if !isDeleted {
                    Divider()
                        .frame(height: 14)
                        .opacity(0.2)
                }

                // Make Primary button
                if !isDeleted && !audioJob.isDefault {
                    TrackActionButton(
                        icon: "star.fill",
                        label: "Primary",
                        color: .yellow,
                        action: onMakePrimary
                    )
                }

                // Delete / Restore button
                if !isOnlyTrack {
                    if isDeleted {
                        TrackActionButton(
                            icon: "plus.circle.fill",
                            label: "Keep",
                            color: .green,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    audioJob.isEnabled = true
                                }
                            }
                        )
                    } else {
                        TrackActionButton(
                            icon: "trash.fill",
                            label: "Remove",
                            color: .red,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    audioJob.isEnabled = false
                                    // If this was the primary, reassign to first enabled
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
                           : Color.white.opacity(0.08)),
                    lineWidth: 0.5
                )
        )
        .animation(.spring(response: 0.3), value: audioJob.isEnabled)
        .animation(.spring(response: 0.3), value: audioJob.isDefault)
        .opacity(isDeleted ? 0.5 : 1.0)
    }

    // MARK: - Helpers

    private var trackTitle: String {
        if let lang = stream.language { return lang.uppercased() }
        return "Track \(stream.id)"
    }

    private var trackSubtitle: String {
        var parts: [String] = [stream.codecName.uppercased()]
        if let ch = stream.channels { parts.append(channelName(ch)) }
        if let title = stream.title  { parts.append("\"\(title)\"") }
        return parts.joined(separator: " · ")
    }

    private var trackIcon: String {
        let codec = stream.codecName.lowercased()
        if codec.contains("eac3") || codec.contains("ac3") { return "d.circle.fill" }
        if codec.contains("dts")  { return "waveform.circle.fill" }
        if codec.contains("aac")  { return "a.circle.fill" }
        return "music.note"
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
        case .copy:         return "Copy"
        case .toEAC3:       return "→ EAC3"
        case .toAC3:        return "→ AC3"
        case .toAACStereo:  return "→ AAC"
        case .spatialUpmix: return "⬆ Spatial"
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
            .foregroundColor(isHovered ? color : color.opacity(0.5))
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
