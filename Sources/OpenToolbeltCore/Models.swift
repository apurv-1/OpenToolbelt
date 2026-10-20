import Foundation

/// Coding agents, keyed by their `npx skills` agent id.
public enum Agent: String, Codable, Sendable, CaseIterable {
    case claudeCode = "claude-code"
    case codex
    case cursor
    case opencode
    case windsurf
    case geminiCLI = "gemini-cli"

    public var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .opencode: "OpenCode"
        case .windsurf: "Windsurf"
        case .geminiCLI: "Gemini CLI"
        }
    }

    /// Global skill folders, relative to home, as `npx skills -g` installs them
    /// (vercel-labs/skills docs/agents.md). Codex also reads its older folder.
    public var skillDirectories: [String] {
        switch self {
        case .claudeCode: [".claude/skills"]
        case .codex: [".agents/skills", ".codex/skills"]
        case .cursor: [".cursor/skills"]
        case .opencode: [".config/opencode/skills"]
        case .windsurf: [".codeium/windsurf/skills"]
        case .geminiCLI: [".gemini/skills"]
        }
    }

    /// Where agents without usage logs keep their MCP servers: a JSON file and
    /// the key holding the server map. Claude Code and Codex are read in full
    /// by their own scanners instead.
    var mcpConfig: (path: String, key: String)? {
        switch self {
        case .claudeCode, .codex: nil
        case .cursor: (".cursor/mcp.json", "mcpServers")
        case .opencode: (".config/opencode/opencode.json", "mcp")
        case .windsurf: (".codeium/windsurf/mcp_config.json", "mcpServers")
        case .geminiCLI: (".gemini/settings.json", "mcpServers")
        }
    }

    /// A folder whose presence means the agent is set up on this Mac.
    var homeMarker: String {
        switch self {
        case .claudeCode: ".claude"
        case .codex: ".codex"
        case .cursor: ".cursor"
        case .opencode: ".config/opencode"
        case .windsurf: ".codeium/windsurf"
        case .geminiCLI: ".gemini"
        }
    }

    /// Whether OpenToolbelt can read this agent's session logs for usage.
    public var tracksUsage: Bool { self == .claudeCode || self == .codex }
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
}

public struct ItemReport: Codable, Sendable, Identifiable {
    public var item: InstalledItem
    public var uses: Int
    public var lastUsed: Date?

    public var id: String { "\(item.agent.rawValue)|\(item.kind.rawValue)|\(item.name)|\(item.scope.label)" }
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
