import OpenSkillsCore
import SwiftUI

/// The panel that drops down from the menu bar icon, in the style of a
/// command palette: a header, the agents, and a few actions.
struct PopoverView: View {
    @Environment(Store.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let used = store.rows.filter { $0.totalUses > 0 }.count
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ShaderView(kind: .radar(blips: store.blips()), scopeRadius: 16)
                    .frame(width: 38, height: 38)
                    .clipShape(.circle)
                    .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.result == nil ? "Scanning your agents" : "\(used) of \(store.rows.count) skills used")
                        .font(Theme.Font.bodyMedium).foregroundStyle(Theme.Palette.text)
                    Text(store.isScanning ? "Reading local logs…" : "\(store.sessions) sessions · scanned \(Format.ago(store.lastScan))")
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Hairline()
            section("Agents")
            ForEach(store.columns.filter(\.detected)) { column in
                MenuRow(title: column.agent.displayName, detail: "\(store.rows(.agent(column.agent)).count)") {
                    AgentIcon(agent: column.agent, size: 15)
                } action: {
                    open(.skills(.agent(column.agent)))
                }
            }
            Hairline().padding(.vertical, 6)
            MenuRow(title: "Never used", detail: "\(store.rows(.idle).count)") {
                StatusDot(state: .idle)
            } action: { open(.skills(.idle)) }
            MenuRow(title: "Add skills…", shortcut: "⌘N") {
                Image(systemName: "plus").foregroundStyle(Theme.Palette.textSecondary)
            } action: {
                open(.skills(.all))
                store.showingAddSkill = true
            }
            .keyboardShortcut("n")
            MenuRow(title: "Open OpenSkills", shortcut: "⌘O") {
                Image(systemName: "macwindow").foregroundStyle(Theme.Palette.textSecondary)
            } action: { open(store.page) }
            .keyboardShortcut("o")
            MenuRow(title: "Quit", shortcut: "⌘Q") {
                Image(systemName: "power").foregroundStyle(Theme.Palette.textSecondary)
            } action: { NSApp.terminate(nil) }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .frame(width: 300)
        .background(Theme.Palette.surface)
    }

    private func section(_ title: String) -> some View {
        Text(title).font(Theme.Font.section).foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
    }

    private func open(_ page: Page) {
        store.page = page
        openWindow(id: WindowID.main)
        NSApp.activate()
    }
}
