import SwiftUI
import UserNotifications

// MARK: - App State

enum AppScreen {
    case dropZone
    case probing
    case ready(MediaInfo)
    case converting(MediaInfo, ConversionJob)
    case done(MediaInfo, ConversionJob)
}

// MARK: - Content View

struct ContentView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ffmpeg  = FFmpegManager.shared

    // UI State
    @State private var screen: AppScreen = .dropZone
    @State private var selectedURL: URL? = nil
    @State private var audioJobs: [AudioStreamJob] = []
    @State private var showCommandPreview: Bool = false
    @State private var showLog: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            if !settings.isConfigured {
                // First run / FFmpeg not configured
                WelcomeSetupView()
                    .frame(maxWidth: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
                    .padding(40)
            } else {
                mainContent
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert("Conversion Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header bar
                headerBar

                // Body content
                VStack(spacing: 16) {
                    switch screen {
                    case .dropZone:
                        dropZoneContent

                    case .probing:
                        probingContent

                    case .ready(let info):
                        readyContent(info)

                    case .converting(let info, let job):
                        convertingContent(info, job)

                    case .done(let info, let job):
                        doneContent(info, job)
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // App icon + title
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 34, height: 34)
                    Image(systemName: "headphones.circle")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("AirPods Spatializer")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Spatial Audio Converter")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            // File breadcrumb
            if let url = selectedURL {
                HStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.caption)
                        .foregroundColor(.accent1)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }

            // Stepback button
            if selectedURL != nil {
                Button {
                    resetToDropZone()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Clear file and start over")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(Divider().opacity(0.3), alignment: .bottom)
    }

    // MARK: - Drop Zone Content

    private var dropZoneContent: some View {
        VStack(spacing: 16) {
            DropZoneView(selectedURL: $selectedURL) { url in
                loadFile(url)
            }

            // Feature chips
            HStack(spacing: 10) {
                ForEach(features, id: \.0) { icon, label in
                    FeatureChip(icon: icon, label: label)
                }
            }
        }
    }

    // MARK: - Probing Content

    private var probingContent: some View {
        GlassCard {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Analyzing file...")
                    .font(.headline)
                Text(selectedURL?.lastPathComponent ?? "")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    // MARK: - Ready Content

    private func readyContent(_ info: MediaInfo) -> some View {
        VStack(spacing: 14) {
            MediaInfoView(mediaInfo: info)

            ConversionSettingsView(
                mediaInfo: info,
                audioJobs: $audioJobs,
                showCommandPreview: $showCommandPreview,
                onConvert: { startConversion(info) }
            )
        }
    }

    // MARK: - Converting Content

    private func convertingContent(_ info: MediaInfo, _ job: ConversionJob) -> some View {
        VStack(spacing: 14) {
            MediaInfoView(mediaInfo: info)

            ConversionProgressView(
                mediaInfo: info,
                job: job,
                showLog: $showLog,
                onCancel: { ffmpeg.cancel() },
                onRevealInFinder: { revealInFinder(job.outputURL) },
                onReset: { resetToDropZone() }
            )
        }
    }

    // MARK: - Done Content

    private func doneContent(_ info: MediaInfo, _ job: ConversionJob) -> some View {
        convertingContent(info, job)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            LinearGradient(
                colors: [Color.accent1.opacity(0.05), Color.accent2.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func loadFile(_ url: URL) {
        selectedURL = url
        audioJobs = []
        screen = .probing

        Task {
            do {
                let info = try await FFmpegManager.shared.probe(url: url)
                withAnimation(.spring(response: 0.4)) {
                    audioJobs = info.audioStreams.indices.map { i in
                        AudioStreamJob(
                            index: i,
                            isEnabled: i == 0,
                            forceSpatialUpmix: false,
                            strategy: ConversionStrategy.recommend(for: info, audioStreamIndex: i)
                        )
                    }
                    screen = .ready(info)
                }
            } catch {
                withAnimation {
                    screen = .dropZone
                    selectedURL = nil
                }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startConversion(_ info: MediaInfo) {
        let job = ConversionJob(
            inputURL: info.url,
            audioJobs: audioJobs
        )

        withAnimation {
            screen = .converting(info, job)
        }

        Task {
            do {
                try await FFmpegManager.shared.convert(job: job, mediaInfo: info)
                withAnimation {
                    screen = .done(info, job)
                }
                // Send macOS notification
                sendCompletionNotification(filename: job.outputURL.lastPathComponent)
            } catch FFmpegError.cancelled {
                withAnimation {
                    screen = .done(info, job)
                }
            } catch {
                withAnimation {
                    screen = .done(info, job)
                }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func resetToDropZone() {
        withAnimation(.spring(response: 0.4)) {
            screen = .dropZone
            selectedURL = nil
            audioJobs = []
            showCommandPreview = false
            showLog = false
            ffmpeg.logLines = []
            ffmpeg.progress = 0
        }
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func sendCompletionNotification(filename: String) {
        let content = UNMutableNotificationContent()
        content.title = "Conversion Complete"
        content.body = "\(filename) is ready for Spatial Audio"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Feature chips data

    private var features: [(String, String)] {
        [
            ("sparkles", "Spatial Audio"),
            ("doc.on.doc.fill", "Smart Remux"),
            ("arrow.triangle.2.circlepath", "Auto-detect Codec"),
            ("waveform", "5.1 Upmix"),
        ]
    }
}

// MARK: - Feature Chip

struct FeatureChip: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accent1)
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
    }
}
