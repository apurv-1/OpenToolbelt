import Foundation

public struct AuditResult: Sendable {
    /// Per-agent installed-vs-used reports for the agents whose logs we read.
    public var agents: [AgentReport]
    /// Every skill and MCP server across every supported agent.
    public var library: Library
    /// Skill and MCP calls per day, oldest first.
    public var activity: [DailyActivity]
    public var insights: [Insight] { Insights.compute(self) }
}

public struct DailyActivity: Sendable, Identifiable {
    public var day: Date
    public var skillCalls: Int
    public var mcpCalls: Int
    public var id: Date { day }

    /// Counts calls per calendar day for the `days` days ending today.
    static func daily(_ events: [UsageEvent], days: Int, now: Date, calendar: Calendar = .current) -> [DailyActivity] {
        let today = calendar.startOfDay(for: now)
        var buckets: [Date: (Int, Int)] = [:]
        for event in events {
            guard let timestamp = event.timestamp else { continue }
            let day = calendar.startOfDay(for: timestamp)
            var bucket = buckets[day] ?? (0, 0)
            if event.kind == .skill { bucket.0 += 1 } else { bucket.1 += 1 }
            buckets[day] = bucket
        }
        return (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { day in
                DailyActivity(day: day, skillCalls: buckets[day]?.0 ?? 0, mcpCalls: buckets[day]?.1 ?? 0)
            }
        }
    }
}

/// Joins what is installed with what the transcripts show was used.
public enum Audit {
    public static func run(home: URL = FileManager.default.homeDirectoryForCurrentUser, now: Date = .now) -> AuditResult {
        let claude = ClaudeCode(home: home)
        let codex = Codex(home: home)
        let claudeInventory = claude.inventory()
        let claudeUsage = claude.usage(), codexUsage = codex.usage()
        let reports = [
            report(.claudeCode, installed: claudeInventory, scan: claudeUsage),
            report(.codex, installed: codex.inventory(), scan: codexUsage),
        ]
        return AuditResult(
            agents: reports,
            library: Library.build(home: home, claudeInventory: claudeInventory, reports: reports,
                                   usage: [.claudeCode: claudeUsage, .codex: codexUsage]),
            activity: DailyActivity.daily(claudeUsage.events + codexUsage.events, days: 30, now: now)
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
