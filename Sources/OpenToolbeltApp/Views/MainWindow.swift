import OpenToolbeltCore
import SwiftUI

/// The window: a custom sidebar and a page, with no native title bar or
/// toolbar. Only the window controls float over the sidebar.
struct MainWindow: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 216)
                .background(Theme.Palette.sidebar)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.Palette.hairline).frame(width: 1)
                }
            Group {
                switch store.page {
                case .overview: OverviewPage()
                case .library(let filter): LibraryPage(filter: filter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.canvas)
        }
        .ignoresSafeArea()
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
        VStack(alignment: .leading, spacing: 0) {
            // Room for the window controls.
            Color.clear.frame(height: 40)

            HStack(spacing: 8) {
                Image(nsImage: MenuBarIcon.image).renderingMode(.template).resizable()
                    .frame(width: 15, height: 15)
                    .foregroundStyle(Theme.Palette.accent)
                Text("OpenToolbelt").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.text)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 1) {
                    SidebarItem(title: "Overview", page: .overview) { symbol("square.grid.2x2") }
                    SidebarItem(title: "Everything", count: store.rows.count, page: .library(.all)) { symbol("square.stack") }
                    SidebarItem(title: "Skills", count: store.rows(.skills).count, page: .library(.skills)) { symbol("doc.text") }
                    SidebarItem(title: "MCP servers", count: store.rows(.mcpServers).count, page: .library(.mcpServers)) { symbol("powerplug") }

                    SidebarLabel(text: "Agents")
                    ForEach(store.columns.filter(\.detected)) { column in
                        SidebarItem(title: column.agent.displayName, count: store.rows(.agent(column.agent)).count,
                                    page: .library(.agent(column.agent))) {
                            AgentIcon(agent: column.agent, size: 14)
                        }
                    }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
            HStack {
                Text(store.isScanning ? "Scanning…" : "Scanned \(Format.ago(store.lastScan))")
                    .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
                Spacer()
                IconButton(systemImage: "arrow.clockwise", help: "Scan again (⌘R)") { store.refresh() }
                    .keyboardShortcut("r")
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 12, weight: .medium))
    }
}

struct SidebarLabel: View {
    var text: String
    var body: some View {
        Text(text).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, 8)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

/// A quiet nav row: no accent fill, just a soft raised background when selected.
struct SidebarItem<Icon: View>: View {
    @Environment(Store.self) private var store
    var title: String
    var count: Int?
    var page: Page
    @ViewBuilder var icon: Icon
    @State private var hovering = false

    var body: some View {
        let selected = store.page == page
        Button { store.page = page } label: {
            HStack(spacing: 9) {
                icon.frame(width: 16).foregroundStyle(selected ? Theme.Palette.text : Theme.Palette.textSecondary)
                Text(title).font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Theme.Palette.text : Theme.Palette.textSecondary)
                Spacer()
                if let count {
                    Text("\(count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(selected ? Theme.Palette.raised : hovering ? Theme.Palette.raised.opacity(0.5) : .clear,
                        in: .rect(cornerRadius: Theme.Radius.row))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: Page chrome

/// The slim bar at the top of every page: title, a quiet detail, and actions.
struct PageBar<Actions: View>: View {
    var title: String
    var detail: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.sm) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Palette.text)
                if let detail {
                    Text(detail).font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textTertiary).lineLimit(1)
                }
                Spacer(minLength: Theme.Space.md)
                actions
            }
            .padding(.horizontal, Theme.Space.lg)
            .frame(height: 52)
            Hairline()
        }
    }
}

struct AddSkillsButton: View {
    @Environment(Store.self) private var store

    var body: some View {
        Button { store.showingAddSkill = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                Text("Add skills")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .keyboardShortcut("n")
        .help("Add skills (⌘N)")
    }
}
