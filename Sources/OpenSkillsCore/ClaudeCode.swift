import Foundation

/// Reads Claude Code's config and transcripts under a home directory.
public struct ClaudeCode: Sendable {
    public var home: URL

    public init(home: URL) { self.home = home }

    var claudeDir: URL { home.appendingPathComponent(".claude") }

    // MARK: Inventory

    public func inventory() -> [InstalledItem] {
        let config = Files.json(home.appendingPathComponent(".claude.json")) ?? [:]
        var items: [InstalledItem] = []

        let skillsDir = claudeDir.appendingPathComponent("skills")
        for skill in SkillFile.skills(in: skillsDir) where skill.url.lastPathComponent != "synced" {
            items.append(skillItem(skill.name, .user, skill.url))
        }
        // Skills synced from claude.ai live in per-account buckets and are
        // invoked under the `anthropic-skills:` namespace.
        for bucket in Files.subdirectories(of: skillsDir.appendingPathComponent("synced")) {
            for skill in SkillFile.skills(in: bucket) {
                items.append(skillItem("anthropic-skills:\(skill.name)", .synced, skill.url))
            }
        }

        for name in mcpNames(config["mcpServers"]) {
            items.append(mcpItem(name, .user, home.appendingPathComponent(".claude.json")))
        }

        let projects = (config["projects"] as? [String: Any]) ?? [:]
        for path in projects.keys.sorted() {
            let project = URL(fileURLWithPath: path)
            // A project at the home directory would re-list the user's own skills.
            guard project.standardizedFileURL != home.standardizedFileURL else { continue }
            for skill in SkillFile.skills(in: project.appendingPathComponent(".claude/skills")) {
                items.append(skillItem(skill.name, .project(path), skill.url))
            }
            let local = (projects[path] as? [String: Any])?["mcpServers"]
            for name in mcpNames(local) {
                items.append(mcpItem(name, .project(path), home.appendingPathComponent(".claude.json")))
            }
            let shared = project.appendingPathComponent(".mcp.json")
            for name in mcpNames(Files.json(shared)?["mcpServers"]) {
                items.append(mcpItem(name, .project(path), shared))
            }
        }

        items += pluginItems()
        return items
    }

    private func pluginItems() -> [InstalledItem] {
        let registry = Files.json(claudeDir.appendingPathComponent("plugins/installed_plugins.json"))
        let plugins = (registry?["plugins"] as? [String: Any]) ?? [:]
        let settings = Files.json(claudeDir.appendingPathComponent("settings.json"))
        let enabledMap = (settings?["enabledPlugins"] as? [String: Bool]) ?? [:]

        var items: [InstalledItem] = []
        for key in plugins.keys.sorted() {
            guard let install = (plugins[key] as? [[String: Any]])?.first,
                  let installPath = install["installPath"] as? String else { continue }
            let plugin = String(key.split(separator: "@").first ?? Substring(key))
            let root = URL(fileURLWithPath: installPath)
            let enabled = enabledMap[key] ?? true
            let manifest = Files.json(root.appendingPathComponent(".claude-plugin/plugin.json")) ?? [:]

            let skillsDir = root.appendingPathComponent((manifest["skills"] as? String) ?? "skills")
            for skill in SkillFile.skills(in: skillsDir) {
                var item = skillItem("\(plugin):\(skill.name)", .plugin(plugin), skill.url)
                item.enabled = enabled
                items.append(item)
            }

            // `mcpServers` is either a path to a JSON file or an inline object.
            let servers: Any?
            if let inline = manifest["mcpServers"] as? [String: Any] {
                servers = inline
            } else {
                let file = root.appendingPathComponent((manifest["mcpServers"] as? String) ?? ".mcp.json")
                // Plugins write `.mcp.json` either wrapped in `mcpServers` or as a bare map.
                let json = Files.json(file)
                servers = json?["mcpServers"] ?? json
            }
            for name in mcpNames(servers) {
                // Plugin MCP tools are named `mcp__plugin_<plugin>_<server>__<tool>`.
                var item = mcpItem("plugin_\(plugin)_\(name)", .plugin(plugin), root)
                item.enabled = enabled
                items.append(item)
            }
        }
        return items
    }

    private func mcpNames(_ value: Any?) -> [String] {
        ((value as? [String: Any]) ?? [:]).keys.sorted()
    }

    private func skillItem(_ name: String, _ scope: Scope, _ url: URL) -> InstalledItem {
        InstalledItem(agent: .claudeCode, kind: .skill, name: name, scope: scope, path: url.path, enabled: true)
    }

    private func mcpItem(_ name: String, _ scope: Scope, _ url: URL) -> InstalledItem {
        InstalledItem(agent: .claudeCode, kind: .mcpServer, name: name, scope: scope, path: url.path, enabled: true)
    }

    // MARK: Usage

    public func usage() -> UsageScan {
        var scan = UsageScan()
        var seenToolUseIDs = Set<String>()
        let root = claudeDir.appendingPathComponent("projects")
        for file in Files.jsonlFiles(under: root) {
            if !file.pathComponents.contains("subagents") {
                scan.sessions += 1
                let values = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                scan.see(values?.creationDate)
                scan.see(values?.contentModificationDate)
            }
            Files.forEachLine(in: file, containingAny: ["\"type\":\"tool_use\"", "<command-name>"]) { line in
                guard let event = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                      let message = event["message"] as? [String: Any] else { return }
                let timestamp = Timestamps.parse(event["timestamp"])
                let cwd = event["cwd"] as? String
                switch event["type"] as? String {
                case "assistant":
                    for block in (message["content"] as? [[String: Any]]) ?? [] where block["type"] as? String == "tool_use" {
                        if let id = block["id"] as? String, !seenToolUseIDs.insert(id).inserted { continue }
                        guard let name = block["name"] as? String else { continue }
                        if name == "Skill", let skill = (block["input"] as? [String: Any])?["skill"] as? String {
                            scan.events.append(UsageEvent(agent: .claudeCode, kind: .skill, name: skill,
                                                          timestamp: timestamp, cwd: cwd, viaPrompt: false))
                        } else if let server = ToolNames.mcpServer(name) {
                            scan.events.append(UsageEvent(agent: .claudeCode, kind: .mcpServer, name: server,
                                                          timestamp: timestamp, cwd: cwd, viaPrompt: false))
                        }
                    }
                case "user":
                    // A typed `/skill-name` is recorded as a <command-name> tag in
                    // the prompt, not as a Skill tool call.
                    for text in Self.texts(message["content"]) {
                        for command in Self.commandNames(in: text) {
                            scan.events.append(UsageEvent(agent: .claudeCode, kind: .skill, name: command,
                                                          timestamp: timestamp, cwd: cwd, viaPrompt: true))
                        }
                    }
                default:
                    break
                }
            }
        }
        return scan
    }

    static func texts(_ content: Any?) -> [String] {
        if let string = content as? String { return [string] }
        return ((content as? [[String: Any]]) ?? []).compactMap { block in
            block["type"] as? String == "text" ? block["text"] as? String : nil
        }
    }

    static func commandNames(in text: String) -> [String] {
        var names: [String] = []
        var rest = text[...]
        while let open = rest.range(of: "<command-name>"),
              let close = rest.range(of: "</command-name>", range: open.upperBound..<rest.endIndex) {
            var name = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("/") { name.removeFirst() }
            if !name.isEmpty { names.append(name) }
            rest = rest[close.upperBound...]
        }
        return names
    }
}
