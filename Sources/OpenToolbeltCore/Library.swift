import Foundation

/// Where a skill or MCP server came from.
public enum Origin: Hashable, Sendable {
    /// A skill installed with `npx skills add`, tracked in `~/.agents/.skill-lock.json`.
    case external(source: String, url: String?)
    /// Shipped inside a Claude Code plugin, which can bundle skills and MCP servers.
    case plugin(String)
    /// A skill synced from claude.ai.
    case synced
    /// A skill shipped with the agent itself.
    case builtIn(Agent)
    /// A skill folder someone put there by hand.
    case local
    /// An MCP server listed in an agent's config file.
    case configured
}

/// One item's state in one agent.
public struct Cell: Sendable, Equatable {
    public var installed = false
    /// nil when the agent's logs are not readable, so usage is unknown.
    public var uses: Int?
    public var lastUsed: Date?
}

/// A skill or an MCP server, with its state in every agent.
public struct LibraryRow: Sendable, Identifiable {
    public var kind: ItemKind
    /// Skills: the folder name, as `npx skills` and the lockfile name it.
    /// MCP servers: the server name people recognize.
    public var name: String
    /// The name agents use for it: `slack:slack-search` for a plugin skill,
    /// `plugin_slack_slack` for a plugin MCP server.
    public var invocation: String
    public var summary: String?
    public var origin: Origin
    public var installedAt: Date?
    public var paths: [String] = []
    public var cells: [Agent: Cell] = [:]
    /// False when it is on disk but switched off, such as a disabled plugin.
    public var enabled = true

    public var id: String { "\(kind)|\(origin)|\(invocation)" }

    /// Rough tokens a skill adds to every session: agents list each skill's
    /// name and description up front so the model can pick one. Estimated at
    /// four characters per token. Zero for MCP servers, whose tool lists we
    /// cannot see without starting them.
    public var contextTokens: Int {
        kind == .skill ? (invocation.count + (summary?.count ?? 0) + 16) / 4 : 0
    }

    public var totalUses: Int { cells.values.compactMap(\.uses).reduce(0, +) }
    public var lastUsed: Date? { cells.values.compactMap(\.lastUsed).max() }
    public var installedAgents: [Agent] { Agent.allCases.filter { cells[$0]?.installed == true } }
    /// Installed in at least one agent whose usage we can read, and used in none.
    public var isIdle: Bool {
        enabled && totalUses == 0 && cells.contains { $0.key.tracksUsage && $0.value.installed }
    }
}

public struct AgentColumn: Sendable, Identifiable {
    public var agent: Agent
    public var detected: Bool
    public var sessions: Int?
    public var firstSeen: Date?
    public var id: Agent { agent }
}

/// Every skill and MCP server on the Mac, across every supported agent.
public struct Library: Sendable {
    public var agents: [AgentColumn]
    public var rows: [LibraryRow]

    /// Skills an agent loads at the start of each session.
    public func loaded(by agent: Agent) -> [LibraryRow] {
        rows.filter { $0.kind == .skill && $0.enabled && $0.cells[agent]?.installed == true }
    }

    /// Estimated tokens of skill listings an agent carries into every
    /// session, and how much of that is skills it has never used.
    public func contextTokens(_ agent: Agent) -> (total: Int, idle: Int) {
        let loaded = loaded(by: agent)
        let idle = loaded.filter { $0.cells[agent]?.uses == 0 }
        return (loaded.map(\.contextTokens).reduce(0, +), idle.map(\.contextTokens).reduce(0, +))
    }

