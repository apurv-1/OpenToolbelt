import Charts
import OpenSkillsCore
import SwiftUI

/// The dashboard: what agents carry, what they use, and what to do about it.
struct OverviewPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            OverviewContent()
                .padding(Theme.Space.lg)
                .frame(maxWidth: 1040)
                .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
        .navigationSubtitle(store.firstSeen.map { "since \(Format.day($0))" } ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.showingAddSkill = true } label: { Label("Add skills", systemImage: "plus") }
                    .keyboardShortcut("n")
                    .help("Add skills (⌘N)")
            }
        }
    }
}

struct OverviewContent: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            MetricStrip()
            if let result = store.result {
                ActivityPanel(activity: result.activity)
                SuggestionsPanel(insights: result.insights)
                MostUsedPanel()
            }
        }
    }
}

/// A titled surface with a hairline edge.
struct DashboardPanel<Content: View, Accessory: View>: View {
    var title: String
    var detail: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Palette.text)
                if let detail { Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary) }
                Spacer()
                accessory
            }
            .padding(.horizontal, Theme.Space.md)
            .frame(height: 40)
            Hairline()
            content
        }
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.panel))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }
}

extension DashboardPanel where Accessory == EmptyView {
    init(title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, detail: detail, accessory: { EmptyView() }, content: content)
    }
}

// MARK: Metrics

struct MetricStrip: View {
    @Environment(Store.self) private var store

    var body: some View {
        let context = contextAgent
        let servers = store.mcpServers
        HStack(spacing: 0) {
            metric("Context per session", value: context.map { Format.tokens($0.cost.total) } ?? "–",
                   detail: context.map { "\(Format.tokens($0.cost.idle)) from unused skills" } ?? "No usage logs yet",
                   detailTone: (context?.cost.idle ?? 0) > 0 ? Theme.Palette.idle : Theme.Palette.textTertiary,
                   agent: context?.agent)
            divider
            metric("Skills in use", value: "\(store.rows.filter { $0.totalUses > 0 }.count) / \(store.rows.filter(\.enabled).count)",
                   detail: "enabled skills used at least once")
            divider
            metric("MCP servers in use", value: "\(servers.filter { $0.item.uses > 0 }.count) / \(servers.count)",
                   detail: "Claude Code and Codex")
            divider
            metric("Sessions", value: "\(store.sessions)", detail: "since \(Format.day(store.firstSeen))")
        }
        .frame(height: 96)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.panel))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }

    /// The tracked agent that carries the most skill context.
    private var contextAgent: (agent: Agent, cost: (total: Int, idle: Int))? {
        guard let matrix = store.result?.skills else { return nil }
        return store.detectedAgents.filter(\.tracksUsage)
            .map { ($0, matrix.contextTokens($0)) }
            .max { $0.1.total < $1.1.total }
    }

    private var divider: some View {
        Rectangle().fill(Theme.Palette.hairline).frame(width: 1).padding(.vertical, Theme.Space.md)
    }

    private func metric(_ label: String, value: String, detail: String, detailTone: Color = Theme.Palette.textTertiary,
                        agent: Agent? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary)
                if let agent { AgentIcon(agent: agent, size: 11) }
            }
            Text(value).font(.system(size: 24, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.Palette.text)
            Text(detail).font(Theme.Font.caption).foregroundStyle(detailTone).lineLimit(1)
        }
        .padding(.horizontal, Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Activity

struct ActivityPanel: View {
    var activity: [DailyActivity]

    var body: some View {
        DashboardPanel(title: "Activity", detail: "skill and MCP calls, last 30 days") {
            HStack(spacing: 12) {
                key(Theme.Palette.accent, "Skills")
                key(Theme.Palette.textTertiary.opacity(0.6), "MCP")
            }
        } content: {
            Chart(activity) { day in
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Calls", day.mcpCalls))
                    .foregroundStyle(Theme.Palette.textTertiary.opacity(0.45))
                    .cornerRadius(2)
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Calls", day.skillCalls))
                    .foregroundStyle(Theme.Palette.accent)
                    .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Theme.Palette.hairline)
                    AxisValueLabel().font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .frame(height: 150)
            .padding(Theme.Space.md)
        }
    }

    private func key(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
        }
    }
}

// MARK: Suggestions

struct SuggestionsPanel: View {
    @Environment(Store.self) private var store
    var insights: [Insight]

    var body: some View {
        DashboardPanel(title: "Suggestions", detail: insights.isEmpty ? nil : "\(insights.count)") {
            VStack(spacing: 0) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    SuggestionRow(insight: insight)
                    if index < insights.count - 1 { Hairline().padding(.leading, 48) }
                }
                if insights.isEmpty {
                    Text("Nothing to tidy. Every installed skill and server is pulling its weight.")
                        .font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.md)
                }
            }
        }
    }
}

