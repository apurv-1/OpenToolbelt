import SwiftUI

/// A raised surface. Elevation comes from layered soft shadows and a hairline,
/// not from heavy borders.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.Font.eyebrow)
            .tracking(0.6)
            .foregroundStyle(Theme.Palette.textTertiary)
    }
}

/// A big number with a label, for headline stats.
struct StatTile: View {
    var label: String
    var value: String
    var detail: String

    var body: some View {
        Card(padding: Theme.Space.sm + 2) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Eyebrow(text: label)
                Text(value).font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.Palette.text)
                Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }
}

enum PillTone {
    /// `quiet` is text only, for secondary tags that repeat on every row.
    case neutral, quiet, accent, idle

    var foreground: Color {
        switch self {
        case .neutral: Theme.Palette.textSecondary
        case .quiet: Theme.Palette.textTertiary
        case .accent: Theme.Palette.accent
        case .idle: Theme.Palette.idle
        }
    }

    var background: Color {
        switch self {
        case .neutral: Theme.Palette.sunken
        case .quiet: .clear
        case .accent: Theme.Palette.accentSoft
        case .idle: Theme.Palette.idleSoft
        }
    }
}

struct Pill: View {
    var text: String
    var tone: PillTone = .neutral

    var body: some View {
        Text(text)
            .font(Theme.Font.caption)
            .lineLimit(1)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tone.background, in: .rect(cornerRadius: Theme.Radius.pill))
    }
}

/// A thin horizontal meter, used to compare use counts within a list.
struct UsageBar: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.sunken)
                Capsule().fill(Theme.Palette.accent)
                    .frame(width: max(fraction > 0 ? 3 : 0, geo.size.width * fraction))
            }
        }
        .frame(height: 4)
    }
}

/// Icon-only button with a quiet hover state.
struct IconButton: View {
    var systemImage: String
    var help: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 26)
                .foregroundStyle(hovering ? Theme.Palette.text : Theme.Palette.textSecondary)
                .background(hovering ? Theme.Palette.sunken : .clear, in: .rect(cornerRadius: Theme.Radius.control))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// The primary action style: dark ink capsule, like the references.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Palette.surface)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Theme.Palette.text, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
