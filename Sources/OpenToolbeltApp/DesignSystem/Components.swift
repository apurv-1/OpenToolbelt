import OpenToolbeltCore
import SwiftUI

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
    }
}

/// A keyboard shortcut hint, like ⌘N.
struct KeyCap: View {
    var keys: String
    var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Theme.Palette.raised, in: .rect(cornerRadius: 4))
    }
}

/// The state of one skill in one agent, as a single mark.
struct StatusDot: View {
    enum State { case absent, installed, used, idle }
    var state: State

    var body: some View {
        switch state {
        case .absent:
            Circle().fill(Theme.Palette.textTertiary.opacity(0.35)).frame(width: 3, height: 3)
        case .installed:
            Circle().strokeBorder(Theme.Palette.textSecondary, lineWidth: 1.5).frame(width: 9, height: 9)
        case .idle:
            Circle().strokeBorder(Theme.Palette.idle, lineWidth: 1.5).frame(width: 9, height: 9)
        case .used:
            Circle().fill(Theme.Palette.accent).frame(width: 9, height: 9)
                .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 3)
        }
    }
}

/// Icon-only button with a quiet hover fill.
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
                .background(hovering ? Theme.Palette.raised : .clear, in: .rect(cornerRadius: Theme.Radius.control))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// The one primary action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.Palette.canvas)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Theme.Palette.text, in: .rect(cornerRadius: Theme.Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

/// Secondary actions: no fill until hovered.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GhostLabel(configuration: configuration)
    }

    private struct GhostLabel: View {
        var configuration: Configuration
        @State private var hovering = false
        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(hovering || configuration.isPressed ? Theme.Palette.raised : .clear, in: .rect(cornerRadius: Theme.Radius.control))
                .onHover { hovering = $0 }
        }
    }
}

/// A list row that highlights on hover, used in the menu bar panel.
struct MenuRow<Leading: View>: View {
    var title: String
    var detail: String?
    var shortcut: String?
    @ViewBuilder var leading: Leading
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leading.frame(width: 18, height: 18)
                Text(title).font(Theme.Font.body).foregroundStyle(Theme.Palette.text)
                Spacer(minLength: Theme.Space.xs)
                if let detail { Text(detail).font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary) }
                if let shortcut { KeyCap(keys: shortcut) }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(hovering ? Theme.Palette.raised : .clear, in: .rect(cornerRadius: Theme.Radius.row))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The leading mark on a row: a monogram tile for a skill, a plug for an MCP
/// server. Skills have no icon of their own, so the tile's color comes from
/// a hash of the name and stays stable across launches.
struct ItemTile: View {
    var kind: ItemKind
    var name: String
    var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        Group {
            switch kind {
            case .skill:
                Text(initial)
                    .font(.system(size: size * 0.56, weight: .semibold, design: .rounded))
                    .foregroundStyle(hue)
                    .frame(width: size, height: size)
                    .background(hue.opacity(0.16), in: shape)
            case .mcpServer:
                Image(systemName: "powerplug.fill")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: size, height: size)
                    .background(Theme.Palette.raised, in: shape)
                    .overlay(shape.strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            }
        }
        .help(kind == .skill ? "Skill" : "MCP server")
    }

    private var initial: String {
        let letters = name.split(separator: ":").last.map(String.init) ?? name
        return String(letters.first { $0.isLetter || $0.isNumber } ?? "?").uppercased()
    }

    private var hue: Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.55, brightness: 0.72)
    }
}
