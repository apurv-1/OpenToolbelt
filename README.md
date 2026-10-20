# OpenSkills

A local macOS menu bar app that shows every skill your coding agents have, where each one came from, and which ones actually get used.

> Working name. The final name is still open.

## Why

Coding agents collect skills and MCP servers fast.
A plugin brings twenty skills, a popular repo brings thirty more, and nobody knows which of them ever run.
Your agents already write down everything they do in local session transcripts.
OpenSkills reads those transcripts and puts the answer next to what is installed.

## What it shows

The main screen is a skill by agent matrix.
Each row is a skill, and each column is an agent: Claude Code, Codex, Cursor, OpenCode, Windsurf and Gemini CLI.
Each cell says whether the skill is installed in that agent and, where the agent keeps readable logs, whether it was used.

Skills are grouped by where they came from:

- **External**: installed with `npx skills add`, grouped by source repo, read from `~/.agents/.skill-lock.json`.
- **Local**: skill folders added by hand.
- **Plugins, claude.ai and built-in**: skills that ship with a Claude Code plugin, sync from claude.ai, or come with the agent.

You can add skills from the app.
Paste `owner/repo`, a git URL or a local path, pick agents, and it runs `npx skills add` for you.
External skills can be removed the same way.

Usage comes from Claude Code and Codex session logs today.
Other agents show whether a skill is installed, and mark usage as not tracked.
An MCP servers page lists servers from Claude Code and Codex with their use counts.

## Privacy

Everything stays on your Mac.
The app has no telemetry.
It reads agent config and transcripts and never edits them.
The only time it changes anything is when you add or remove a skill, and then it runs `npx skills`, which fetches the source you asked for.

## Install

Download `OpenSkills.dmg` from the releases page and drag the app to Applications.
The app is not notarized yet, so macOS blocks the first launch.
Open **System Settings > Privacy & Security** and click **Open Anyway**.

## Build from source

You need macOS 15 or later and Xcode 16 or later.

```bash
swift build
```

```bash
swift test
```

Run the command-line report:

```bash
swift run -c release openskills
```

Build the app bundle and a DMG into `dist/`:

```bash
scripts/build-app.sh --dmg
```

## How usage is counted

A skill counts as used when the agent calls the `Skill` tool with its name, or when you type `/skill-name` (Claude Code) or `$skill-name` (Codex) in a prompt.
An MCP server counts as used when the agent calls one of its tools, named `mcp__<server>__<tool>` in the transcript.
Project-scoped items only count usage from sessions that ran inside that project.

## Limitations

- Claude Code deletes old transcripts after a retention period, so counts are a lower bound for the window the app shows.
- Codex usage detection is tested against synthetic fixtures and a small amount of real data.
- Usage comes from what reaches the transcript. A tool that does work without a recorded call is invisible to the app.

## Project layout

| Path | What it is |
|---|---|
| `Sources/OpenSkillsCore` | Scanner: reads config and transcripts, builds the report. No UI. |
| `Sources/openskills` | Command-line report on top of the core. |
| `Sources/OpenSkillsApp` | SwiftUI menu bar app and window. |
| `Sources/OpenSkillsApp/DesignSystem` | Tokens, components, and Metal shader backdrops. See [docs/design-system.md](docs/design-system.md). |
| `Design/AppIcon` | The app icon and the script that draws it. |
| `scripts/build-app.sh` | Packages the app and DMG. |

## Roadmap

- Usage from Cursor, OpenCode and Gemini CLI session logs.
- An activity log per skill: which commands ran, which files changed, and which hosts were contacted while it was active.
- More agents.

## License

MIT.
Agent logos come from [lobe-icons](https://github.com/lobehub/lobe-icons) (MIT) and belong to their owners.
