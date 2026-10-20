import Foundation
import Observation
import OpenSkillsCore

/// What the skills screen is showing.
enum SkillFilter: Hashable {
    case all
    case external
    case idle
    case agent(Agent)
    /// Loaded by one agent every session, never used there.
    case idleIn(Agent)
}

enum Page: Hashable {
    case overview
    case skills(SkillFilter)
    case mcpServers
}

/// Holds the latest audit and runs scans off the main thread.
@MainActor @Observable
final class Store {
    private(set) var result: AuditResult?
    private(set) var isScanning = false
    private(set) var lastScan: Date?
    var page: Page = .overview
    var showingAddSkill = false
    /// The `npx skills` runner shared by the add and remove flows.
    let cli = SkillsCLI()

    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { Audit.run() }.value
            apply(result)
            isScanning = false
        }
    }

    func apply(_ result: AuditResult) {
        self.result = result
        lastScan = .now
    }

    var rows: [SkillRow] { result?.skills.rows ?? [] }
    var columns: [AgentColumn] { result?.skills.agents ?? [] }
    var detectedAgents: [Agent] { columns.filter(\.detected).map(\.agent) }

    func rows(_ filter: SkillFilter) -> [SkillRow] {
        switch filter {
        case .all: rows
        case .external: rows.filter(\.isExternal)
        case .idle: rows.filter(\.isIdle)
        case .agent(let agent): rows.filter { $0.cells[agent]?.installed == true }
        case .idleIn(let agent): (result?.skills.loaded(by: agent) ?? []).filter { $0.cells[agent]?.uses == 0 }
        }
    }

    var externalSources: Int {
        Set(rows.compactMap { if case .external(let source, _) = $0.origin { source } else { nil } }).count
    }

    var mcpServers: [(agent: Agent, item: ItemReport)] {
        (result?.agents ?? []).flatMap { report in
            report.items.filter { $0.item.kind == .mcpServer }.map { (report.agent, $0) }
        }
    }

    var sessions: Int { columns.compactMap(\.sessions).reduce(0, +) }
    var firstSeen: Date? { columns.compactMap(\.firstSeen).min() }

    func blips() -> [Blip] {
        let used = rows.filter { $0.totalUses > 0 }.sorted { $0.totalUses > $1.totalUses }.prefix(10)
        let idle = rows.filter(\.isIdle).prefix(6)
        return used.map { Blip(name: $0.name, used: true) } + idle.map { Blip(name: $0.name, used: false) }
    }
}

extension SkillRow {
    var isExternal: Bool {
        if case .external = origin { return true }
        return false
    }
}

/// Groups of rows as the matrix shows them: one per external source, then
/// hand-made, plugin, claude.ai and built-in skills.
struct SkillSection: Identifiable {
    var title: String
    var subtitle: String
    var link: URL?
    var rows: [SkillRow]
    var collapsedByDefault: Bool
    var id: String { subtitle + "/" + title }

    static func group(_ rows: [SkillRow]) -> [SkillSection] {
        var external: [String: [SkillRow]] = [:], links: [String: URL] = [:]
        var local: [SkillRow] = [], plugins: [String: [SkillRow]] = [:], synced: [SkillRow] = []
        var builtIn: [Agent: [SkillRow]] = [:]
        for row in rows {
            switch row.origin {
            case .external(let source, let url):
                external[source, default: []].append(row)
                if let url, url.hasPrefix("http"), let link = URL(string: url.replacingOccurrences(of: ".git", with: "")) {
                    links[source] = link
                }
            case .local: local.append(row)
            case .plugin(let plugin): plugins[plugin, default: []].append(row)
            case .synced: synced.append(row)
            case .builtIn(let agent): builtIn[agent, default: []].append(row)
            }
        }
        var sections = external.keys.sorted().map {
            SkillSection(title: $0, subtitle: "npx skills", link: links[$0], rows: external[$0]!, collapsedByDefault: false)
        }
        if !local.isEmpty {
            sections.append(SkillSection(title: "Local", subtitle: "added by hand", rows: local, collapsedByDefault: false))
        }
        sections += plugins.keys.sorted().map {
            SkillSection(title: $0, subtitle: "Claude Code plugin", rows: plugins[$0]!, collapsedByDefault: true)
        }
        if !synced.isEmpty {
            sections.append(SkillSection(title: "claude.ai", subtitle: "synced", rows: synced, collapsedByDefault: true))
        }
        sections += builtIn.keys.sorted { $0.rawValue < $1.rawValue }.map {
            SkillSection(title: $0.displayName, subtitle: "built in", rows: builtIn[$0]!, collapsedByDefault: true)
        }
        return sections
    }
}

extension InstalledItem {
    /// Plugin MCP servers drop their `plugin_<plugin>_` prefix for display.
    var displayName: String {
        if kind == .mcpServer, case .plugin(let plugin) = scope, name.hasPrefix("plugin_\(plugin)_") {
            return String(name.dropFirst("plugin_\(plugin)_".count))
        }
        return name
    }

    var sourceLabel: String {
        switch scope {
        case .user: "user"
        case .project(let path): URL(fileURLWithPath: path).lastPathComponent
        case .plugin(let plugin): plugin
        case .synced: "claude.ai"
        }
    }
}

enum Format {
    static func day(_ date: Date?) -> String {
        date?.formatted(.dateTime.month(.abbreviated).day()) ?? "-"
    }

    /// 6588 -> "6.6k".
    static func tokens(_ count: Int) -> String {
        count < 1000 ? "\(count)" : String(format: "%.1fk", Double(count) / 1000)
    }

    /// "a", "a and b", "a, b and c".
    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    static func ago(_ date: Date?) -> String {
        guard let date else { return "never" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
