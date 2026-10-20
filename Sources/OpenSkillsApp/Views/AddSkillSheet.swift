import OpenSkillsCore
import SwiftUI

/// Install skills with `npx skills add`, globally, for the chosen agents.
/// Also shows the live output of a remove started from the matrix.
struct AddSkillSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var source = ""
    @State private var skillNames = ""
    @State private var agents: Set<Agent> = []
    @FocusState private var sourceFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if store.cli.status == .idle {
                form
            } else {
                CommandLog(cli: store.cli)
            }
            Hairline()
            footer
        }
        .frame(width: 560)
        .background(Theme.Palette.surface)
        .onAppear {
            agents = Set(store.detectedAgents)
            sourceFocused = true
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add skills").font(Theme.Font.title).foregroundStyle(Theme.Palette.text)
                Text("Installs globally with npx skills, then links each skill into the agents you pick.")
                    .font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textSecondary)
            }
            HStack(spacing: 8) {
                Image(systemName: "shippingbox").foregroundStyle(Theme.Palette.textTertiary)
                TextField("owner/repo, git URL, or local path", text: $source)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($sourceFocused)
                    .onSubmit(install)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Theme.Palette.raised, in: .rect(cornerRadius: Theme.Radius.panel))

            field("Skills") {
                TextField("All skills in the source, or names separated by spaces", text: $skillNames)
                    .textFieldStyle(.plain).font(Theme.Font.body)
            }
            field("Agents") {
                FlowChips(agents: Agent.allCases, selected: $agents, detected: Set(store.detectedAgents))
            }
        }
        .padding(Theme.Space.lg)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
            Text(label).font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textSecondary).frame(width: 52, alignment: .leading)
            content()
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.xs) {
            switch store.cli.status {
            case .idle:
                Text(preview).font(Theme.Font.mono).foregroundStyle(Theme.Palette.textTertiary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(GhostButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Install") { install() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                    .disabled(trimmedSource.isEmpty || agents.isEmpty)
                    .opacity(trimmedSource.isEmpty || agents.isEmpty ? 0.4 : 1)
            case .running:
                ProgressView().controlSize(.small)
                Text("Running npx skills…").font(Theme.Font.secondary).foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Button("Stop") { store.cli.cancel() }.buttonStyle(GhostButtonStyle())
            case .succeeded, .failed:
                Text(store.cli.status == .succeeded ? "Done. The list has been refreshed." : "npx skills exited with an error.")
                    .font(Theme.Font.secondary)
                    .foregroundStyle(store.cli.status == .succeeded ? Theme.Palette.accent : Theme.Palette.danger)
                Spacer()
                Button("Back") { store.cli.reset() }.buttonStyle(GhostButtonStyle())
                Button("Done") { store.cli.reset(); dismiss() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 52)
    }

    private var trimmedSource: String { source.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var command: [String] {
        SkillsCommand.add(source: trimmedSource.isEmpty ? "owner/repo" : trimmedSource,
                          skills: skillNames.split(whereSeparator: \.isWhitespace).map(String.init),
                          agents: Agent.allCases.filter(agents.contains))
    }

    private var preview: String { "npx " + command.joined(separator: " ") }

    private func install() {
        guard !trimmedSource.isEmpty, !agents.isEmpty else { return }
        store.cli.run(command) { store.refresh() }
    }
}

/// Toggleable agent chips with brand marks.
struct FlowChips: View {
    var agents: [Agent]
    @Binding var selected: Set<Agent>
    var detected: Set<Agent>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(agents, id: \.self) { agent in
                let on = selected.contains(agent)
                Button {
                    if on { selected.remove(agent) } else { selected.insert(agent) }
                } label: {
                    HStack(spacing: 6) {
                        AgentIcon(agent: agent, size: 13).opacity(on ? 1 : 0.5)
                        Text(agent.displayName).font(Theme.Font.secondary)
                            .foregroundStyle(on ? Theme.Palette.text : Theme.Palette.textTertiary)
                        if !detected.contains(agent) {
                            Text("not found").font(.system(size: 10)).foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(on ? Theme.Palette.raised : .clear, in: .rect(cornerRadius: Theme.Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(on ? Theme.Palette.textTertiary.opacity(0.6) : Theme.Palette.hairline, lineWidth: 1))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .animation(Theme.Motion.quick, value: on)
            }
        }
    }
}

/// Streaming output of an `npx skills` run.
struct CommandLog: View {
    var cli: SkillsCLI

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(cli.output)
                    .font(Theme.Font.mono)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.md)
                Color.clear.frame(height: 1).id("end")
            }
            .onChange(of: cli.output) { proxy.scrollTo("end", anchor: .bottom) }
        }
        .frame(height: 280)
        .background(Theme.Palette.canvas)
    }
}
