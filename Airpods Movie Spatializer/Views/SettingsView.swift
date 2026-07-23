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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ──────────────────────────────────────────────
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient.accentGradient)
                            .frame(width: 44, height: 44)
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Configure FFmpeg binary path")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.bottom, 4)

                // ── FFmpeg ───────────────────────────────────────────────
                SettingsCard(icon: "terminal.fill", title: "FFmpeg Binary", accentColor: .accent1) {
                    BinaryPathRow(
                        path: $settings.ffmpegPath,
                        placeholder: "Path to ffmpeg binary...",
                        onBrowse: { browseForBinary(title: "Select FFmpeg binary", key: "ffmpeg") }
                    )

                    HStack(spacing: 8) {
                        SettingsActionButton(label: "Auto-detect", icon: "magnifyingglass", color: .accent2) {
                            settings.autoDetectFFmpeg()
                        }
                        SettingsActionButton(label: "Remove Quarantine", icon: "lock.open", color: .orange) {
                            if settings.removeQuarantine(from: settings.ffmpegPath) {
                                quarantineMsg = "Quarantine removed from ffmpeg ✓"
                            } else {
                                quarantineMsg = "Nothing to remove or failed"
                            }
                        }
                        .disabled(settings.ffmpegPath.isEmpty)
                    }

                    if let msg = quarantineMsg {
                        Label(msg, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .transition(.opacity)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundColor(.textSecondary.opacity(0.5))
                        Text("Homebrew: /opt/homebrew/bin/ffmpeg  ·  Intel: /usr/local/bin/ffmpeg")
                            .font(.caption2)
                            .foregroundColor(.textSecondary.opacity(0.65))
                    }
                }

                // ── FFprobe ──────────────────────────────────────────────
                SettingsCard(icon: "magnifyingglass.circle.fill", title: "FFprobe Binary", accentColor: .accent2) {
                    BinaryPathRow(
                        path: $settings.ffprobePath,
                        placeholder: "Path to ffprobe (auto-detected)...",
                        onBrowse: { browseForBinary(title: "Select ffprobe binary", key: "ffprobe") }
                    )

                    HStack(spacing: 8) {
                        SettingsActionButton(label: "Auto-detect", icon: "magnifyingglass", color: .accent2) {
                            settings.autoDetectFFprobe()
                        }
                        SettingsActionButton(label: "Remove Quarantine", icon: "lock.open", color: .orange) {
                            if settings.removeQuarantine(from: settings.ffprobePath) {
                                quarantineMsg = "Quarantine removed from ffprobe ✓"
                            } else {
                                quarantineMsg = "Nothing to remove or failed"
                            }
                        }
                        .disabled(settings.ffprobePath.isEmpty)
                    }
                }

                // ── Language ─────────────────────────────────────────────
                SettingsCard(icon: "globe", title: "Interface Language", accentColor: .accent1) {
                    HStack(spacing: 8) {
                        ForEach([
                            ("system", "🖥", "System"),
                            ("en", "🇬🇧", "English"),
                            ("ru", "🇷🇺", "Русский"),
                            ("uk", "🇺🇦", "Укр")
                        ], id: \.0) { id, flag, label in
                            LanguageTile(
                                flag: flag,
                                label: label,
                                isSelected: settings.appLanguage == id,
                                action: { settings.appLanguage = id }
                            )
                        }
                        Spacer()
                    }
                }

                // ── Verify ───────────────────────────────────────────────
                SettingsCard(icon: "checkmark.seal.fill", title: "Verify Installation", accentColor: Color(hue: 0.35, saturation: 0.7, brightness: 0.8)) {
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
                                Text("Verify FFmpeg")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient.accentGradient
                                    .opacity((settings.ffmpegPath.isEmpty || isVerifying) ? 0.35 : 1.0)
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.ffmpegPath.isEmpty || isVerifying)

                        Spacer()

                        if showSuccess, let version = ffmpegVersion {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("v\(version)")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
                        }

                        if let error = verifyError {
                            HStack(spacing: 5) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuccess)
                    .animation(.easeInOut(duration: 0.2), value: verifyError == nil)
                }

                // ── Homebrew hint ────────────────────────────────────────
                HomebrewHintView()

                Spacer(minLength: 8)
            }
            .padding(24)
        }
        .frame(width: 500)
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

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    var accentColor: Color = .accent1
    let content: Content

    init(icon: String, title: String, accentColor: Color = .accent1, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Divider().opacity(0.25)

            content
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Binary Path Row

struct BinaryPathRow: View {
    @Binding var path: String
    let placeholder: String
    let onBrowse: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $path)
                .textFieldStyle(.plain)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )

            Button("Browse", action: onBrowse)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

// MARK: - Settings Action Button

struct SettingsActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(isHovered ? 0.2 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Homebrew Hint View

struct HomebrewHintView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hue: 0.08, saturation: 0.7, brightness: 0.9).opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hue: 0.08, saturation: 0.7, brightness: 0.9))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Install via Homebrew")
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("brew install ffmpeg")
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 5))

                Text("After install, the binary is usually at /opt/homebrew/bin/ffmpeg")
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
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

// MARK: - Language Tile

struct LanguageTile: View {
    let flag: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(flag)
                    .font(.system(size: 24))
                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(width: 65, height: 65)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accent1.opacity(0.2) : Color.white.opacity(isHovered ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.accent1 : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isHovered && !isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
