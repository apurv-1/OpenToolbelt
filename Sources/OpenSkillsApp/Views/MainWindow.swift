import OpenSkillsCore
import SwiftUI

struct MainWindow: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch store.page {
                case .skills(let filter): SkillsPage(filter: filter)
                case .mcpServers: MCPServersPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.canvas)
        }
        .sheet(isPresented: $store.showingAddSkill) {
            AddSkillSheet().environment(store)
        }
        .frame(minWidth: 960, minHeight: 600)
    }
}

// MARK: Sidebar

struct Sidebar: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: MenuBarIcon.image).renderingMode(.template)
                    .foregroundStyle(Theme.Palette.accent)
                Text("OpenSkills").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.text)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 14)

            List(selection: $store.page) {
                Section {
                    item("All skills", symbol: "square.stack", count: store.rows.count, page: .skills(.all))
                    item("External", symbol: "shippingbox", count: store.rows(.external).count, page: .skills(.external))
                    item("Never used", symbol: "moon", count: store.rows(.idle).count, page: .skills(.idle))
                }
                Section("Agents") {
                    ForEach(store.columns) { column in
                        HStack(spacing: 8) {
                            AgentIcon(agent: column.agent, size: 14)
                                .opacity(column.detected ? 1 : 0.4)
                            Text(column.agent.displayName)
                                .foregroundStyle(column.detected ? Theme.Palette.text : Theme.Palette.textTertiary)
                            Spacer()
                            Text(column.detected ? "\(store.rows(.agent(column.agent)).count)" : "not found")
                                .font(Theme.Font.number)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                        .tag(Page.skills(.agent(column.agent)))
                    }
                }
                Section("Tools") {
                    item("MCP servers", symbol: "point.3.connected.trianglepath.dotted", count: store.mcpServers.count, page: .mcpServers)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Hairline()
            HStack {
                Text(store.isScanning ? "Scanning…" : "Scanned \(Format.ago(store.lastScan))")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                Spacer()
                IconButton(systemImage: "arrow.clockwise", help: "Scan again (⌘R)") { store.refresh() }
                    .keyboardShortcut("r")
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
        }
    }

    private func item(_ title: String, symbol: String, count: Int, page: Page) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary).frame(width: 14)
            Text(title).foregroundStyle(Theme.Palette.text)
            Spacer()
            Text("\(count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textTertiary)
        }
        .tag(page)
    }
}

// MARK: Page chrome

/// Title, count, search and the primary action, in one 52pt bar.
struct PageHeader<Trailing: View>: View {
    var title: String
    var count: Int
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Text(title).font(Theme.Font.title).foregroundStyle(Theme.Palette.text)
            Text("\(count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textTertiary)
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: Theme.Size.header)
    }
}
