import SwiftUI

// MARK: - Drop Zone View

struct DropZoneView: View {
    @Binding var selectedURL: URL?
    let onFileSelected: (URL) -> Void

    @State private var isDragging = false
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    private let acceptedTypes = ["mkv", "avi", "mp4", "mov", "m4v", "wmv",
                                  "flv", "ts", "mts", "m2ts", "vob", "mpg",
                                  "mpeg", "m2v", "3gp", "webm", "ogv"]

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient.subtleGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isDragging
                                ? LinearGradient.accentGradient
                                : LinearGradient(colors: [Color.white.opacity(0.15)],
                                                 startPoint: .top, endPoint: .bottom),
                            lineWidth: isDragging ? 2 : 1
                        )
                )
                .animation(.spring(response: 0.3), value: isDragging)

            // Pulse rings when dragging
            if isDragging {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient.accentGradient.opacity(0.3 - Double(i) * 0.1),
                            lineWidth: 1
                        )
                        .scaleEffect(1 + CGFloat(i) * 0.04 * pulseScale)
                }
            }

            // Content
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentGradient.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isDragging ? 1.1 * pulseScale : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isDragging)

                    Image(systemName: isDragging ? "film.stack.fill" : "film.stack")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(isDragging ? LinearGradient.accentGradient : LinearGradient(colors: [.textSecondary], startPoint: .top, endPoint: .bottom))
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isDragging)
                }

                VStack(spacing: 6) {
                    Text(isDragging ? "Release to Load" : "Drop Video File Here")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(isDragging ? .accent1 : .textPrimary)
                        .animation(.easeInOut(duration: 0.2), value: isDragging)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    // File picker button
                    Button(action: openFilePicker) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Choose File")
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                        .foregroundColor(.textPrimary)
                    }
                    .buttonStyle(.plain)
                }

                // Supported formats
                Text("MKV · AVI · MP4 · MOV · TS · WMV and more")
                    .font(.caption2)
                    .foregroundColor(.textSecondary.opacity(0.7))
            }
            .padding(32)
        }
        .frame(minHeight: 220)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: isDragging) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            } else {
                pulseScale = 1.0
            }
        }
    }

    // MARK: - Actions

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = []
        panel.message = "Select a video file to convert"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            processURL(url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                self.processURL(url)
            }
        }
        return true
    }

    private func processURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard acceptedTypes.contains(ext) || ext.isEmpty else { return }

        selectedURL = url
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            onFileSelected(url)
        }
    }
}
