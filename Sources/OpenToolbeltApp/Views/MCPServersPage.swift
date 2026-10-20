import OpenToolbeltCore
import SwiftUI

/// MCP servers from the agents whose config and logs OpenToolbelt reads.
struct MCPServersPage: View {
    @Environment(Store.self) private var store
    @State private var query = ""

    var body: some View {
        let servers = store.mcpServers.filter { query.isEmpty || $0.item.item.displayName.localizedCaseInsensitiveContains(query) }
        ScrollView {
            MCPServerList(servers: servers).padding(.vertical, Theme.Space.xs)
        }
        .navigationTitle("MCP servers")
        .navigationSubtitle("\(servers.count) servers")
        .searchable(text: $query, placement: .toolbar, prompt: "Search servers")
    }
}

struct MCPServerList: View {
    var servers: [(agent: Agent, item: ItemReport)]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Agent.allCases, id: \.self) { agent in
                let rows = servers.filter { $0.agent == agent }.map(\.item)
                    .sorted { ($0.uses, $1.item.displayName) > ($1.uses, $0.item.displayName) }
                if !rows.isEmpty {
                    HStack(spacing: 8) {
                        AgentIcon(agent: agent, size: 14)
                        Text(agent.displayName).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.text)
                        Text("\(rows.count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, MatrixLayout.inset - Theme.Space.xs)
                    .frame(height: 34)
                    .padding(.top, Theme.Space.xs)
                    ForEach(rows) { MCPServerRow(row: $0) }
                }
            }
        }
        .padding(.horizontal, Theme.Space.xs)
    }
}

struct MCPServerRow: View {
    var row: ItemReport
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(state: row.uses > 0 ? .used : .idle).frame(width: 10)
            Text(row.item.displayName).font(Theme.Font.bodyMedium).foregroundStyle(Theme.Palette.text).lineLimit(1)
            Text(row.item.sourceLabel).font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textTertiary).lineLimit(1)
            if !row.item.enabled {
                Text("disabled").font(Theme.Font.caption).foregroundStyle(Theme.Palette.idle)
            }
            Spacer()
            Text(row.uses > 0 ? "\(row.uses)" : "–").font(Theme.Font.number)
                .foregroundStyle(row.uses > 0 ? Theme.Palette.text : Theme.Palette.textTertiary)
                .frame(width: MatrixLayout.uses, alignment: .trailing)
            Text(row.lastUsed.map { Format.ago($0) } ?? "–").font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: MatrixLayout.lastUsed, alignment: .trailing)
        }
        .padding(.horizontal, MatrixLayout.inset - Theme.Space.xs)
        .frame(height: Theme.Size.row)
        .background(hovering ? Theme.Palette.raised : .clear, in: .rect(cornerRadius: Theme.Radius.row))
        .onHover { hovering = $0 }
    }
}
