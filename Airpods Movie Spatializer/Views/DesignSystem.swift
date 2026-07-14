import SwiftUI

// MARK: - Design System

extension Color {
    static let accent1 = Color(hue: 0.72, saturation: 0.7, brightness: 0.9)   // violet
    static let accent2 = Color(hue: 0.6, saturation: 0.8, brightness: 1.0)    // blue
    static let surfacePrimary = Color(NSColor.windowBackgroundColor)
    static let surfaceSecondary = Color(NSColor.controlBackgroundColor)
    static let textPrimary = Color(NSColor.labelColor)
    static let textSecondary = Color(NSColor.secondaryLabelColor)

    // Badge colors
    static let spatialReadyColor = Color(hue: 0.45, saturation: 0.7, brightness: 0.75)
    static let surroundColor = Color(hue: 0.55, saturation: 0.65, brightness: 0.85)
    static let stereoColor = Color(hue: 0.1, saturation: 0.65, brightness: 0.9)
    static let transcodeColor = Color(hue: 0.08, saturation: 0.7, brightness: 0.95)
}

extension LinearGradient {
    static let accentGradient = LinearGradient(
        colors: [.accent1, .accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let subtleGradient = LinearGradient(
        colors: [Color.accent1.opacity(0.15), Color.accent2.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Reusable Components

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

struct GradientButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    var isDisabled: Bool = false

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isDestructive {
                        LinearGradient(colors: [Color.red.opacity(0.8), Color.orange.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing)
                    } else {
                        LinearGradient.accentGradient
                    }
                }
                .opacity(isDisabled ? 0.4 : (isHovered ? 1.0 : 0.9))
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: (isDestructive ? Color.red : Color.accent1).opacity(isHovered ? 0.4 : 0.2), radius: 8, y: 3)
            .scaleEffect(isHovered && !isDisabled ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDisabled: Bool = false

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isHovered ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .foregroundColor(.textPrimary.opacity(isDisabled ? 0.4 : 1.0))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Stream Badge

struct AudioCompatibilityBadge: View {
    let compatibility: AudioCompatibility

    var badgeColor: Color {
        switch compatibility {
        case .spatialReady:       return .spatialReadyColor
        case .surroundCompatible: return .surroundColor
        case .stereoOnly:         return .stereoColor
        case .needsTranscode:     return .transcodeColor
        case .noAudio:            return .gray
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: compatibility.systemImage)
                .font(.system(size: 11))
            Text(compatibility.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.18))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(badgeColor.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .textPrimary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
            Spacer()
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accent1)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}
