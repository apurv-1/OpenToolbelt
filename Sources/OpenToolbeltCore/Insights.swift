import Foundation

/// One concrete thing to do about the skills and servers on this Mac.
public struct Insight: Sendable, Identifiable {
    public enum Kind: Sendable {
        /// Skills an agent loads every session but has never used.
        case pruneIdle(agent: Agent, skills: [String], tokens: Int)
        /// An external skill that gets used, missing from other agents on this Mac.
        case spread(skill: String, source: String, to: [Agent])
        /// Lockfile entries no agent has installed any more.
        case staleLock(skills: [String])
        /// Configured MCP servers that were never called.
        case idleServers(agent: Agent, servers: [String])
    }

    public var kind: Kind
    public var id: String

    init(_ kind: Kind) {
        self.kind = kind
        switch kind {
        case .pruneIdle(let agent, _, _): id = "prune/\(agent.rawValue)"
        case .spread(let skill, _, _): id = "spread/\(skill)"
        case .staleLock: id = "stale"
        case .idleServers(let agent, _): id = "servers/\(agent.rawValue)"
        }
    }
}

public enum Insights {
    /// Suggestions in the order they matter: context weight first, then
    /// getting more out of what works, then housekeeping.
    public static func compute(_ result: AuditResult) -> [Insight] {
        let library = result.library
        let detected = library.agents.filter(\.detected).map(\.agent)
        var insights: [Insight] = []

        let prune = detected.filter(\.tracksUsage).compactMap { agent -> (Insight, Int)? in
            let idle = library.loaded(by: agent).filter { $0.cells[agent]?.uses == 0 }
            guard !idle.isEmpty else { return nil }
            let tokens = idle.map(\.contextTokens).reduce(0, +)
            let names = idle.sorted { $0.contextTokens > $1.contextTokens }.map(\.invocation)
            return (Insight(.pruneIdle(agent: agent, skills: names, tokens: tokens)), tokens)
        }
        insights += prune.sorted { $0.1 > $1.1 }.map(\.0)

        for row in library.rows where row.kind == .skill && row.totalUses > 0 {
            guard case .external(let source, _) = row.origin else { continue }
            let missing = detected.filter { row.cells[$0]?.installed != true }
            if !missing.isEmpty { insights.append(Insight(.spread(skill: row.name, source: source, to: missing))) }
        }

        let stale = library.rows.filter { row in
            if case .external = row.origin { return row.installedAgents.isEmpty }
            return false
        }
        if !stale.isEmpty { insights.append(Insight(.staleLock(skills: stale.map(\.name)))) }

        for agent in detected where agent.tracksUsage {
            let idle = library.rows.filter {
                $0.kind == .mcpServer && $0.enabled && $0.cells[agent]?.installed == true && $0.cells[agent]?.uses == 0
            }
            if !idle.isEmpty { insights.append(Insight(.idleServers(agent: agent, servers: idle.map(\.name)))) }
        }
        return insights
    }
}
