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

@Suite struct SkillMatrixTests {
    let home = FakeHome()

    init() throws {
        let h = home
        try h.write(".agents/.skill-lock.json", h.json(["version": 3, "skills": [
            "shared": ["source": "acme/skills", "sourceUrl": "https://github.com/acme/skills.git", "installedAt": "2026-09-01T00:00:00.000Z"],
            "dropped": ["source": "acme/skills"],
        ]]))
        // npx skills keeps the canonical copy in ~/.agents/skills and links it per agent.
        try h.skill(".agents/skills/shared", name: "shared")
        try FileManager.default.createDirectory(at: h.root.appendingPathComponent(".claude/skills"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: h.root.appendingPathComponent(".claude/skills/shared"),
                                                   withDestinationURL: h.root.appendingPathComponent(".agents/skills/shared"))
        try h.skill(".cursor/skills/handmade", name: "handmade")
        try h.skill(".cursor/skills-cursor/review", name: "review")
        try h.write(".claude/projects/-work/s1.jsonl", h.toolUse("t1", "Skill", ["skill": "shared"]))
    }

    func matrix() -> SkillMatrix { Audit.run(home: home.root).skills }

    @Test func externalSkillsKeepTheirSourceAndPerAgentState() throws {
        let rows = matrix().rows
        let shared = try #require(rows.first { $0.name == "shared" })
        #expect(shared.origin == .external(source: "acme/skills", url: "https://github.com/acme/skills.git"))
        #expect(shared.installedAgents == [.claudeCode, .codex])
        #expect(shared.cells[.claudeCode]?.uses == 1)
        #expect(shared.cells[.codex]?.uses == 0)
        #expect(shared.installedAt != nil)

        let dropped = try #require(rows.first { $0.name == "dropped" })
        #expect(dropped.installedAgents.isEmpty)  // in the lockfile, gone from disk
    }

    @Test func otherSkillsAreLocalOrBuiltInWithUnknownUsage() throws {
        let rows = matrix().rows
        let handmade = try #require(rows.first { $0.name == "handmade" })
        #expect(handmade.origin == .local)
        #expect(handmade.cells[.cursor] == SkillCell(installed: true, uses: nil, lastUsed: nil))
        #expect(rows.first { $0.name == "review" }?.origin == .builtIn(.cursor))
    }

    @Test func detectsAgentsByTheirHomeFolder() {
        let detected = matrix().agents.filter(\.detected).map(\.agent)
        #expect(detected == [.claudeCode, .cursor])
    }
}

@Suite struct SkillsCommandTests {
    @Test func addInstallsGloballyForChosenAgents() {
        #expect(SkillsCommand.add(source: "acme/skills", skills: [], agents: [.claudeCode, .cursor]) ==
                ["skills", "add", "acme/skills", "--global", "--yes", "--agent", "claude-code", "--agent", "cursor", "--skill", "*"])
        #expect(SkillsCommand.add(source: "acme/skills", skills: ["one"], agents: [.codex]).suffix(2) == ["--skill", "one"])
    }

    @Test func shellLineQuotesUserInput() {
        let line = SkillsCommand.shellLine(["skills", "add", "x'; rm -rf ~; echo '"])
        #expect(line == #"'npx' '--yes' 'skills' 'add' 'x'\''; rm -rf ~; echo '\'''"#)
    }
}

@Suite struct InsightsTests {
    let home = FakeHome()

    init() throws {
        let h = home
        try h.write(".agents/.skill-lock.json", h.json(["skills": [
            "loved": ["source": "acme/skills"],
            "gone": ["source": "acme/skills"],
        ]]))
        try h.write(".claude/skills/loved/SKILL.md", "---\nname: loved\ndescription: |\n  Two lines\n  of description.\n---\n")
        try h.skill(".claude/skills/idle", name: "idle")
        try h.skill(".cursor/skills/other", name: "other")
        try h.write(".claude.json", h.json(["mcpServers": ["quiet": [:]],
                                            "projects": ["/a": ["mcpServers": ["quiet": [:]]]]]))
        try h.write(".claude/projects/-work/s1.jsonl", h.toolUse("t1", "Skill", ["skill": "loved"]))
    }

    @Test func blockScalarDescriptionsAreRead() throws {
        let row = try #require(Audit.run(home: home.root).skills.rows.first { $0.name == "loved" })
        #expect(row.summary == "Two lines of description.")
    }

    @Test func suggestsPruningSpreadingAndCleanup() throws {
        let insights = Audit.run(home: home.root).insights
        guard case .pruneIdle(let agent, let skills, let tokens) = insights.first?.kind else {
            Issue.record("expected prune first"); return
        }
        #expect(agent == .claudeCode)
        #expect(skills == ["idle"])
        #expect(tokens > 0)
        #expect(insights.contains { if case .spread("loved", "acme/skills", [.cursor]) = $0.kind { true } else { false } })
        #expect(insights.contains { if case .staleLock(["gone"]) = $0.kind { true } else { false } })
        #expect(insights.contains { if case .idleServers(.claudeCode, ["quiet"]) = $0.kind { true } else { false } })
    }

    @Test func dailyActivityBucketsByDay() {
        let now = ISO8601DateFormatter().date(from: "2026-10-02T12:00:00Z")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let events = [
            UsageEvent(agent: .claudeCode, kind: .skill, name: "a", timestamp: now, cwd: nil, viaPrompt: false),
            UsageEvent(agent: .claudeCode, kind: .mcpServer, name: "b", timestamp: now.addingTimeInterval(-86400), cwd: nil, viaPrompt: false),
        ]
        let days = DailyActivity.daily(events, days: 3, now: now, calendar: calendar)
        #expect(days.map(\.skillCalls) == [0, 0, 1])
        #expect(days.map(\.mcpCalls) == [0, 1, 0])
    }
}
