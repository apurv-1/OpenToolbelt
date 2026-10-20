import OpenToolbeltCore
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
                case .overview: OverviewPage()
                case .library(let filter): LibraryPage(filter: filter)
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
                Text("OpenToolbelt").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.text)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 14)

            List(selection: $store.page) {
                Section {
                    item("Overview", symbol: "gauge.with.dots.needle.33percent", count: nil, page: .overview)
                    item("Everything", symbol: "square.stack", count: store.rows.count, page: .library(.all))
                    item("Skills", symbol: "doc.text", count: store.rows(.skills).count, page: .library(.skills))
                    item("MCP servers", symbol: "powerplug", count: store.rows(.mcpServers).count, page: .library(.mcpServers))
                    item("Never used", symbol: "moon", count: store.rows(.idle).count, page: .library(.idle))
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
                        .tag(Page.library(.agent(column.agent)))
                    }
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

    private func item(_ title: String, symbol: String, count: Int?, page: Page) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Theme.Palette.textSecondary).frame(width: 14)
            Text(title).foregroundStyle(Theme.Palette.text)
            Spacer()
            if let count { Text("\(count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textTertiary) }
        }
        .tag(page)
    }
}
