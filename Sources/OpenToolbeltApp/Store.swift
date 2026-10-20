import Foundation
import Observation
import OpenToolbeltCore

/// What the library screen is showing.
enum LibraryFilter: Hashable {
    case all
    case skills
    case mcpServers
    case idle
    case agent(Agent)
    /// Skills one agent loads every session but never used there.
    case idleIn(Agent)
}

enum Page: Hashable {
    case overview
    case library(LibraryFilter)
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

    var rows: [LibraryRow] { result?.library.rows ?? [] }
    var columns: [AgentColumn] { result?.library.agents ?? [] }
    var detectedAgents: [Agent] { columns.filter(\.detected).map(\.agent) }

    func rows(_ filter: LibraryFilter) -> [LibraryRow] {
        switch filter {
        case .all: rows
        case .skills: rows.filter { $0.kind == .skill }
        case .mcpServers: rows.filter { $0.kind == .mcpServer }
        case .idle: rows.filter(\.isIdle)
        case .agent(let agent): rows.filter { $0.cells[agent]?.installed == true }
        case .idleIn(let agent): (result?.library.loaded(by: agent) ?? []).filter { $0.cells[agent]?.uses == 0 }
        }
    }

    /// MCP servers configured in an agent whose usage we can read.
    var trackedServers: [LibraryRow] {
        rows(.mcpServers).filter { row in row.cells.contains { $0.key.tracksUsage && $0.value.installed } }
    }

    var sessions: Int { columns.compactMap(\.sessions).reduce(0, +) }
    var firstSeen: Date? { columns.compactMap(\.firstSeen).min() }

    func blips() -> [Blip] {
        let used = rows.filter { $0.totalUses > 0 }.sorted { $0.totalUses > $1.totalUses }.prefix(10)
        let idle = rows.filter(\.isIdle).prefix(6)
        return used.map { Blip(name: $0.name, used: true) } + idle.map { Blip(name: $0.name, used: false) }
    }
}

extension LibraryRow {
    var isExternal: Bool {
        if case .external = origin { return true }
        return false
    }
}

/// Groups of rows as the library shows them: external repos, plugins,
/// configured MCP servers, hand-made skills, then synced and built-in skills.
struct LibrarySection: Identifiable {
    enum Icon { case symbol(String), agent(Agent) }

    var title: String
    /// What the group is, shown on hover.
    var kind: String
    var icon: Icon
    var link: URL?
    var rows: [LibraryRow]
    var collapsedByDefault: Bool
    var id: String { kind + "/" + title }

    /// "8 skills · 1 MCP", naming each kind the group holds.
    var contents: String {
        let skills = rows.filter { $0.kind == .skill }.count, servers = rows.count - skills
        return [skills > 0 ? "\(skills) \(skills == 1 ? "skill" : "skills")" : nil, servers > 0 ? "\(servers) MCP" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }

    static func group(_ rows: [LibraryRow]) -> [LibrarySection] {
        var external: [String: [LibraryRow]] = [:], links: [String: URL] = [:]
        var plugins: [String: [LibraryRow]] = [:], configured: [LibraryRow] = [], local: [LibraryRow] = []
        var synced: [LibraryRow] = [], builtIn: [Agent: [LibraryRow]] = [:]
        for row in rows {
            switch row.origin {
            case .external(let source, let url):
                external[source, default: []].append(row)
                if let url, url.hasPrefix("http"), let link = URL(string: url.replacingOccurrences(of: ".git", with: "")) {
                    links[source] = link
                }
            case .plugin(let plugin): plugins[plugin, default: []].append(row)
            case .configured: configured.append(row)
            case .local: local.append(row)
            case .synced: synced.append(row)
            case .builtIn(let agent): builtIn[agent, default: []].append(row)
            }
        }
        // Within a group, MCP servers sit above skills.
        func ordered(_ rows: [LibraryRow]) -> [LibraryRow] {
            rows.sorted { ($0.kind == .mcpServer ? 0 : 1, $0.name) < ($1.kind == .mcpServer ? 0 : 1, $1.name) }
        }
        var sections = external.keys.sorted().map {
            LibrarySection(title: $0, kind: "Installed with npx skills", icon: .symbol("arrow.down.circle"),
                           link: links[$0], rows: ordered(external[$0]!), collapsedByDefault: false)
        }
        sections += plugins.keys.sorted().map {
            LibrarySection(title: $0, kind: "Claude Code plugin", icon: .symbol("puzzlepiece.extension"),
                           rows: ordered(plugins[$0]!), collapsedByDefault: true)
        }
        if !configured.isEmpty {
            sections.append(LibrarySection(title: "MCP servers", kind: "From agent config files", icon: .symbol("powerplug"),
                                           rows: configured, collapsedByDefault: false))
        }
        if !local.isEmpty {
            sections.append(LibrarySection(title: "Local skills", kind: "Added by hand", icon: .symbol("folder"),
                                           rows: local, collapsedByDefault: false))
        }
        if !synced.isEmpty {
            sections.append(LibrarySection(title: "claude.ai", kind: "Synced from claude.ai", icon: .symbol("icloud"),
                                           rows: synced, collapsedByDefault: true))
        }
        sections += builtIn.keys.sorted { $0.rawValue < $1.rawValue }.map {
            LibrarySection(title: "\($0.displayName) built-in", kind: "Ships with \($0.displayName)", icon: .agent($0),
                           rows: builtIn[$0]!, collapsedByDefault: true)
        }
        return sections
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
