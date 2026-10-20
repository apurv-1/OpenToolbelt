# Design system

The app is a calm, dense tool in the spirit of Linear and Raycast, with one small live radar as its signature.
All tokens live in `Sources/OpenToolbeltApp/DesignSystem/Theme.swift`, and views never hard-code colors or sizes.

## Principles

- **Calm and dense, like Linear and Raycast.** Small type, tight rows, hairlines instead of cards and shadows.
- **Monochrome first.** Almost everything is a shade of gray. Color only marks state.
- **Color carries meaning.** Mint means used. Amber means installed but never used. A gray ring means installed but usage is not tracked.
- **Brand marks over labels.** Agents appear as their own logos, in color where it helps recognition and in mono inside the dense grid.
- **One live element.** The small radar in the menu bar panel is the only thing that moves.

## Color

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#FAFAFA` | `#0D0E10` | Window background |
| `surface` | `#FFFFFF` | `#131416` | Panels, sheets, the menu bar panel |
| `raised` | `#F1F1F2` | `#1B1C1F` | Hover, selection, fields |
| `hairline` | black 8% | white 7% | Dividers and edges |
| `text` | `#18181B` | `#EDEDEF` | Primary text |
| `textSecondary` | `#6B6D74` | `#8B8D94` | Supporting text |
| `textTertiary` | `#A0A2A8` | `#5B5D63` | Labels, counts, timestamps |
| `accent` | `#059669` | `#6EE7B7` | Used |
| `idle` | `#B7791F` | `#E3B341` | Never used |
| `danger` | `#DC2626` | `#F87171` | Errors |

## Type

System font throughout, with monospaced digits for counts.
Sizes are 15 for page titles, 13 for rows, 12 for supporting text and 11 for labels.

## Space and shape

Spacing steps are 8, 12, 16 and 24.
Rows are 34pt tall. Page titles, search and the primary action live in the native window toolbar.
Corner radii are 6 for controls and rows, and 10 for panels.

## Components

All shared components are in `Components.swift` and `AgentIcon.swift`.

- `StatusDot`: the matrix cell mark for used, never used, installed and absent.
- `KeyCap`: a keyboard shortcut hint.
- `IconButton`, `PrimaryButtonStyle`, `GhostButtonStyle`: the three button weights.
- `MenuRow`: a command-palette row for the menu bar panel.
- `AgentIcon`: an agent's logo in color or mono.
- `ItemTile`: a letter tile for a skill, colored from a hash of its name, or a plug for an MCP server.

Groups use one symbol each: a download arrow for npx skills repos, a puzzle piece for plugins, a plug for MCP servers, a folder for local skills, and the agent's logo for built-in skills.

## Shaders

The radar is a fragment shader in Metal Shading Language, in `Shaders.swift`.
It compiles at runtime with the Metal framework, so building needs no offline Metal toolchain.
Each blip is one skill: used skills glow and flare as the beam passes, unused ones stay dim.
`ShaderView` renders at 30 fps while visible and holds a still frame when Reduce Motion is on.

## Icons

The app icon is drawn by `Design/AppIcon/make-icon.swift`.
The menu bar glyph is drawn in code by `MenuBarIcon.swift` as a template image.
Agent logos are SVGs from lobe-icons in `Sources/OpenToolbeltApp/Resources/AgentIcons`.
