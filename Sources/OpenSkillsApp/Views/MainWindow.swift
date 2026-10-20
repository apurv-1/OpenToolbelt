import OpenSkillsCore
import SwiftUI

enum Section: String, Hashable, CaseIterable, Identifiable {
    case overview = "Overview"
    case skills = "Skills"
    case servers = "MCP Servers"
    case neverUsed = "Never Used"
    case notInstalled = "Not Installed"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .overview: "dot.radiowaves.left.and.right"
        case .skills: "sparkles"
        case .servers: "server.rack"
        case .neverUsed: "moon.zzz"
        case .notInstalled: "questionmark.circle"
        }
    }
}

struct MainWindow: View {
    @Environment(Store.self) private var store
    @State private var section: Section = .overview

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Label(item.rawValue, systemImage: item.symbol)
                    .badge(badge(for: item))
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            Group {
                switch section {
                case .overview: OverviewView(section: $section)
                case .skills: ItemListView(title: "Skills", items: store.items(.skill))
                case .servers: ItemListView(title: "MCP Servers", items: store.items(.mcpServer))
                case .neverUsed: ItemListView(title: "Never Used", items: store.neverUsed)
                case .notInstalled: GhostListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.canvas)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Agent", selection: $store.agent) {
                    Text("All agents").tag(Agent?.none)
                    ForEach(Agent.allCases, id: \.self) { Text($0.rawValue).tag(Agent?.some($0)) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem {
                Button { store.refresh() } label: { Label("Scan again", systemImage: "arrow.clockwise") }
                    .disabled(store.isScanning)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private func badge(for section: Section) -> Int {
        switch section {
        case .overview: 0
        case .skills: store.items(.skill).count
        case .servers: store.items(.mcpServer).count
        case .neverUsed: store.neverUsed.count
        case .notInstalled: store.ghosts.count
        }
    }
}

// MARK: Overview

struct OverviewView: View {
    @Binding var section: Section

    var body: some View {
        ScrollView { OverviewContent(section: $section) }
    }
}

struct OverviewContent: View {
    @Environment(Store.self) private var store
    @Binding var section: Section

    var body: some View {
        let skills = store.items(.skill), servers = store.items(.mcpServer)
        let usedSkills = skills.filter { $0.uses > 0 }.count
        VStack(alignment: .leading, spacing: Theme.Space.md) {
                hero(used: usedSkills, total: skills.count, idleServers: servers.filter { $0.uses == 0 }.count)
                HStack(spacing: Theme.Space.sm) {
                    StatTile(label: "Skills", value: "\(usedSkills)/\(skills.count)", detail: "used at least once")
                    StatTile(label: "MCP servers", value: "\(servers.filter { $0.uses > 0 }.count)/\(servers.count)", detail: "used at least once")
                    StatTile(label: "Sessions", value: "\(store.sessions)", detail: "since \(Format.day(store.firstSeen))")
                    StatTile(label: "Not installed", value: "\(store.ghosts.count)", detail: "built-in or removed tools")
                }
                HStack(alignment: .top, spacing: Theme.Space.sm) {
                    mostUsed(skills + servers)
                    neverUsedBySource
                }
        }
        .padding(Theme.Space.lg)
    }

    private func hero(used: Int, total: Int, idleServers: Int) -> some View {
        ZStack {
            ShaderView(kind: .aurora)
            HStack(spacing: Theme.Space.lg) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Eyebrow(text: "\(store.sessions) sessions since \(Format.day(store.firstSeen))")
                    Text(store.hasData ? "\(used) of \(total) skills used" : "Scanning your agents")
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.Palette.text)
                    Text(store.hasData
                         ? "\(total - used) skills and \(idleServers) MCP servers are installed but have never run."
                         : "Reading local session logs. Nothing leaves this Mac.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Review never used") { section = .neverUsed }
                        .buttonStyle(InkButtonStyle())
                        .padding(.top, Theme.Space.xs)
                }
                Spacer(minLength: 0)
                ShaderView(kind: .radar(blips: store.blips()), scopeRadius: 78)
                    .frame(width: 184, height: 184)
                    .clipShape(.circle)
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            }
            .padding(Theme.Space.xl)
        }
        .frame(height: 248)
        .clipShape(.rect(cornerRadius: Theme.Radius.hero))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.hero).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private func mostUsed(_ items: [ItemReport]) -> some View {
        let top = items.filter { $0.uses > 0 }.sorted { $0.uses > $1.uses }.prefix(8)
        let peak = Double(top.first?.uses ?? 1)
        return Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Eyebrow(text: "Most used")
                ForEach(Array(top)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.item.displayName).font(Theme.Font.body).foregroundStyle(Theme.Palette.text).lineLimit(1)
                            if let source = row.item.sourcePill { Pill(text: source) }
                            Spacer()
                            Text("\(row.uses)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary)
                        }
                        UsageBar(fraction: Double(row.uses) / peak)
                    }
                }
                if top.isEmpty { EmptyNote(text: "No usage recorded yet.") }
            }
        }
    }

    private var neverUsedBySource: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Eyebrow(text: "Never used, by source")
                    Spacer()
                    Pill(text: "\(store.neverUsed.count)", tone: .idle)
                }
                ForEach(store.neverUsedBySource.prefix(8), id: \.source) { group in
                    HStack {
                        Text(group.source).font(Theme.Font.body).foregroundStyle(Theme.Palette.text).lineLimit(1)
                        Spacer()
                        Text("\(group.count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .frame(minHeight: 22)
                }
                if store.neverUsedBySource.isEmpty { EmptyNote(text: "Everything installed has been used.") }
            }
        }
    }
}

