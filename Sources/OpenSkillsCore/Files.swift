import Foundation

enum Files {
    static var fm: FileManager { .default }

    static func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    static func subdirectories(of url: URL) -> [URL] {
        let urls = (try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return urls.filter { $0.resolvingSymlinksInPath().hasDirectoryPath || isDirectory($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.resolvingSymlinksInPath().path, isDirectory: &isDir) && isDir.boolValue
    }

    static func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// All `*.jsonl` files under `root`, including nested subagent transcripts.
    static func jsonlFiles(under root: URL) -> [URL] {
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
    }

    /// Calls `body` with each newline-separated line of the file whose bytes
    /// contain at least one of `markers`, so the caller only JSON-decodes lines
    /// that can matter. Transcripts run to hundreds of megabytes.
    static func forEachLine(in url: URL, containingAny markers: [String], _ body: (Data) -> Void) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return }
        let needles = markers.map { Array($0.utf8) }
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var start = 0
            let count = raw.count
            while start < count {
                let end = memchr(base + start, 0x0A, count - start)
                    .map { UnsafeRawPointer($0) - base } ?? count
                let length = end - start
                if length > 0, needles.contains(where: { needle in
                    needle.withUnsafeBytes { memmem(base + start, length, $0.baseAddress, $0.count) != nil }
                }) {
                    body(Data(bytes: base + start, count: length))
                }
                start = end + 1
            }
        }
    }
}

enum SkillFile {
    /// The `name:` from a SKILL.md frontmatter, or nil when absent.
    static func frontmatterName(_ url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            if trimmed.hasPrefix("name:") {
                let value = trimmed.dropFirst("name:".count)
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Skill directories (each holding a SKILL.md) directly inside `root`.
    static func skills(in root: URL) -> [(name: String, url: URL)] {
        Files.subdirectories(of: root).compactMap { dir in
            let file = dir.appendingPathComponent("SKILL.md")
            guard Files.exists(file) else { return nil }
            return (frontmatterName(file) ?? dir.lastPathComponent, dir)
        }
    }
}

enum Timestamps {
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    static func parse(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return fractional.date(from: string) ?? plain.date(from: string)
    }
}

enum ToolNames {
    /// The server segment of an MCP tool name such as `mcp__treg__call`.
    static func mcpServer(_ toolName: String) -> String? {
        guard toolName.hasPrefix("mcp__") else { return nil }
        let rest = toolName.dropFirst("mcp__".count)
        guard let end = rest.range(of: "__") else { return nil }
        let server = rest[..<end.lowerBound]
        return server.isEmpty ? nil : String(server)
    }
}
