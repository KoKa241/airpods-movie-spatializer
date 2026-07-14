import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var ffmpegVersion: String? = nil
    @State private var isVerifying = false
    @State private var verifyError: String? = nil
    @State private var showSuccess = false
    @State private var quarantineMsg: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                VStack(alignment: .leading) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure FFmpeg binary path")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Divider()

            // FFmpeg path
            VStack(alignment: .leading, spacing: 10) {
                Label("FFmpeg Binary", systemImage: "terminal.fill")
                    .font(.headline)

                HStack {
                    TextField("Path to ffmpeg binary...", text: $settings.ffmpegPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse") {
                        browseForBinary(title: "Select FFmpeg binary", key: "ffmpeg")
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    Button("Auto-detect") {
                        settings.autoDetectFFmpeg()
                    }
                    .font(.caption)
                    .foregroundColor(.accent2)

                    Button("Remove Quarantine") {
                        if settings.removeQuarantine(from: settings.ffmpegPath) {
                            quarantineMsg = "Quarantine removed from ffmpeg ✓"
                        } else {
                            quarantineMsg = "Nothing to remove or failed"
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .disabled(settings.ffmpegPath.isEmpty)
                }

                if let msg = quarantineMsg {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Text("Homebrew: /opt/homebrew/bin/ffmpeg  ·  Intel Mac: /usr/local/bin/ffmpeg")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            // ffprobe path (auto or manual)
            VStack(alignment: .leading, spacing: 10) {
                Label("FFprobe Binary", systemImage: "magnifyingglass")
                    .font(.headline)

                HStack {
                    TextField("Path to ffprobe (auto-detected)...", text: $settings.ffprobePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse") {
                        browseForBinary(title: "Select ffprobe binary", key: "ffprobe")
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    Button("Auto-detect from FFmpeg location") {
                        settings.autoDetectFFprobe()
                    }
                    .font(.caption)
                    .foregroundColor(.accent2)

                    Button("Remove Quarantine") {
                        if settings.removeQuarantine(from: settings.ffprobePath) {
                            quarantineMsg = "Quarantine removed from ffprobe ✓"
                        } else {
                            quarantineMsg = "Nothing to remove or failed"
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .disabled(settings.ffprobePath.isEmpty)
                }
            }

            Divider()

            // Verify & status
            HStack(spacing: 12) {
                Button {
                    verifyFFmpeg()
                } label: {
                    HStack(spacing: 6) {
                        if isVerifying {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.seal")
                        }
                        Text("Verify")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(settings.ffmpegPath.isEmpty || isVerifying)

                // Status indicator
                if showSuccess, let version = ffmpegVersion {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if let error = verifyError {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            // Homebrew hint
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 13))
                        Text("Install via Homebrew")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("brew install ffmpeg")
                        .font(.system(.body, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("After install, the binary is usually at /opt/homebrew/bin/ffmpeg")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 480)
        .animation(.spring(response: 0.3), value: showSuccess)
    }

    // MARK: - Actions

    private func browseForBinary(title: String, key: String) {
        let panel = NSOpenPanel()
        panel.message = title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            if key == "ffmpeg" {
                settings.ffmpegPath = url.path
                settings.autoDetectFFprobe()
            } else {
                settings.ffprobePath = url.path
            }
        }
    }

    private func verifyFFmpeg() {
        isVerifying = true
        showSuccess = false
        verifyError = nil

        Task {
            await Task.detached(priority: .userInitiated) {
                let version = AppSettings.shared.ffmpegVersion
                await MainActor.run {
                    isVerifying = false
                    if let v = version {
                        ffmpegVersion = v
                        showSuccess = true
                    } else {
                        verifyError = "Binary not found or not executable"
                    }
                }
            }.value
        }
    }
}

// MARK: - Welcome Setup View

struct WelcomeSetupView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 0) {
            // Hero gradient header
            ZStack {
                LinearGradient(
                    colors: [Color.accent1.opacity(0.8), Color.accent2.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 16) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 20)
                        .scaleEffect(animateIn ? 1.0 : 0.7)
                        .opacity(animateIn ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("AirPods Spatializer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Convert any video for Apple Spatial Audio")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                }
                .padding(40)
            }
            .frame(height: 220)

            // Setup section
            VStack(alignment: .leading, spacing: 20) {
                Text("First, select your FFmpeg binary")
                    .font(.headline)
                    .padding(.top, 4)

                // Path field
                HStack {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.textSecondary)
                    TextField("FFmpeg path...", text: $settings.ffmpegPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Browse") {
                        let panel = NSOpenPanel()
                        panel.message = "Select FFmpeg binary"
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            settings.ffmpegPath = url.path
                            settings.autoDetectFFprobe()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                // Common locations hint
                VStack(alignment: .leading, spacing: 4) {
                    Text("Common locations:")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    ForEach(["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"], id: \.self) { path in
                        Button(path) {
                            settings.ffmpegPath = path
                            settings.autoDetectFFprobe()
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.accent2)
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                GradientButton(
                    title: "Get Started",
                    icon: "arrow.right.circle.fill",
                    action: {},
                    isDisabled: !settings.isConfigured
                )
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                animateIn = true
            }
        }
    }
}
