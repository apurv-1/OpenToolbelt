import Foundation

public struct AuditResult: Sendable {
    /// Per-agent installed-vs-used reports for the agents whose logs we read.
    public var agents: [AgentReport]
    /// Every skill across every supported agent.
    public var skills: SkillMatrix
}

/// Joins what is installed with what the transcripts show was used.
public enum Audit {
    public static func run(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> AuditResult {
        let claude = ClaudeCode(home: home)
        let codex = Codex(home: home)
        let claudeInventory = claude.inventory()
        let claudeUsage = claude.usage(), codexUsage = codex.usage()
        return AuditResult(
            agents: [
                report(.claudeCode, installed: claudeInventory, scan: claudeUsage),
                report(.codex, installed: codex.inventory(), scan: codexUsage),
            ],
            skills: SkillMatrix.build(home: home, claudeInventory: claudeInventory,
                                      usage: [.claudeCode: claudeUsage, .codex: codexUsage])
        )
    }

    public static func report(_ agent: Agent, installed: [InstalledItem], scan: UsageScan) -> AgentReport {
        struct Key: Hashable { var kind: ItemKind; var name: String }
        let events = Dictionary(grouping: scan.events.filter { $0.agent == agent }) { Key(kind: $0.kind, name: $0.name) }

        let items = installed.filter { $0.agent == agent }.map { item in
            let matching = (events[Key(kind: item.kind, name: item.name)] ?? []).filter { event in
                guard case .project(let path) = item.scope else { return true }
                return event.cwd.map { $0 == path || $0.hasPrefix(path + "/") } ?? false
            }
            return ItemReport(item: item, uses: matching.count, lastUsed: matching.compactMap(\.timestamp).max())
        }

        let installedKeys = Set(installed.filter { $0.agent == agent }.map { Key(kind: $0.kind, name: $0.name) })
        let ghosts = events
            .filter { key, _ in !installedKeys.contains(key) }
            .compactMap { key, events -> GhostReport? in
                let toolCalls = events.filter { !$0.viaPrompt }
                guard !toolCalls.isEmpty else { return nil }
                return GhostReport(kind: key.kind, name: key.name, uses: toolCalls.count,
                                   lastUsed: toolCalls.compactMap(\.timestamp).max())
            }
            .sorted { ($0.uses, $1.name) > ($1.uses, $0.name) }

        return AgentReport(agent: agent, items: items, ghosts: ghosts, sessions: scan.sessions,
                           firstSeen: scan.firstSeen, lastSeen: scan.lastSeen)
    }
}
