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

/// Inline search field in the Raycast style.
struct SearchField: View {
    @Binding var text: String
    var prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Palette.textTertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.Font.body)
                .focused($focused)
            if text.isEmpty {
                KeyCap(keys: "⌘F")
            } else {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 240, height: 28)
        .background(Theme.Palette.raised, in: .rect(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control)
            .strokeBorder(focused ? Theme.Palette.textTertiary : .clear, lineWidth: 1))
        .background(Button("") { focused = true }.keyboardShortcut("f").hidden())
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