struct SuggestionRow: View {
    @Environment(Store.self) private var store
    var insight: Insight

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.sm) {
            icon.frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.Font.bodyMedium).foregroundStyle(Theme.Palette.text)
                Text(detail).font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.md)
            if let impact {
                Text(impact).font(Theme.Font.number).foregroundStyle(Theme.Palette.accent)
            }
            Button(actionTitle, action: act).buttonStyle(GhostButtonStyle())
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, 12)
    }

    @ViewBuilder private var icon: some View {
        switch insight.kind {
        case .pruneIdle(let agent, _, _), .idleServers(let agent, _): AgentIcon(agent: agent, size: 18)
        case .spread(_, _, let agents): AgentIcon(agent: agents.first ?? .claudeCode, size: 18)
        case .staleLock:
            Image(systemName: "exclamationmark.circle").font(.system(size: 15)).foregroundStyle(Theme.Palette.idle)
        }
    }

    private var title: String {
        switch insight.kind {
        case .pruneIdle(let agent, let skills, _):
            "Trim \(skills.count) unused \(skills.count == 1 ? "skill" : "skills") from \(agent.displayName)"
        case .spread(let skill, _, let agents):
            "Use \(skill) in \(Format.list(agents.map(\.displayName)))"
        case .staleLock(let skills):
            "\(skills.count) lockfile \(skills.count == 1 ? "entry points" : "entries point") at nothing"
        case .idleServers(let agent, let servers):
            "\(servers.count) MCP \(servers.count == 1 ? "server was" : "servers were") never called in \(agent.displayName)"
        }
    }

    private var detail: String {
        switch insight.kind {
        case .pruneIdle(_, let skills, _):
            "Every session loads their descriptions so the model can pick one. Largest: \(Format.list(Array(skills.prefix(3))))."
        case .spread(_, let source, _):
            "You already use it, and it is installed elsewhere. One install from \(source) adds it here too."
        case .staleLock(let skills):
            "\(Format.list(skills)) \(skills.count == 1 ? "is" : "are") in the npx skills lockfile but not installed in any agent."
        case .idleServers(_, let servers):
            "\(Format.list(Array(servers.prefix(4)))). Unused servers still start up and add their tools to the model's options."
        }
    }

    private var impact: String? {
        if case .pruneIdle(_, _, let tokens) = insight.kind { return "−\(Format.tokens(tokens)) tokens" }
        return nil
    }

    private var actionTitle: String {
        switch insight.kind {
        case .pruneIdle, .idleServers: "Review"
        case .spread: "Install"
        case .staleLock: "Clean up"
        }
    }

    private func act() {
        switch insight.kind {
        case .pruneIdle(let agent, _, _):
            store.page = .skills(.idleIn(agent))
        case .idleServers:
            store.page = .mcpServers
        case .spread(let skill, let source, let agents):
            store.cli.run(SkillsCommand.add(source: source, skills: [skill], agents: agents)) { store.refresh() }
            store.showingAddSkill = true
        case .staleLock(let skills):
            store.cli.run(SkillsCommand.remove(skills: skills)) { store.refresh() }
            store.showingAddSkill = true
        }
    }
}

// MARK: Most used

struct MostUsedPanel: View {
    @Environment(Store.self) private var store

    var body: some View {
        let skills = store.rows.filter { $0.totalUses > 0 }.sorted { $0.totalUses > $1.totalUses }
            .map { (name: $0.invocation, kind: "skill", uses: $0.totalUses, agents: $0.installedAgents) }
        let servers = store.mcpServers.filter { $0.item.uses > 0 }
            .map { (name: $0.item.item.displayName, kind: "MCP", uses: $0.item.uses, agents: [$0.agent]) }
        let top = (skills + servers).sorted { $0.uses > $1.uses }.prefix(8)
        let peak = Double(top.first?.uses ?? 1)
        DashboardPanel(title: "Most used", detail: "skills and MCP servers") {
            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: Theme.Space.sm) {
                        Text(entry.name).font(Theme.Font.bodyMedium).foregroundStyle(Theme.Palette.text).lineLimit(1)
                        Text(entry.kind).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                        Spacer()
                        HStack(spacing: 4) { ForEach(entry.agents, id: \.self) { AgentIcon(agent: $0, style: .mono, size: 11).opacity(0.6) } }
                        Capsule().fill(Theme.Palette.raised).frame(width: 120, height: 4)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.Palette.accent).frame(width: max(3, 120 * Double(entry.uses) / peak), height: 4)
                            }
                        Text("\(entry.uses)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .frame(height: Theme.Size.row)
                }
                if top.isEmpty {
                    Text("No usage yet.").font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.Space.md)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
