import OpenToolbeltCore
import SwiftUI

/// The library: one row per skill or MCP server, one column per agent.
struct LibraryPage: View {
    @Environment(Store.self) private var store
    var filter: LibraryFilter
    @State private var query = ""

    var body: some View {
        let rows = store.rows(filter).filter(matches)
        VStack(spacing: 0) {
            MatrixColumnHeader()
            Hairline()
            ScrollView {
                MatrixSections(sections: LibrarySection.group(rows), expandAll: !query.isEmpty)
                    .padding(.vertical, Theme.Space.xs)
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle(rows))
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .toolbar {
            ToolbarItem { LegendButton() }
            ToolbarItem(placement: .primaryAction) {
                Button { store.showingAddSkill = true } label: { Label("Add skills", systemImage: "plus") }
                    .keyboardShortcut("n")
                    .help("Add skills (⌘N)")
            }
        }
    }

    private var title: String {
        switch filter {
        case .all: "Everything"
        case .skills: "Skills"
        case .mcpServers: "MCP servers"
        case .idle: "Never used"
        case .agent(let agent): agent.displayName
        case .idleIn(let agent): "Unused in \(agent.displayName)"
        }
    }

    private func subtitle(_ rows: [LibraryRow]) -> String {
        let skills = rows.filter { $0.kind == .skill }.count, servers = rows.count - skills
        return [skills > 0 ? "\(skills) skills" : nil, servers > 0 ? "\(servers) MCP servers" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func matches(_ row: LibraryRow) -> Bool {
        guard !query.isEmpty else { return true }
        if row.name.localizedCaseInsensitiveContains(query) || (row.summary?.localizedCaseInsensitiveContains(query) ?? false) { return true }
        if case .external(let source, _) = row.origin { return source.localizedCaseInsensitiveContains(query) }
        return false
    }
}

/// Column widths shared by the header and every row, so the grid lines up.
enum MatrixLayout {
    static let uses: CGFloat = 52
    static let lastUsed: CGFloat = 76
    static let actions: CGFloat = 60
    static let inset: CGFloat = Theme.Space.lg
    /// Chevron width plus gap, so row tiles line up under section icons.
    static let nameIndent: CGFloat = 18
}

struct MatrixColumnHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Name").padding(.leading, MatrixLayout.nameIndent).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Agent.allCases, id: \.self) { agent in
                AgentIcon(agent: agent, style: .mono, size: 14)
                    .opacity(0.75)
                    .frame(width: Theme.Size.agentColumn)
            }
            Text("Uses").frame(width: MatrixLayout.uses, alignment: .trailing)
            Text("Last used").frame(width: MatrixLayout.lastUsed, alignment: .trailing)
            Color.clear.frame(width: MatrixLayout.actions)
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Palette.textTertiary)
        .padding(.horizontal, MatrixLayout.inset)
        .frame(height: 32)
    }
}

struct MatrixSections: View {
    var sections: [LibrarySection]
    var expandAll = false
    @State private var toggled: Set<String> = []

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(sections) { section in
                let collapsed = !expandAll && (section.collapsedByDefault != toggled.contains(section.id))
                SectionHeaderRow(section: section, collapsed: collapsed) {
                    withAnimation(Theme.Motion.smooth) {
                        if toggled.contains(section.id) { toggled.remove(section.id) } else { toggled.insert(section.id) }
                    }
                }
                if !collapsed {
                    ForEach(section.rows) { MatrixRow(row: $0) }
                }
            }
            if sections.isEmpty {
                Text("Nothing matches.")
                    .font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity).padding(.top, 60)
            }
        }
        .padding(.horizontal, Theme.Space.xs)
    }
}

struct SectionHeaderRow: View {
    var section: LibrarySection
    var collapsed: Bool
    var toggle: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.Palette.textTertiary)
                .rotationEffect(.degrees(collapsed ? 0 : 90))
                .frame(width: 10)
            Group {
                switch section.icon {
                case .symbol(let name):
                    Image(systemName: name).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary)
                case .agent(let agent):
                    AgentIcon(agent: agent, style: .mono, size: 13).opacity(0.7)
                }
            }
            .frame(width: 18)
            .help(section.kind)
            Text(section.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.text)
                .help(section.kind)
            Text(section.contents).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
            if let link = section.link, hovering {
                Link(destination: link) {
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .help(link.absoluteString)
            }
            Spacer()
        }
        .padding(.horizontal, MatrixLayout.inset - Theme.Space.xs)
        .frame(height: 30)
        .padding(.top, 6)
        .contentShape(.rect)
        .onTapGesture(perform: toggle)
        .onHover { hovering = $0 }
    }
}

