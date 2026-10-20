import Foundation
import OpenToolbeltCore

let started = Date()
let reports = Audit.run().agents

if CommandLine.arguments.contains("--json") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    FileHandle.standardOutput.write(try encoder.encode(reports))
    print()
    exit(0)
}

let day = Date.FormatStyle(date: .abbreviated, time: .omitted)

func when(_ date: Date?) -> String { date.map { $0.formatted(day) } ?? "-" }

func pad(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
}

for report in reports {
    let window = "\(when(report.firstSeen)) to \(when(report.lastSeen))"
    print("\n\(report.agent.displayName): \(report.sessions) sessions, \(window)")

    for kind in [ItemKind.skill, .mcpServer] {
        let items = report.items.filter { $0.item.kind == kind }
            .sorted { ($0.uses, $1.item.name) > ($1.uses, $0.item.name) }
        guard !items.isEmpty else { continue }
        let used = items.filter { $0.uses > 0 }.count
        print("\n  \(kind == .skill ? "Skills" : "MCP servers") (\(used) of \(items.count) used)")
        let width = min(48, (items.map(\.item.name.count).max() ?? 0) + 2)
        for row in items {
            let off = row.item.enabled ? "" : "  [disabled]"
            print("    \(pad(row.item.name, width))\(pad(String(row.uses), 7))\(pad(when(row.lastUsed), 14))\(row.item.scope.label)\(off)")
        }
    }

    if !report.ghosts.isEmpty {
        print("\n  Used but not installed (built-in, connector, or removed)")
        for ghost in report.ghosts.prefix(25) {
            print("    \(pad(ghost.kind == .skill ? "skill" : "mcp", 7))\(pad(ghost.name, 42))\(pad(String(ghost.uses), 7))\(when(ghost.lastUsed))")
        }
        if report.ghosts.count > 25 { print("    ... \(report.ghosts.count - 25) more") }
    }
}

print(String(format: "\nScanned in %.1fs", Date().timeIntervalSince(started)))