struct EmptyNote: View {
    var text: String
    var body: some View {
        Text(text).font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
    }
}

// MARK: Lists

enum SortOrder: String, CaseIterable, Identifiable {
    case mostUsed = "Most used"
    case recent = "Last used"
    case name = "Name"
    var id: Self { self }
}

struct ItemListView: View {
    var title: String
    var items: [ItemReport]
    @State private var query = ""

    var body: some View {
        ScrollView { ItemListContent(title: title, items: items, query: query) }
            .searchable(text: $query, placement: .toolbar, prompt: "Filter by name or source")
    }
}

struct ItemListContent: View {
    @Environment(Store.self) private var store
    var title: String
    var items: [ItemReport]
    var query: String
    @State private var order: SortOrder = .mostUsed

    var body: some View {
        let rows = sorted(items.filter { query.isEmpty || $0.item.displayName.localizedCaseInsensitiveContains(query) || $0.item.sourceLabel.localizedCaseInsensitiveContains(query) })
        let peak = Double(items.map(\.uses).max() ?? 1)
        VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(Theme.Font.title).foregroundStyle(Theme.Palette.text)
                    Text("\(rows.count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textTertiary)
                    Spacer()
                    Picker("Sort", selection: $order) {
                        ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Card(padding: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            ItemRow(row: row, peak: peak, showAgent: store.agent == nil)
                            if row.id != rows.last?.id { Divider().overlay(Theme.Palette.hairline).padding(.leading, Theme.Space.md) }
                        }
                        if rows.isEmpty {
                            EmptyNote(text: query.isEmpty ? "Nothing here." : "No matches for \"\(query)\".")
                                .padding(Theme.Space.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
        }
        .padding(Theme.Space.lg)
    }

    private func sorted(_ rows: [ItemReport]) -> [ItemReport] {
        switch order {
        case .mostUsed: rows.sorted { ($0.uses, $1.item.displayName) > ($1.uses, $0.item.displayName) }
        case .recent: rows.sorted { ($0.lastUsed ?? .distantPast, $1.item.displayName) > ($1.lastUsed ?? .distantPast, $0.item.displayName) }
        case .name: rows.sorted { $0.item.displayName.localizedStandardCompare($1.item.displayName) == .orderedAscending }
        }
    }
}

struct ItemRow: View {
    var row: ItemReport
    var peak: Double
    var showAgent: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Circle()
                .fill(row.uses > 0 ? Theme.Palette.accent : Theme.Palette.idle)
                .frame(width: 6, height: 6)
            Text(row.item.displayName).font(Theme.Font.body).foregroundStyle(Theme.Palette.text).lineLimit(1)
            if let source = row.item.sourcePill { Pill(text: source) }
            if showAgent { Pill(text: row.item.agent.rawValue, tone: .quiet) }
            if !row.item.enabled { Pill(text: "disabled", tone: .idle) }
            Spacer(minLength: Theme.Space.sm)
            UsageBar(fraction: Double(row.uses) / max(peak, 1)).frame(width: 72)
            Text("\(row.uses)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 44, alignment: .trailing)
            Text(row.lastUsed.map { Format.ago($0) } ?? "never").font(Theme.Font.caption)
                .foregroundStyle(row.lastUsed == nil ? Theme.Palette.idle : Theme.Palette.textTertiary)
                .frame(width: 84, alignment: .trailing)
            IconButton(systemImage: "folder", help: "Show in Finder") { reveal() }
                .opacity(hovering && row.item.path != nil ? 1 : 0)
        }
        .padding(.horizontal, Theme.Space.md)
        .frame(height: 40)
        .background(hovering ? Theme.Palette.sunken.opacity(0.6) : .clear)
        .onHover { hovering = $0 }
    }

    private func reveal() {
        guard let path = row.item.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

struct GhostListView: View {
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Text("Not Installed").font(Theme.Font.title).foregroundStyle(Theme.Palette.text)
                    Text("Tools your agents called that no config on this Mac declares: built-in tools, claude.ai connectors, or things since removed.")
                        .font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                }
                Card(padding: 0) {
                    LazyVStack(spacing: 0) {
                        let rows = store.ghosts
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, entry in
                            HStack(spacing: Theme.Space.sm) {
                                Text(entry.ghost.displayName).font(Theme.Font.body).foregroundStyle(Theme.Palette.text).lineLimit(1)
                                Pill(text: entry.ghost.kind == .skill ? "skill" : "mcp")
                                if store.agent == nil { Pill(text: entry.agent.rawValue, tone: .quiet) }
                                Spacer()
                                Text("\(entry.ghost.uses)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary)
                                Text(Format.ago(entry.ghost.lastUsed)).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                                    .frame(width: 84, alignment: .trailing)
                            }
                            .padding(.horizontal, Theme.Space.md)
                            .frame(height: 40)
                            if index < rows.count - 1 { Divider().overlay(Theme.Palette.hairline).padding(.leading, Theme.Space.md) }
                        }
                        if rows.isEmpty { EmptyNote(text: "Nothing here.").padding(Theme.Space.md).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }
            }
            .padding(Theme.Space.lg)
        }
    }
}
