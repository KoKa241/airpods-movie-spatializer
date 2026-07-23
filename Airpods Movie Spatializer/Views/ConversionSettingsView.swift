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

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
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
                    Text("\(audioJobs.filter(\.isEnabled).count) / \(audioJobs.count) selected")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                VStack(spacing: 8) {
                    ForEach(0..<audioJobs.count, id: \.self) { i in
                        AudioTrackRow(
                            stream: mediaInfo.audioStreams[audioJobs[i].index],
                            audioJob: $audioJobs[i],
                            isOnlyTrack: audioJobs.count == 1
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

// MARK: - Audio Track Row

struct AudioTrackRow: View {
    let stream: MediaStream
    @Binding var audioJob: AudioStreamJob
    let isOnlyTrack: Bool

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ──────────────────────────────────────────────
            Button {
                if audioJob.isEnabled {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    // Toggle
                    Toggle("", isOn: Binding(
                        get: { audioJob.isEnabled },
                        set: { newVal in
                            audioJob.isEnabled = newVal
                            if newVal { withAnimation(.spring(response: 0.35)) { isExpanded = true } }
                            else { withAnimation(.spring(response: 0.3)) { isExpanded = false } }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(.accent1)
                    .scaleEffect(0.85)
                    .disabled(isOnlyTrack)

                    // Track icon
                    ZStack {
                        Circle()
                            .fill(audioJob.isEnabled ? Color.accent1.opacity(0.18) : Color.white.opacity(0.06))
                            .frame(width: 30, height: 30)
                        Image(systemName: trackIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(audioJob.isEnabled ? .accent1 : .textSecondary.opacity(0.5))
                    }
                    .animation(.spring(response: 0.3), value: audioJob.isEnabled)

                    // Track label
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(trackTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(audioJob.isEnabled ? .textPrimary : .textSecondary.opacity(0.5))
                            if stream.isDefault {
                                Text("DEFAULT")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.accent1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.accent1.opacity(0.15), in: Capsule())
                            }
                        }
                        Text(trackSubtitle)
                            .font(.caption2)
                            .foregroundColor(.textSecondary.opacity(audioJob.isEnabled ? 0.7 : 0.4))
                    }

                    Spacer()

                    // Status badge (only when enabled & collapsed)
                    if audioJob.isEnabled && !isExpanded {
                        let effectiveMode = audioJob.forceSpatialUpmix ? AudioConversionMode.spatialUpmix : audioJob.strategy.audioMode
                        Text(modeBadgeLabel(effectiveMode))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.accent2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accent2.opacity(0.12), in: Capsule())
                            .transition(.opacity)
                    }

                    // Expand chevron
                    if audioJob.isEnabled {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.textSecondary.opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                            .animation(.spring(response: 0.3), value: isExpanded)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // ── Expanded settings ────────────────────────────────────────
            if audioJob.isEnabled && isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().opacity(0.2).padding(.horizontal, 12)

                    // Strategy card
                    strategyCard
                        .padding(.horizontal, 12)

                    // Force Spatial Upmix toggle
                    if audioJob.strategy.canForceSpatial {
                        forceSpatialRow
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(audioJob.isEnabled ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    audioJob.isEnabled ? Color.accent1.opacity(0.2) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.3), value: audioJob.isEnabled)
        .onAppear {
            // Auto-expand the default/only enabled track
            if audioJob.isEnabled { isExpanded = true }
        }
    }

    // MARK: - Sub-components

    private var strategyCard: some View {
        let strategy = audioJob.strategy
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accent1.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: strategyIcon(for: strategy.audioMode))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accent1)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(strategy.audioMode.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accent1)
                Text(strategy.explanation)
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.accent1.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accent1.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var forceSpatialRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accent1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Force Spatial Upmix")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                Text("Upmix stereo to 5.1 surround and activate Spatial Audio on AirPods")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $audioJob.forceSpatialUpmix)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(.accent1)
                .scaleEffect(0.85)
        }
        .padding(10)
        .background(
            audioJob.forceSpatialUpmix
                ? Color.accent1.opacity(0.1)
                : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    audioJob.forceSpatialUpmix ? Color.accent1.opacity(0.35) : Color.white.opacity(0.08),
                    lineWidth: audioJob.forceSpatialUpmix ? 1 : 0.5
                )
        )
        .animation(.spring(response: 0.3), value: audioJob.forceSpatialUpmix)
    }

    // MARK: - Helpers

    private var trackTitle: String {
        if let lang = stream.language {
            return lang.uppercased()
        }
        return "Track \(stream.id)"
    }

    private var trackSubtitle: String {
        var parts: [String] = [stream.codecName.uppercased()]
        if let ch = stream.channels { parts.append(channelName(ch)) }
        if let title = stream.title { parts.append("\"\(title)\"") }
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

    private func strategyIcon(for mode: AudioConversionMode) -> String {
        switch mode {
        case .copy:         return "doc.on.doc"
        case .toEAC3:       return "waveform"
        case .toAC3:        return "waveform"
        case .toAACStereo:  return "headphones"
        case .spatialUpmix: return "sparkles"
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

