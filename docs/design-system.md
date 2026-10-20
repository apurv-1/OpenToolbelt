# Design system

The app looks like an instrument: a quiet, light workspace with one live radar at its center.
All tokens live in `Sources/OpenSkillsApp/DesignSystem/Theme.swift`, and views never hard-code colors or sizes.

## Principles

- **Quiet surfaces, one loud element.** Cards are white on a soft gray canvas. The radar is the only dark, moving thing on screen.
- **Shadows, not borders.** Elevation comes from two soft shadows and a 0.5pt hairline. Heavy outlines are not used.
- **Color carries meaning.** Mint means used and alive. Amber means installed but never used. Everything else is grayscale.
- **Numbers first.** Stats lead with a large monospaced number, then a short label.

## Color

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F4F5F4` | `#0E1113` | Window and panel background |
| `surface` | `#FFFFFF` | `#171B1E` | Cards |
| `sunken` | `#EEF0EF` | `#121518` | Pills, tracks, hover |
| `text` | `#111414` | `#F2F4F3` | Primary text |
| `textSecondary` | `#5E6866` | `#9AA4A1` | Supporting text |
| `textTertiary` | `#9AA3A0` | `#5F6967` | Labels and timestamps |
| `accent` | `#0FA673` | `#7CF8C8` | Used, live, primary data |
| `idle` | `#B86E00` | `#F5B544` | Never used |

The accent has a darker shade on light backgrounds so text stays readable, and a glowing shade on dark ones.

## Type

System font throughout.
Numbers use monospaced digits so columns line up.

| Token | Size | Weight | Use |
|---|---|---|---|
| `display` | 30 | Semibold | Hero number |
| `title` | 20 | Semibold | Page titles |
| `headline` | 13 | Semibold | Emphasis |
| `body` | 13 | Regular | Rows and copy |
| `number` | 13 | Medium | Counts in rows |
| `caption` | 11 | Medium | Pills, details |
| `eyebrow` | 10 | Semibold, uppercase, tracked | Section and stat labels |

## Space and shape

Spacing steps are 4, 8, 12, 16, 24 and 32.
Corner radii are 6 for pills, 8 for controls, 14 for cards and 18 for hero cards.

## Components

All components are in `Components.swift`.

- `Card`: a raised surface with the standard shadow and hairline.
- `StatTile`: an eyebrow label, a large number and a detail line.
- `Pill`: a small tag. Tones are `neutral`, `quiet`, `accent` and `idle`.
- `UsageBar`: a thin meter for comparing counts in a list.
- `IconButton`: an icon-only button with a quiet hover fill.
- `InkButtonStyle`: the primary action, a dark capsule.

## Shaders

The shader backdrops are fragment shaders written in Metal Shading Language, in `Shaders.swift`.
They compile at runtime with the Metal framework, so building the app needs no offline Metal toolchain.

- `radar`: a scope with a graticule, a phosphor sweep, and one blip per item. Used items glow and flare as the beam passes. Unused items stay dim. Each blip's position comes from a hash of the item name, so it is stable across launches.
- `aurora`: slow drifting color fields with film grain, used behind the overview hero.

`ShaderView` renders at 30 fps while visible.
When Reduce Motion is on, it renders one still frame instead.

## Icons

The app icon is drawn by `Design/AppIcon/make-icon.swift`.
The menu bar glyph is drawn in code by `MenuBarIcon.swift` as a template image, so macOS tints it for light and dark menu bars.
