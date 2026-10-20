import Foundation

/// Reads Codex CLI's config and session rollouts under a home directory.
public struct Codex: Sendable {
    public var home: URL

    public init(home: URL) { self.home = home }

    var codexDir: URL { home.appendingPathComponent(".codex") }

    // MARK: Inventory

    public func inventory() -> [InstalledItem] {
        var items = Agent.codex.skillDirectories
            .flatMap { SkillFile.skills(in: home.appendingPathComponent($0)) }
            .map { InstalledItem(agent: .codex, kind: .skill, name: $0.name, scope: .user, path: $0.url.path, enabled: true) }
        let config = codexDir.appendingPathComponent("config.toml")
        if let text = try? String(contentsOf: config, encoding: .utf8) {
            items += Self.mcpServers(inTOML: text).map {
                InstalledItem(agent: .codex, kind: .mcpServer, name: $0.name, scope: .user,
                              path: config.path, enabled: $0.enabled)
            }
        }
        return items
    }

    /// The `[mcp_servers.<name>]` tables in a Codex config and whether each
    /// sets `enabled = false`. Only reads table headers and that one key, so it
    /// needs no TOML library.
    static func mcpServers(inTOML text: String) -> [(name: String, enabled: Bool)] {
        var servers: [(name: String, enabled: Bool)] = []
        var current: Int?
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                current = nil
                guard line.hasPrefix("[mcp_servers."), line.hasSuffix("]") else { continue }
                var name = String(line.dropFirst("[mcp_servers.".count).dropLast())
                if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 {
                    name = String(name.dropFirst().dropLast())
                } else if name.contains(".") {
                    continue  // a sub-table such as [mcp_servers.x.env]
                }
                servers.append((name, true))
                current = servers.count - 1
            } else if let index = current, line.replacingOccurrences(of: " ", with: "") == "enabled=false" {
                servers[index].enabled = false
            }
        }
        return servers
    }

    // MARK: Usage

    public func usage() -> UsageScan {
        var scan = UsageScan()
        let roots = [codexDir.appendingPathComponent("sessions"), codexDir.appendingPathComponent("archived_sessions")]
        for file in roots.flatMap(Files.jsonlFiles(under:)) {
            scan.sessions += 1
            Files.forEachLine(in: file, containingAny: ["\"response_item\""]) { line in
                guard let event = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                      let payload = event["payload"] as? [String: Any] else { return }
                let timestamp = Timestamps.parse(event["timestamp"])
                scan.see(timestamp)
                func record(_ kind: ItemKind, _ name: String, viaPrompt: Bool) {
                    scan.events.append(UsageEvent(agent: .codex, kind: kind, name: name,
                                                  timestamp: timestamp, cwd: nil, viaPrompt: viaPrompt))
                }
                switch payload["type"] as? String {
                case "message" where payload["role"] as? String == "user":
                    // Codex skills are invoked as `$skill-name` in the prompt.
                    for block in (payload["content"] as? [[String: Any]]) ?? [] {
                        guard let text = block["text"] as? String else { continue }
                        for name in Self.dollarNames(in: text) { record(.skill, name, viaPrompt: true) }
                    }
                case "function_call":
                    if let server = (payload["name"] as? String).flatMap(ToolNames.mcpServer) {
                        record(.mcpServer, server, viaPrompt: false)
                    }
                case "custom_tool_call":
                    // Code-mode calls reach MCP tools as `tools.mcp__<server>__<tool>(...)`.
                    for server in Self.mcpServers(inCode: (payload["input"] as? String) ?? "") {
                        record(.mcpServer, server, viaPrompt: false)
                    }
                default:
                    break
                }
            }
        }
        return scan
    }

    static func dollarNames(in text: String) -> [String] {
        matches(of: #/\$([A-Za-z0-9][A-Za-z0-9_:-]*)/#, in: text)
    }

    static func mcpServers(inCode code: String) -> [String] {
        // Server names may hold single underscores; `__` ends the segment.
        matches(of: #/mcp__([A-Za-z0-9-]+(?:_[A-Za-z0-9-]+)*)__/#, in: code)
    }

    private static func matches(of regex: Regex<(Substring, Substring)>, in text: String) -> [String] {
        text.matches(of: regex).map { String($0.output.1) }
    }
}
