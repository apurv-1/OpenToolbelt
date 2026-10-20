#!/usr/bin/env python3
"""Builds a fake home directory with a realistic coding-agent setup.

It is used to render the README screenshots without anyone's real data:

    python3 scripts/demo-home.py /tmp/demo-home
    swift run OpenToolbeltApp --snapshot docs/images --home /tmp/demo-home

Everything here is made up. Sessions are spread over the 30 days before
today, so the activity chart has shape.
"""

import json
import os
import random
import shutil
import sys
from datetime import datetime, timedelta, timezone

random.seed(7)

if len(sys.argv) != 2:
    sys.exit("usage: demo-home.py <directory>")
HOME = os.path.abspath(sys.argv[1])
shutil.rmtree(HOME, ignore_errors=True)
NOW = datetime.now(timezone.utc)


def write(path, text):
    full = os.path.join(HOME, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)


def skill(path, name, description):
    write(f"{path}/SKILL.md", f"---\nname: {name}\ndescription: {description}\n---\n\n# {name}\n")


def link(target, link_path):
    full = os.path.join(HOME, link_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    os.symlink(os.path.join(HOME, target), full)


def stamp(days_ago, hour=10):
    t = (NOW - timedelta(days=days_ago)).replace(hour=hour, minute=random.randint(0, 59))
    t = min(t, NOW - timedelta(minutes=random.randint(5, 90)))  # never in the future
    return t.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def line(obj):
    return json.dumps(obj, separators=(",", ":"))  # compact, as agents write it


# Agent home folders, so each agent is detected.
for marker in [".claude", ".codex", ".cursor", ".config/opencode"]:
    os.makedirs(os.path.join(HOME, marker), exist_ok=True)

# External skills installed with `npx skills add`: canonical copies in
# ~/.agents/skills, linked into each agent, tracked in the lockfile.
EXTERNAL = {
    "anthropics/skills": {
        "pdf": "Read, fill and merge PDF files, extract text and tables, and create new PDFs from scratch.",
        "docx": "Create and edit Word documents with tracked changes, comments, styles and tables.",
        "xlsx": "Build spreadsheets with formulas, charts and formatting, and clean up messy tabular data.",
        "skill-creator": "Guide for creating new skills: structure, frontmatter, references and evaluation.",
    },
    "obra/superpowers": {
        "brainstorming": "Turn a rough idea into a design through focused questions before writing any code.",
        "systematic-debugging": "Find the root cause of a bug with evidence before proposing any fix.",
        "test-driven-development": "Write the failing test first, watch it fail, then write the minimal code to pass.",
    },
    "vercel-labs/agent-skills": {
        "web-design-guidelines": "Review UI code against web interface guidelines for accessibility, layout and polish.",
        "frontend-design": "Build distinctive, production-grade frontend interfaces that avoid generic AI aesthetics.",
    },
}
lock = {"version": 3, "skills": {}}
for source, skills in EXTERNAL.items():
    for name, description in skills.items():
        skill(f".agents/skills/{name}", name, description)
        link(f".agents/skills/{name}", f".claude/skills/{name}")
        if source != "anthropics/skills":
            link(f".agents/skills/{name}", f".cursor/skills/{name}")
        lock["skills"][name] = {
            "source": source,
            "sourceType": "github",
            "sourceUrl": f"https://github.com/{source}.git",
            "installedAt": stamp(random.randint(20, 60)),
        }
write(".agents/.skill-lock.json", json.dumps(lock, indent=2))

# A hand-made skill, and one only OpenCode has.
skill(".claude/skills/release-notes", "release-notes", "Draft release notes from merged pull requests since the last tag.")
skill(".config/opencode/skills/changelog", "changelog", "Keep CHANGELOG.md in Keep a Changelog format.")

# Claude Code plugins, each bundling skills and an MCP server.
PLUGINS = {
    "sentry": (["sentry-triage", "sentry-release-health"], "sentry"),
    "linear": (["linear-issues", "linear-cycles", "linear-triage"], "linear"),
}
installed = {}
for plugin, (skills, server) in PLUGINS.items():
    root = f"plugin-cache/{plugin}/1.0.0"
    write(f"{root}/.claude-plugin/plugin.json", json.dumps({"name": plugin}))
    write(f"{root}/.mcp.json", json.dumps({"mcpServers": {server: {"type": "http", "url": f"https://mcp.{plugin}.example/mcp"}}}))
    for name in skills:
        skill(f"{root}/skills/{name}", name, f"Work with {plugin.title()} from the agent: {name.replace('-', ' ')}.")
    installed[f"{plugin}@marketplace"] = [{"scope": "user", "installPath": os.path.join(HOME, root), "version": "1.0.0"}]
write(".claude/plugins/installed_plugins.json", json.dumps({"version": 2, "plugins": installed}))
write(".claude/settings.json", json.dumps({"enabledPlugins": {k: True for k in installed}}))

# MCP servers from config files.
write(".claude.json", json.dumps({"mcpServers": {"github": {}, "postgres": {}, "filesystem": {}, "puppeteer": {}}}))
write(".cursor/mcp.json", json.dumps({"mcpServers": {"github": {}, "figma": {}}}))
write(".codex/config.toml", "[mcp_servers.github]\ncommand = \"github-mcp\"\n")

# Cursor's built-in skills.
for name in ["review", "shell", "create-rule"]:
    skill(f".cursor/skills-cursor/{name}", name, f"Built-in Cursor skill: {name.replace('-', ' ')}.")

# Claude Code sessions over the last 30 days.
CLAUDE_USE = [("Skill", "pdf"), ("Skill", "systematic-debugging"), ("Skill", "frontend-design"),
              ("Skill", "brainstorming"), ("Skill", "release-notes"), ("Skill", "linear:linear-issues")]
MCP_USE = ["mcp__github__create_pull_request", "mcp__github__get_issue", "mcp__postgres__query",
           "mcp__plugin_sentry_sentry__get_issue", "mcp__plugin_linear_linear__list_issues"]
call = 0
for session in range(42):
    days_ago = random.choice(range(30))
    lines = []
    for _ in range(random.randint(3, 14)):
        call += 1
        if random.random() < 0.3:
            tool, skill_name = random.choice(CLAUDE_USE)
            block = {"type": "tool_use", "id": f"t{call}", "name": tool, "input": {"skill": skill_name}}
        else:
            block = {"type": "tool_use", "id": f"t{call}", "name": random.choice(MCP_USE), "input": {}}
        lines.append(line({"type": "assistant", "timestamp": stamp(days_ago, random.randint(8, 20)),
                                 "cwd": "/work/app", "message": {"content": [block]}}))
    write(f".claude/projects/-work-app/session-{session}.jsonl", "\n".join(lines))

# Codex sessions.
for session in range(6):
    days_ago = random.choice(range(30))
    lines = [
        line({"type": "response_item", "timestamp": stamp(days_ago),
                    "payload": {"type": "message", "role": "user",
                                "content": [{"type": "input_text", "text": "use $test-driven-development for this fix"}]}}),
        line({"type": "response_item", "timestamp": stamp(days_ago, 11),
                    "payload": {"type": "function_call", "name": "mcp__github__get_pull_request"}}),
    ]
    write(f".codex/sessions/2026/10/{session + 1:02d}/rollout-{session}.jsonl", "\n".join(lines))

print(f"Demo home written to {HOME}")
