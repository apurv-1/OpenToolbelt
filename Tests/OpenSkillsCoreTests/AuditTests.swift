import Foundation
import Testing
@testable import OpenSkillsCore

/// Builds a throwaway home directory shaped like a real Claude Code + Codex setup.
struct FakeHome {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("openskills-\(UUID().uuidString)")

    func write(_ path: String, _ text: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func skill(_ dir: String, name: String) throws {
        try write("\(dir)/SKILL.md", "---\nname: \(name)\ndescription: test\n---\nbody\n")
    }

    func json(_ object: Any) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
    }

    func toolUse(_ id: String, _ name: String, _ input: [String: Any] = [:], cwd: String = "/work") -> String {
        json(["type": "assistant", "timestamp": "2026-10-01T10:00:00.000Z", "cwd": cwd,
              "message": ["content": [["type": "tool_use", "id": id, "name": name, "input": input]]]])
    }

    func prompt(_ text: String) -> String {
        json(["type": "user", "timestamp": "2026-10-02T10:00:00.000Z", "cwd": "/work",
              "message": ["content": text]])
    }
}

@Suite struct AuditTests {
    let home = FakeHome()

    init() throws {
        let h = home
        try h.skill(".claude/skills/alpha", name: "alpha")
        try h.skill(".claude/skills/beta", name: "beta")
        try h.skill(".claude/skills/unused", name: "unused")
        try h.skill(".claude/skills/synced/bucket-1/docs", name: "docs")
        try h.write(".claude.json", h.json([
            "mcpServers": ["treg": [:]],
            // The home directory itself often shows up as a project.
            "projects": ["/p": ["mcpServers": ["local": [:]]], h.root.path: [:]],
        ]))
        let plugin = h.root.appendingPathComponent("plugin-cache/slack").path
        try h.write(".claude/plugins/installed_plugins.json", h.json([
            "plugins": ["slack@official": [["scope": "user", "installPath": plugin]]],
        ]))
        try h.write(".claude/settings.json", h.json(["enabledPlugins": ["slack@official": false]]))
        try h.write("plugin-cache/slack/.claude-plugin/plugin.json", "{}")
        try h.skill("plugin-cache/slack/skills/search", name: "slack-search")
        try h.write("plugin-cache/slack/.mcp.json", h.json(["slack": [:]]))  // bare map, no `mcpServers`

        try h.write(".claude/projects/-work/s1.jsonl", [
            h.toolUse("t1", "Skill", ["skill": "alpha"]),
            h.toolUse("t1", "Skill", ["skill": "alpha"]),  // same block written twice
            h.toolUse("t2", "mcp__treg__call"),
            h.toolUse("t3", "mcp__plugin_slack_slack__send"),
            h.toolUse("t4", "mcp__Claude_Browser__navigate"),
            h.toolUse("t5", "mcp__local__x", cwd: "/elsewhere"),
            h.toolUse("t6", "mcp__local__x", cwd: "/p/sub"),
            h.prompt("<command-name>/beta</command-name>"),
            h.prompt("<command-name>/model</command-name>"),
            "not json",
        ].joined(separator: "\n"))
        try h.write(".claude/projects/-work/s1/subagents/agent-1.jsonl",
                    h.toolUse("t7", "Skill", ["skill": "anthropic-skills:docs"]))

        try h.skill(".codex/skills/treg", name: "treg")
        try h.write(".codex/config.toml", """
            model = "x"
            [mcp_servers.node_repl]
            command = "node"
            [mcp_servers.node_repl.env]
            enabled = false
            [mcp_servers.computer-use]
            enabled = false
            """)
        try h.write(".codex/sessions/2026/10/01/rollout-1.jsonl", [
            h.json(["type": "response_item", "timestamp": "2026-10-01T09:00:00.000Z",
                    "payload": ["type": "message", "role": "user",
                                "content": [["type": "input_text", "text": "use $treg, not $HOME"]]]]),
            h.json(["type": "response_item", "timestamp": "2026-10-01T09:01:00.000Z",
                    "payload": ["type": "custom_tool_call", "name": "exec",
                                "input": "await tools.mcp__node_repl__js({})"]]),
        ].joined(separator: "\n"))
    }

    func uses(_ report: AgentReport, _ name: String) -> Int? {
        report.items.first { $0.item.name == name }?.uses
    }

    @Test func claudeInventoryCoversEveryScope() {
        let items = ClaudeCode(home: home.root).inventory()
        let names = Set(items.map(\.name))
        #expect(names == ["alpha", "beta", "unused", "anthropic-skills:docs", "treg", "local",
                          "slack:slack-search", "plugin_slack_slack"])
        #expect(items.filter { $0.scope == .plugin("slack") }.allSatisfy { !$0.enabled })
        #expect(items.first { $0.name == "local" }?.scope == .project("/p"))
    }

    @Test func claudeUsageJoinsToolCallsAndSlashCommands() {
        let claude = ClaudeCode(home: home.root)
        let report = Audit.report(.claudeCode, installed: claude.inventory(), scan: claude.usage())
        #expect(report.sessions == 1)
        #expect(uses(report, "alpha") == 1)
        #expect(uses(report, "beta") == 1)
        #expect(uses(report, "anthropic-skills:docs") == 1)
        #expect(uses(report, "treg") == 1)
        #expect(uses(report, "plugin_slack_slack") == 1)
        #expect(uses(report, "local") == 1)  // only the call made inside /p
        #expect(report.neverUsed.map(\.item.name) == ["unused", "slack:slack-search"])
        #expect(report.ghosts.map(\.name) == ["Claude_Browser"])  // `/model` is not a ghost
    }

    @Test func codexInventoryAndUsage() {
        let codex = Codex(home: home.root)
        let items = codex.inventory()
        #expect(items.map(\.name) == ["treg", "node_repl", "computer-use"])
        #expect(items.map(\.enabled) == [true, true, false])
        let report = Audit.report(.codex, installed: items, scan: codex.usage())
        #expect(uses(report, "treg") == 1)
        #expect(uses(report, "node_repl") == 1)
        #expect(report.ghosts.isEmpty)
    }

    @Test func mcpServerSegment() {
        #expect(ToolNames.mcpServer("mcp__plugin_aws-core_aws-mcp__aws___run_script") == "plugin_aws-core_aws-mcp")
        #expect(ToolNames.mcpServer("mcp__treg__call") == "treg")
        #expect(ToolNames.mcpServer("Bash") == nil)
    }
}
