import Foundation

public enum Agent: String, Codable, Sendable, CaseIterable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
}

public enum ItemKind: String, Codable, Sendable {
    case skill
    case mcpServer = "mcp"
}

/// Where an installed item comes from. Project-scoped items only count usage
/// from sessions whose working directory is inside that project.
public enum Scope: Codable, Sendable, Hashable {
    case user
    case project(String)
    case plugin(String)
    case synced

    public var label: String {
        switch self {
        case .user: "user"
        case .project(let path): "project \(path)"
        case .plugin(let name): "plugin \(name)"
        case .synced: "synced"
        }
    }
}

public struct InstalledItem: Codable, Sendable, Hashable {
    public var agent: Agent
    public var kind: ItemKind
    /// The name as it appears in transcripts: the `Skill` tool's `skill`
    /// input, or the server segment of `mcp__<server>__<tool>`.
    public var name: String
    public var scope: Scope
    public var path: String?
    public var enabled: Bool
}

public struct UsageEvent: Sendable {
    public var agent: Agent
    public var kind: ItemKind
    public var name: String
    public var timestamp: Date?
    public var cwd: String?
    /// True when the name came from prompt text (`/name`, `$name`) rather than
    /// a tool call. Such names count only if they match an installed item,
    /// since built-in commands like `/model` look the same.
    public var viaPrompt: Bool
}

public struct UsageScan: Sendable {
    public var events: [UsageEvent] = []
    public var sessions = 0
    public var firstSeen: Date?
    public var lastSeen: Date?

    mutating func see(_ date: Date?) {
        guard let date else { return }
        if firstSeen.map({ date < $0 }) ?? true { firstSeen = date }
        if lastSeen.map({ date > $0 }) ?? true { lastSeen = date }
    }

    mutating func merge(_ other: UsageScan) {
        events += other.events
        sessions += other.sessions
        see(other.firstSeen)
        see(other.lastSeen)
    }
}

public struct ItemReport: Codable, Sendable {
    public var item: InstalledItem
    public var uses: Int
    public var lastUsed: Date?
}

/// Something the transcripts used that no scanned config declares: a built-in
/// or connector tool, or an item that was since removed or renamed.
public struct GhostReport: Codable, Sendable {
    public var kind: ItemKind
    public var name: String
    public var uses: Int
    public var lastUsed: Date?
}

public struct AgentReport: Codable, Sendable {
    public var agent: Agent
    public var items: [ItemReport]
    public var ghosts: [GhostReport]
    public var sessions: Int
    public var firstSeen: Date?
    public var lastSeen: Date?

    public var neverUsed: [ItemReport] { items.filter { $0.uses == 0 } }
}
