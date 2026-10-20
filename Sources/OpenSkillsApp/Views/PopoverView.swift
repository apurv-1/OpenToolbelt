import OpenSkillsCore
import SwiftUI

/// The panel that drops down from the menu bar icon.
struct PopoverView: View {
    @Environment(Store.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let skills = store.items(.skill), servers = store.items(.mcpServer)
        VStack(spacing: Theme.Space.sm) {
            hero(skills: skills)
            HStack(spacing: Theme.Space.sm) {
                StatTile(label: "MCP servers", value: "\(servers.filter { $0.uses > 0 }.count)/\(servers.count)", detail: "used")
                StatTile(label: "Sessions", value: "\(store.sessions)", detail: "since \(Format.day(store.firstSeen))")
            }
            neverUsed
            footer
        }
        .padding(Theme.Space.sm)
        .frame(width: 340)
        .background(Theme.Palette.canvas)
    }

    private func hero(skills: [ItemReport]) -> some View {
        ZStack(alignment: .bottomLeading) {
            ShaderView(kind: .radar(blips: store.blips()), scopeCenter: UnitPoint(x: 0.79, y: 0.5), scopeRadius: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("SKILLS USED")
                    .font(Theme.Font.eyebrow).tracking(0.6)
                    .foregroundStyle(Color(nsColor: NSColor(hex: 0x7CF8C8)).opacity(0.8))
                Spacer()
                if store.hasData {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(skills.filter { $0.uses > 0 }.count)").font(Theme.Font.display)
                        Text("of \(skills.count)").font(.system(size: 15, weight: .medium)).opacity(0.55)
                    }
                    Text("across \(store.sessions) sessions").font(Theme.Font.caption).opacity(0.55)
                } else {
                    Text("Scanning transcripts").font(.system(size: 15, weight: .medium))
                    Text("Reading local session logs").font(Theme.Font.caption).opacity(0.55)
                }
            }
            .foregroundStyle(.white)
            .padding(Theme.Space.md)
        }
        .frame(height: 136)
        .clipShape(.rect(cornerRadius: Theme.Radius.hero))
    }

    private var neverUsed: some View {
        Card(padding: Theme.Space.sm + 2) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    Eyebrow(text: "Never used")
                    Spacer()
                    Pill(text: "\(store.neverUsed.count)", tone: .idle)
                }
                ForEach(store.neverUsedBySource.prefix(4), id: \.source) { group in
                    HStack {
                        Text(group.source).font(Theme.Font.body).foregroundStyle(Theme.Palette.text).lineLimit(1)
                        Spacer()
                        Text("\(group.count)").font(Theme.Font.number).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                if store.neverUsedBySource.isEmpty {
                    Text(store.hasData ? "Everything installed has been used." : "Waiting for the first scan.")
                        .font(Theme.Font.body).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.xxs) {
            Text(store.isScanning ? "Scanning..." : "Scanned \(Format.ago(store.lastScan))")
                .font(Theme.Font.caption).foregroundStyle(Theme.Palette.textTertiary)
            Spacer()
            IconButton(systemImage: "arrow.clockwise", help: "Scan again") { store.refresh() }
            IconButton(systemImage: "power", help: "Quit OpenSkills") { NSApp.terminate(nil) }
            Button("Open") {
                openWindow(id: WindowID.main)
                NSApp.activate()
            }
            .buttonStyle(InkButtonStyle())
            .padding(.leading, Theme.Space.xxs)
        }
        .padding(.horizontal, Theme.Space.xxs)
    }
}
