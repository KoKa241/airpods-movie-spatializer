import SwiftUI

// MARK: - Conversion Progress View

struct ConversionProgressView: View {
    let mediaInfo: MediaInfo
    let job: ConversionJob
    @Binding var showLog: Bool
    let onCancel: () -> Void
    let onRevealInFinder: () -> Void
    let onReset: () -> Void

    @State private var particleAngles: [Double] = Array(repeating: 0, count: 8)

    private let ffmpeg = FFmpegManager.shared

    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                // Phase header
                SectionHeader(
                    title: ffmpeg.isConverting ? "Converting..." : (ffmpeg.progress >= 1 ? "Done!" : "Cancelled"),
                    icon: ffmpeg.isConverting ? "waveform.badge.sparkles" : (ffmpeg.progress >= 1 ? "checkmark.circle.fill" : "xmark.circle.fill")
                )

                Divider().opacity(0.3)

                // Circular progress
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: ffmpeg.progress)
                        .stroke(
                            LinearGradient.accentGradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: ffmpeg.progress)

                    // Center content
                    VStack(spacing: 2) {
                        if ffmpeg.isConverting {
                            Text(String(format: "%.0f%%", ffmpeg.progress * 100))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.accent1)
                        } else if ffmpeg.progress >= 1 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.accent1)
                        } else {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        Text(ffmpeg.currentPhase)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }

                // File info
                VStack(spacing: 4) {
                    Text(mediaInfo.url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.accent1)
                        Text(job.outputURL.lastPathComponent)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accent1)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Action buttons
                if ffmpeg.isConverting {
                    GradientButton(title: "Cancel", icon: "stop.fill", action: onCancel, isDestructive: true)
                } else if ffmpeg.progress >= 1 {
                    VStack(spacing: 10) {
                        GradientButton(title: "Reveal in Finder", icon: "folder.fill", action: onRevealInFinder)
                        SecondaryButton(title: "Convert Another File", icon: "arrow.counterclockwise", action: onReset)
                    }
                } else {
                    SecondaryButton(title: "Convert Another File", icon: "arrow.counterclockwise", action: onReset)
                }

                // Log section
                logSection
            }
        }
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showLog.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showLog ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text("FFmpeg Log")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    if ffmpeg.isConverting {
                        PulsingDot()
                    }
                }
            }
            .buttonStyle(.plain)

            if showLog {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(ffmpeg.logLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(logLineColor(line))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line)
                            }
                            Spacer()
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(10)
                    }
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(height: 150)
                    .onChange(of: ffmpeg.logLines.count) { _ in
                        withAnimation { proxy.scrollTo("bottom") }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func logLineColor(_ line: String) -> Color {
        if line.hasPrefix("✓") { return .green.opacity(0.9) }
        if line.hasPrefix("✗") || line.hasPrefix("⚠") { return .yellow.opacity(0.9) }
        if line.hasPrefix("→") { return .accent2.opacity(0.9) }
        return .white.opacity(0.6)
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.accent1)
            .frame(width: 6, height: 6)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1 : 0.5)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
