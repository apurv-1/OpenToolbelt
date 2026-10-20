import Foundation
import Observation
import OpenSkillsCore

/// Holds the latest audit and runs scans off the main thread.
@MainActor @Observable
final class Store {
    private(set) var reports: [AgentReport] = []
    private(set) var isScanning = false
    private(set) var lastScan: Date?
    /// nil shows every agent.
    var agent: Agent?

    func refresh() {
        guard !isScanning else { return }
        isScanning = true
        Task {
            let reports = await Task.detached(priority: .userInitiated) { Audit.run() }.value
            apply(reports)
            isScanning = false
        }
    }

    func apply(_ reports: [AgentReport]) {
        self.reports = reports
        lastScan = .now
    }

    private var visible: [AgentReport] {
        reports.filter { agent == nil || $0.agent == agent }
    }

    func items(_ kind: ItemKind) -> [ItemReport] {
        visible.flatMap(\.items).filter { $0.item.kind == kind }
    }

    var neverUsed: [ItemReport] {
        visible.flatMap(\.neverUsed)
    }

    var ghosts: [(agent: Agent, ghost: GhostReport)] {
        visible.flatMap { report in report.ghosts.map { (report.agent, $0) } }
    }

    var sessions: Int { visible.map(\.sessions).reduce(0, +) }

    var firstSeen: Date? { visible.compactMap(\.firstSeen).min() }

    var hasData: Bool { lastScan != nil }

    /// Never-used items grouped by where they came from, largest group first.
    /// Project-scoped items form one group, since folder names say little.
    var neverUsedBySource: [(source: String, count: Int)] {
        Dictionary(grouping: neverUsed, by: { $0.item.groupLabel })
            .map { ($0.key, $0.value.count) }
            .sorted { ($0.count, $1.source) > ($1.count, $0.source) }
    }

    func blips() -> [Blip] {
        let all = visible.flatMap(\.items)
        let used = all.filter { $0.uses > 0 }.sorted { $0.uses > $1.uses }.prefix(10)
        let idle = all.filter { $0.uses == 0 }.prefix(6)
        return used.map { Blip(name: $0.item.name, used: true) } + idle.map { Blip(name: $0.item.name, used: false) }
    }
}

extension InstalledItem {
    /// The name people recognize. Plugin MCP servers drop their
    /// `plugin_<plugin>_` prefix, since the source pill already says it.
    var displayName: String {
        if kind == .mcpServer, case .plugin(let plugin) = scope, name.hasPrefix("plugin_\(plugin)_") {
            return String(name.dropFirst("plugin_\(plugin)_".count))
        }
        return name
    }

    /// The source pill, or nil when it would only repeat the name.
    var sourcePill: String? {
        sourceLabel == displayName ? nil : sourceLabel
    }

    var groupLabel: String {
        if case .project = scope { return "project skills" }
        return sourceLabel
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

extension GhostReport {
    /// claude.ai connectors show up as bare UUIDs; give them a readable label.
    var displayName: String {
        name.range(of: #"^[0-9a-f]{8}-[0-9a-f]{4}-"#, options: .regularExpression) != nil
            ? "connector \(name.prefix(8))" : name
    }
}

enum Format {
    static func day(_ date: Date?) -> String {
        date?.formatted(.dateTime.month(.abbreviated).day()) ?? "-"
    }

    static func ago(_ date: Date?) -> String {
        guard let date else { return "never" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
