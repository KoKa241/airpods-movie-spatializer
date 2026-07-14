import SwiftUI

// MARK: - Conversion Settings View

struct ConversionSettingsView: View {
    let mediaInfo: MediaInfo
    @Binding var selectedAudioIndex: Int
    @Binding var forceSpatial: Bool
    @Binding var showCommandPreview: Bool
    let onConvert: () -> Void

    private var strategy: ConversionStrategy {
        ConversionStrategy.recommend(for: mediaInfo, audioStreamIndex: selectedAudioIndex)
    }

    private var job: ConversionJob {
        ConversionJob(
            inputURL: mediaInfo.url,
            selectedAudioStreamIndex: selectedAudioIndex,
            forceSpatialUpmix: forceSpatial && strategy.canForceSpatial
        )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Conversion Settings", icon: "slider.horizontal.3")

                Divider().opacity(0.3)

                // Audio track selector (if multiple tracks)
                if mediaInfo.audioStreams.count > 1 {
                    audioTrackPicker
                }

                // Strategy explanation
                strategyCard

                // Force spatial toggle (only when applicable)
                if strategy.canForceSpatial {
                    forceSpatialToggle
                }

                // Output path preview
                outputPathRow

                Divider().opacity(0.3)

                // Command preview
                commandPreviewSection

                // Convert button
                GradientButton(title: "Convert to Spatial Audio", icon: "waveform.badge.sparkles") {
                    onConvert()
                }
            }
        }
    }

    // MARK: - Sub-views

    private var audioTrackPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Track")
                .font(.caption)
                .foregroundColor(.textSecondary)

            Picker("Audio Track", selection: $selectedAudioIndex) {
                ForEach(0..<mediaInfo.audioStreams.count, id: \.self) { i in
                    let stream = mediaInfo.audioStreams[i]
                    let label = audioStreamLabel(stream)
                    Text(label).tag(i)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var strategyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            // Mode badge
            VStack(spacing: 4) {
                Image(systemName: strategyIcon)
                    .font(.title2)
                    .foregroundColor(.accent1)
                Text(strategy.audioMode.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accent1)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended Action")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)
                Text(strategy.explanation)
                    .font(.caption)
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(LinearGradient.subtleGradient)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accent1.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var forceSpatialToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(.accent1)
                    Text("Force Spatial Upmix")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text("Stereo → 5.1 через FFmpeg surround filter. Активирует Spatial Audio на AirPods.")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $forceSpatial)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(.accent1)
        }
        .padding(12)
        .background(forceSpatial
            ? Color.accent1.opacity(0.1)
            : Color.white.opacity(0.05)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    forceSpatial ? Color.accent1.opacity(0.4) : Color.white.opacity(0.08),
                    lineWidth: forceSpatial ? 1 : 0.5
                )
        )
        .animation(.spring(response: 0.3), value: forceSpatial)
    }

    private var outputPathRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .foregroundColor(.textSecondary)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
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

    private var commandPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showCommandPreview.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showCommandPreview ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text("FFmpeg Command Preview")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Image(systemName: "terminal.fill")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if showCommandPreview {
                let command = FFmpegManager.shared.buildCommandPreview(
                    for: job,
                    mediaInfo: mediaInfo,
                    mode: strategy.audioMode
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(command)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.green.opacity(0.9))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: 120)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Helpers

    private var strategyIcon: String {
        switch strategy.audioMode {
        case .copy:         return "doc.on.doc"
        case .toEAC3:       return "waveform.and.magnifyingglass"
        case .toAC3:        return "waveform"
        case .toAACStereo:  return "headphones"
        case .spatialUpmix: return "waveform.badge.sparkles"
        }
    }

    private func audioStreamLabel(_ stream: MediaStream) -> String {
        var parts: [String] = []
        if let lang = stream.language { parts.append(lang.uppercased()) }
        parts.append(stream.codecName.uppercased())
        if let ch = stream.channels { parts.append(channelName(ch)) }
        if let title = stream.title { parts.append("\"\(title)\"") }
        if stream.isDefault { parts.append("•") }
        return parts.joined(separator: " ")
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
}
