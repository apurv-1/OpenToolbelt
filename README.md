# OpenSkills

A local macOS menu bar app that shows which skills and MCP servers your coding agents actually use.

> Working name. The final name is still open.

## Why

Coding agents collect skills and MCP servers fast.
A plugin brings twenty skills, a popular repo brings thirty more, and nobody knows which of them ever run.
Your agents already write down everything they do in local session transcripts.
OpenSkills reads those transcripts and puts the answer next to what is installed.

## What it shows

- **Installed vs used** for every skill and MCP server, with use counts and the last time each one ran.
- **Never used**: items that are installed but have not run once in the transcripts on this Mac.
- **Not installed**: tools your agents called that no config declares, such as built-in tools, claude.ai connectors, or things you since removed.
- **Sessions**: how many sessions were scanned and how far back they go.

It covers Claude Code and Codex CLI today.
For Claude Code it reads user skills, project skills, plugin skills and MCP servers, claude.ai synced skills, and MCP servers from `~/.claude.json` and project `.mcp.json` files.

## Privacy

Everything stays on your Mac.
The app makes no network calls and has no telemetry.
It only reads agent config and transcripts, and it never writes to them.

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

- An activity log per skill and MCP server: which commands ran, which files changed, and which hosts were contacted while it was active.
- Disable or remove never-used items, with a backup first.
- More agents.

## License

MIT