    static func build(home: URL, claudeInventory: [InstalledItem], reports: [AgentReport], usage: [Agent: UsageScan]) -> Library {
        var rows: [String: LibraryRow] = [:]

        func upsertSkill(_ key: String, name: String, invocation: String, origin: Origin, agent: Agent?, path: String?) {
            var row = rows[key] ?? LibraryRow(kind: .skill, name: name, invocation: invocation, origin: origin)
            if let agent { row.cells[agent, default: Cell()].installed = true }
            if let path, !row.paths.contains(path) {
                row.paths.append(path)
                if row.summary == nil {
                    row.summary = SkillFile.frontmatter("description", in: URL(fileURLWithPath: path).appendingPathComponent("SKILL.md"))
                }
            }
            rows[key] = row
        }

        // External skills first, so each keeps its source even if no agent has it yet.
        for entry in SkillLock.read(home: home) {
            upsertSkill(entry.name, name: entry.name, invocation: entry.name,
                        origin: .external(source: entry.source, url: entry.sourceURL), agent: nil, path: nil)
            rows[entry.name]?.installedAt = entry.installedAt
        }

        // Each agent's global skill folders. Folder name is the identity, as in the lockfile.
        for agent in Agent.allCases {
            for directory in agent.skillDirectories {
                for dir in Files.subdirectories(of: home.appendingPathComponent(directory)) where dir.lastPathComponent != "synced" {
                    let file = dir.appendingPathComponent("SKILL.md")
                    guard Files.exists(file) else { continue }
                    let folder = dir.lastPathComponent
                    upsertSkill(folder, name: folder, invocation: SkillFile.frontmatter("name", in: file) ?? folder,
                                origin: rows[folder]?.origin ?? .local, agent: agent, path: dir.path)
                }
            }
        }
        // Cursor ships its own skills in a separate folder.
        for skill in SkillFile.skills(in: home.appendingPathComponent(".cursor/skills-cursor")) {
            upsertSkill("cursor-builtin/\(skill.url.lastPathComponent)", name: skill.url.lastPathComponent, invocation: skill.name,
                        origin: .builtIn(.cursor), agent: .cursor, path: skill.url.path)
        }
        // Claude Code plugin and claude.ai skills, from the Claude inventory.
        for item in claudeInventory where item.kind == .skill {
            let origin: Origin
            switch item.scope {
            case .plugin(let plugin): origin = .plugin(plugin)
            case .synced: origin = .synced
            default: continue
            }
            upsertSkill("claude/\(item.name)", name: item.name, invocation: item.name, origin: origin, agent: .claudeCode, path: item.path)
            rows["claude/\(item.name)"]?.enabled = item.enabled
        }

        // MCP servers from Claude Code and Codex, with usage. Servers with the
        // same name and origin merge into one row, such as one server
        // configured in several projects.
        for report in reports {
            for entry in report.items where entry.item.kind == .mcpServer {
                let item = entry.item
                let origin: Origin = if case .plugin(let plugin) = item.scope { .plugin(plugin) } else { .configured }
                let name = item.displayName
                let key = "mcp/\(origin)/\(name)"
                var row = rows[key] ?? LibraryRow(kind: .mcpServer, name: name, invocation: item.name, origin: origin)
                var cell = row.cells[report.agent] ?? Cell(installed: true, uses: 0)
                cell.uses = (cell.uses ?? 0) + entry.uses
                cell.lastUsed = [cell.lastUsed, entry.lastUsed].compactMap { $0 }.max()
                row.cells[report.agent] = cell
                row.enabled = row.enabled && item.enabled
                if let path = item.path, !row.paths.contains(path) { row.paths.append(path) }
                rows[key] = row
            }
        }
        // MCP servers from agents we only read config for. Usage is unknown.
        for agent in Agent.allCases {
            guard let config = agent.mcpConfig else { continue }
            let url = home.appendingPathComponent(config.path)
            let servers = (Files.json(url)?[config.key] as? [String: Any]) ?? [:]
            for name in servers.keys {
                let key = "mcp/\(Origin.configured)/\(name)"
                var row = rows[key] ?? LibraryRow(kind: .mcpServer, name: name, invocation: name, origin: .configured)
                row.cells[agent, default: Cell()].installed = true
                if !row.paths.contains(url.path) { row.paths.append(url.path) }
                rows[key] = row
            }
        }

        // Skill usage, for the agents whose logs we read.
        var columns: [AgentColumn] = []
        for agent in Agent.allCases {
            let detected = Files.exists(home.appendingPathComponent(agent.homeMarker))
            guard agent.tracksUsage, let scan = usage[agent] else {
                columns.append(AgentColumn(agent: agent, detected: detected))
                continue
            }
            columns.append(AgentColumn(agent: agent, detected: detected, sessions: scan.sessions, firstSeen: scan.firstSeen))
            let events = Dictionary(grouping: scan.events.filter { $0.kind == .skill }, by: \.name)
            for key in rows.keys where rows[key]?.kind == .skill {
                guard var cell = rows[key]?.cells[agent], cell.installed, let row = rows[key] else { continue }
                let matching = events[row.invocation] ?? []
                cell.uses = matching.count
                cell.lastUsed = matching.compactMap(\.timestamp).max()
                rows[key]?.cells[agent] = cell
            }
        }

        return Library(agents: columns, rows: rows.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }
}

extension InstalledItem {
    /// The name people recognize. Plugin MCP servers drop their
    /// `plugin_<plugin>_` prefix, since the plugin is shown alongside.
    public var displayName: String {
        if kind == .mcpServer, case .plugin(let plugin) = scope, name.hasPrefix("plugin_\(plugin)_") {
            return String(name.dropFirst("plugin_\(plugin)_".count))
        }
        return name
    }
}

/// Reads the lockfile `npx skills` keeps for global installs.
enum SkillLock {
    struct Entry {
        var name: String
        var source: String
        var sourceURL: String?
        var installedAt: Date?
    }

    static func read(home: URL) -> [Entry] {
        let json = Files.json(home.appendingPathComponent(".agents/.skill-lock.json"))
        let skills = (json?["skills"] as? [String: [String: Any]]) ?? [:]
        return skills.keys.sorted().compactMap { name in
            guard let entry = skills[name], let source = entry["source"] as? String else { return nil }
            return Entry(name: name, source: source, sourceURL: entry["sourceUrl"] as? String,
                         installedAt: Timestamps.parse(entry["installedAt"]))
        }
    }
}
