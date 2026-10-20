import Foundation

/// Where a skill came from.
public enum SkillOrigin: Hashable, Sendable {
    /// Installed with `npx skills add`, tracked in `~/.agents/.skill-lock.json`.
    case external(source: String, url: String?)
    /// Shipped inside a Claude Code plugin.
    case plugin(String)
    /// Synced from claude.ai.
    case synced
    /// Shipped with the agent itself.
    case builtIn(Agent)
    /// A folder someone put there by hand.
    case local
}

/// One skill's state in one agent.
public struct SkillCell: Sendable, Equatable {
    public var installed = false
    /// nil when the agent's logs are not readable, so usage is unknown.
    public var uses: Int?
    public var lastUsed: Date?
}

public struct SkillRow: Sendable, Identifiable {
    /// The folder name, which is how `npx skills` and the lockfile name it.
    public var name: String
    /// The name agents invoke it by, e.g. `slack:slack-search` for a plugin skill.
    public var invocation: String
    public var summary: String?
    public var origin: SkillOrigin
    public var installedAt: Date?
    public var paths: [String] = []
    public var cells: [Agent: SkillCell] = [:]
    /// False for skills in a disabled Claude Code plugin: on disk, but not loaded.
    public var enabled = true

    public var id: String { "\(origin)|\(invocation)" }

    /// Rough tokens this skill adds to every session: agents list each
    /// skill's name and description up front so the model can pick one.
    /// Estimated at four characters per token.
    public var contextTokens: Int { (invocation.count + (summary?.count ?? 0) + 16) / 4 }

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

/// Every skill on the Mac, across every supported agent.
public struct SkillMatrix: Sendable {
    public var agents: [AgentColumn]
    public var rows: [SkillRow]

    /// Skills an agent loads at the start of each session.
    public func loaded(by agent: Agent) -> [SkillRow] {
        rows.filter { $0.enabled && $0.cells[agent]?.installed == true }
    }

    /// Estimated tokens of skill listings an agent carries into every
    /// session, and how much of that is skills it has never used.
    public func contextTokens(_ agent: Agent) -> (total: Int, idle: Int) {
        let loaded = loaded(by: agent)
        let idle = loaded.filter { $0.cells[agent]?.uses == 0 }
        return (loaded.map(\.contextTokens).reduce(0, +), idle.map(\.contextTokens).reduce(0, +))
    }

    public static func build(home: URL, claudeInventory: [InstalledItem], usage: [Agent: UsageScan]) -> SkillMatrix {
        let lock = SkillLock.read(home: home)
        var rows: [String: SkillRow] = [:]

        func upsert(_ key: String, name: String, invocation: String, origin: SkillOrigin, agent: Agent?, path: String?) {
            var row = rows[key] ?? SkillRow(name: name, invocation: invocation, origin: origin)
            if let agent { row.cells[agent, default: SkillCell()].installed = true }
            if let path, !row.paths.contains(path) {
                row.paths.append(path)
                if row.summary == nil { row.summary = SkillFile.frontmatter("description", in: URL(fileURLWithPath: path).appendingPathComponent("SKILL.md")) }
            }
            rows[key] = row
        }

        // External skills first, so each keeps its source even if no agent has it yet.
        for entry in lock {
            upsert(entry.name, name: entry.name, invocation: entry.name,
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
                    let invocation = SkillFile.frontmatter("name", in: file) ?? folder
                    upsert(folder, name: folder, invocation: invocation, origin: rows[folder]?.origin ?? .local,
                           agent: agent, path: dir.path)
                }
            }
        }
        // Cursor ships its own skills in a separate folder.
        for skill in SkillFile.skills(in: home.appendingPathComponent(".cursor/skills-cursor")) {
            upsert("cursor-builtin/\(skill.url.lastPathComponent)", name: skill.url.lastPathComponent, invocation: skill.name,
                   origin: .builtIn(.cursor), agent: .cursor, path: skill.url.path)
        }
        // Claude Code plugin and claude.ai skills, from the Claude inventory.
        for item in claudeInventory where item.kind == .skill {
            let origin: SkillOrigin
            switch item.scope {
            case .plugin(let plugin): origin = .plugin(plugin)
            case .synced: origin = .synced
            default: continue
            }
            upsert("claude/\(item.name)", name: item.name, invocation: item.name, origin: origin, agent: .claudeCode, path: item.path)
            rows["claude/\(item.name)"]?.enabled = item.enabled
        }

        // Usage, for the agents whose logs we read.
        var columns: [AgentColumn] = []
        for agent in Agent.allCases {
            let detected = Files.exists(home.appendingPathComponent(agent.homeMarker))
            guard agent.tracksUsage, let scan = usage[agent] else {
                columns.append(AgentColumn(agent: agent, detected: detected))
                continue
            }
            columns.append(AgentColumn(agent: agent, detected: detected, sessions: scan.sessions, firstSeen: scan.firstSeen))
            let events = Dictionary(grouping: scan.events.filter { $0.kind == .skill }, by: \.name)
            for key in rows.keys {
                guard var cell = rows[key]?.cells[agent], cell.installed, let row = rows[key] else { continue }
                let matching = events[row.invocation] ?? []
                cell.uses = matching.count
                cell.lastUsed = matching.compactMap(\.timestamp).max()
                rows[key]?.cells[agent] = cell
            }
        }

        return SkillMatrix(agents: columns, rows: rows.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
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
