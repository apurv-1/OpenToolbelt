#if DEBUG
import AppKit
import OpenToolbeltCore
import SwiftUI

/// Debug-only: renders the main views offscreen to PNGs in light and dark,
/// for design review without screenshotting the desktop. AppKit-backed
/// controls (List, TextField) do not render offscreen, so pages are composed
/// from their content views.
/// Usage: swift run OpenToolbeltApp --snapshot <dir> [--home <dir>]
@MainActor
enum Snapshot {
    static func run(to directory: URL, home: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = Store()
        store.apply(Audit.run(home: home))
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            // Dynamic colors resolve against the app appearance offscreen, so set both.
            NSApplication.shared.appearance = NSAppearance(named: appearance)
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                let scheme: ColorScheme = name == "dark" ? .dark : .light
                write(PopoverView(), store, scheme, width: 300, to: directory.appendingPathComponent("popover-\(name).png"))
                write(OverviewContent().padding(24), store, scheme, width: 1000, to: directory.appendingPathComponent("overview-\(name).png"))
                // Full-window shots for the README. Pages are composed without
                // their scroll views and search field, which do not render offscreen.
                store.page = .overview
                write(window(PageBar(title: "Overview", detail: "since \(Format.day(store.firstSeen))") { AddSkillsButton() },
                             OverviewContent().padding(Theme.Space.lg)),
                      store, scheme, width: 1240, to: directory.appendingPathComponent("window-overview-\(name).png"))
                store.page = .library(.all)
                write(window(PageBar(title: "Everything", detail: "\(store.rows.count) items") { AddSkillsButton() },
                             VStack(spacing: 0) {
                                 MatrixColumnHeader()
                                 Hairline()
                                 MatrixSections(sections: LibrarySection.group(store.rows)).padding(.vertical, 8)
                             }),
                      store, scheme, width: 1240, to: directory.appendingPathComponent("window-library-\(name).png"))
                let skills = VStack(spacing: 0) {
                    MatrixColumnHeader()
                    Hairline()
                    MatrixSections(sections: LibrarySection.group(store.rows)).padding(.vertical, 8)
                }
                write(skills, store, scheme, width: 900, to: directory.appendingPathComponent("skills-\(name).png"))
            }
        }
    }

    private static func window<Bar: View, Content: View>(_ bar: Bar, _ content: Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Sidebar()
                .frame(width: 216)
                .frame(maxHeight: .infinity)
                .background(Theme.Palette.sidebar)
                .overlay(alignment: .trailing) { Rectangle().fill(Theme.Palette.hairline).frame(width: 1) }
            VStack(spacing: 0) {
                bar
                content
                Spacer(minLength: 0)
            }
            .background(Theme.Palette.canvas)
        }
        .fixedSize(horizontal: false, vertical: true)
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
