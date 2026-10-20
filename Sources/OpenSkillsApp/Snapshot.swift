#if DEBUG
import AppKit
import OpenSkillsCore
import SwiftUI

/// Debug-only: renders the main views offscreen to PNGs in light and dark,
/// for design review without screenshotting the desktop. AppKit-backed
/// controls (List, TextField) do not render offscreen, so pages are composed
/// from their content views.
/// Usage: swift run OpenSkillsApp --snapshot <dir>
@MainActor
enum Snapshot {
    static func run(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = Store()
        store.apply(Audit.run())
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            // Dynamic colors resolve against the app appearance offscreen, so set both.
            NSApplication.shared.appearance = NSAppearance(named: appearance)
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                let scheme: ColorScheme = name == "dark" ? .dark : .light
                write(PopoverView(), store, scheme, width: 300, to: directory.appendingPathComponent("popover-\(name).png"))
                let skills = VStack(spacing: 0) {
                    PageHeader(title: "All skills", count: store.rows.count) {}
                    SummaryLine()
                    Hairline()
                    MatrixColumnHeader()
                    Hairline()
                    MatrixSections(sections: SkillSection.group(store.rows)).padding(.vertical, 8)
                    Hairline()
                    Legend()
                }
                write(skills, store, scheme, width: 900, to: directory.appendingPathComponent("skills-\(name).png"))
                write(MCPServerList(servers: store.mcpServers), store, scheme, width: 900,
                      to: directory.appendingPathComponent("mcp-\(name).png"))
            }
        }
    }

    private static func write<V: View>(_ view: V, _ store: Store, _ scheme: ColorScheme, width: CGFloat, to url: URL) {
        let content = view
            .environment(store)
            .environment(\.colorScheme, scheme)
            .frame(width: width)
            .background(Theme.Palette.canvas)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