struct MatrixRow: View {
    @Environment(Store.self) private var store
    var row: LibraryRow
    @State private var hovering = false
    @State private var confirmingRemove = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                ItemTile(kind: row.kind, name: row.name)
                Text(row.name).font(Theme.Font.bodyMedium).foregroundStyle(Theme.Palette.text).lineLimit(1)
                    .layoutPriority(1)
                if !row.enabled {
                    Text("disabled").font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textTertiary)
                } else if row.installedAgents.isEmpty {
                    Text("in the lockfile, not installed in any agent").font(Theme.Font.secondary).foregroundStyle(Theme.Palette.idle)
                } else if let summary = row.summary {
                    Text(summary).font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textTertiary).lineLimit(1)
                }
            }
            .padding(.leading, MatrixLayout.nameIndent)
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Agent.allCases, id: \.self) { agent in
                StatusDot(state: state(agent))
                    .frame(width: Theme.Size.agentColumn, height: Theme.Size.row)
                    .contentShape(.rect)
                    .help(tooltip(agent))
            }
            Text(row.totalUses > 0 ? "\(row.totalUses)" : "–")
                .font(Theme.Font.number)
                .foregroundStyle(row.totalUses > 0 ? Theme.Palette.text : Theme.Palette.textTertiary)
                .frame(width: MatrixLayout.uses, alignment: .trailing)
            Text(row.lastUsed.map { Format.ago($0) } ?? "–")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: MatrixLayout.lastUsed, alignment: .trailing)
            HStack(spacing: 0) {
                if let path = row.paths.first {
                    IconButton(systemImage: "folder", help: "Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    .opacity(hovering ? 1 : 0)
                }
                // Removal is always visible where the app can do it safely.
                if row.isExternal {
                    IconButton(systemImage: "trash", help: "Remove from every agent") { confirmingRemove = true }
                        .opacity(hovering ? 1 : 0.55)
                }
            }
            .frame(width: MatrixLayout.actions, alignment: .trailing)
        }
        .padding(.horizontal, MatrixLayout.inset - Theme.Space.xs)
        .frame(height: Theme.Size.row)
        .background(hovering ? Theme.Palette.raised : .clear, in: .rect(cornerRadius: Theme.Radius.row))
        .onHover { hovering = $0 }
        .confirmationDialog("Remove \(row.name) from every agent?", isPresented: $confirmingRemove) {
            Button("Remove", role: .destructive) {
                store.cli.run(SkillsCommand.remove(skills: [row.name])) { store.refresh() }
                store.showingAddSkill = true
            }
        } message: {
            Text("Runs npx skills remove. The skill can be added again from its source.")
        }
    }

    private func state(_ agent: Agent) -> StatusDot.State {
        guard let cell = row.cells[agent], cell.installed else { return .absent }
        guard let uses = cell.uses else { return .installed }
        return uses > 0 ? .used : .idle
    }

    private func tooltip(_ agent: Agent) -> String {
        guard let cell = row.cells[agent], cell.installed else { return "\(agent.displayName): not installed" }
        guard let uses = cell.uses else { return "\(agent.displayName): installed, usage not tracked" }
        if uses == 0 { return "\(agent.displayName): installed, never used" }
        return "\(agent.displayName): \(uses) uses, last \(Format.ago(cell.lastUsed))"
    }
}

/// The cell marks explained, behind one toolbar button instead of a footer.
struct LegendButton: View {
    @Environment(Store.self) private var store
    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: { Label("Legend", systemImage: "info.circle") }
            .help("What the marks mean")
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    entry(.used, "Used")
                    entry(.idle, "Installed, never used")
                    entry(.installed, "Installed, usage not tracked")
                    entry(.absent, "Not installed")
                    Hairline().padding(.vertical, 2)
                    Text(note).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Space.md)
                .frame(width: 250)
            }
    }

    private var note: String {
        "Usage comes from Claude Code and Codex logs" + (store.firstSeen.map { " since \(Format.day($0))." } ?? ".")
    }

    private func entry(_ state: StatusDot.State, _ label: String) -> some View {
        HStack(spacing: 10) {
            StatusDot(state: state).frame(width: 10)
            Text(label).font(Theme.Font.secondary).foregroundStyle(Theme.Palette.text)
        }
    }
}
