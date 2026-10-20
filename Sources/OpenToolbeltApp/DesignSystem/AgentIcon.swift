import AppKit
import OpenToolbeltCore
import SwiftUI

/// An agent's brand mark. SVGs come from lobe-icons (MIT, github.com/lobehub/lobe-icons);
/// the marks themselves belong to their owners.
struct AgentIcon: View {
    enum Style { case color, mono }

    var agent: Agent
    var style: Style = .color
    var size: CGFloat = 16

    var body: some View {
        Group {
            if style == .color, let image = AgentIcons.image(agent, color: true) {
                Image(nsImage: image).resizable()
            } else if let image = AgentIcons.image(agent, color: false) {
                Image(nsImage: image).renderingMode(.template).resizable().foregroundStyle(Theme.Palette.text)
            } else {
                Text(String(agent.displayName.prefix(1))).font(.system(size: size * 0.7, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .help(agent.displayName)
        .accessibilityLabel(agent.displayName)
    }
}

@MainActor
enum AgentIcons {
    private static var cache: [String: NSImage] = [:]

    private static func file(_ agent: Agent) -> String {
        switch agent {
        case .claudeCode: "claudecode"
        case .codex: "codex"
        case .cursor: "cursor"
        case .opencode: "opencode"
        case .windsurf: "windsurf"
        case .geminiCLI: "geminicli"
        }
    }

    /// The color mark when one exists, otherwise nil so callers fall back to mono.
    static func image(_ agent: Agent, color: Bool) -> NSImage? {
        let name = file(agent) + (color ? "-color" : "")
        if let cached = cache[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "AgentIcons"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = !color
        // The SVGs declare 24pt. Draw them from a large size and scale down,
        // so they stay sharp in the window, in 2x renders and in video frames.
        image.size = NSSize(width: 512, height: 512)
        cache[name] = image
        return image
    }
}
