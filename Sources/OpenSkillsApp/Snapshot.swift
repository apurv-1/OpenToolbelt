#if DEBUG
import AppKit
import OpenSkillsCore
import SwiftUI

/// Debug-only: renders the main views offscreen to PNGs in light and dark,
/// for design review without screenshotting the desktop.
/// Usage: swift run OpenSkillsApp --snapshot <dir>
@MainActor
enum Snapshot {
    static func run(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = Store()
        store.apply(Audit.run())
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                let scheme: ColorScheme = name == "dark" ? .dark : .light
                write(PopoverView(), store, scheme, width: 340, to: directory.appendingPathComponent("popover-\(name).png"))
                write(OverviewContent(section: .constant(.overview)), store, scheme, width: 880,
                      to: directory.appendingPathComponent("overview-\(name).png"))
                write(ItemListContent(title: "Skills", items: Array(store.items(.skill).prefix(14)), query: ""), store, scheme, width: 880,
                      to: directory.appendingPathComponent("skills-\(name).png"))
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
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
