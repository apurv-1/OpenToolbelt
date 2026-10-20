# Launch video

The 30-second launch video, built as an HTML composition and rendered frame by frame to MP4.

## Visual language

Off-white grid, black Inter type, dark product cards, and four mint "cursor" dots that snap around whichever element just landed.
Everything sits on a 120 bpm grid (one beat every 0.5 s).
Scenes cut on the beat through a quick blur dissolve, and each scene drifts forward slowly while it is on screen.
The music stops at 28 s while the end card holds.

## Storyboard (bars of 2 s)

| Time | Beat | Copy |
| --- | --- | --- |
| 0.0 - 4.0 | Agents and their skills land on the grid, one per half beat | |
| 4.0 - 6.0 | Headline, two hits | Every agent. Every skill. |
| 6.0 - 8.0 | Wordmark | OpenToolbelt. See what your coding agents carry, and what it costs. |
| 8.0 - 12.0 | 01 Context cost: counter to 8,500 tokens, three facts | Skills cost tokens before you type. |
| 12.0 - 16.0 | 02 Suggestions: trim, the count falls to 800 | Trim the weight in one click. |
| 16.0 - 20.0 | 03 Add skills: a repo is typed, agents land, install | Any repo. Every agent. |
| 20.0 - 24.0 | Three pillars | Six agents. One honest list. |
| 24.0 - 26.5 | Proof, then the dots jump to the frame edges as dashes | 6 agents, 100% local, MIT. |
| 26.5 - 30.0 | Impact cut to the end card | OpenToolbelt. Know what your agents carry. |

The 8,500 and 7.7k token numbers come from the author's own Claude Code setup.

## Editing

Open `index.html` in a browser to preview.
Space plays or pauses (with the soundtrack once `out/track.wav` exists), and the left arrow restarts.
Every animation lives in one GSAP timeline, keyed by absolute seconds on the beat grid.
`beat(selector, t)` brackets an element with the cursor dots and pops it in; `cut(from, to, t)` changes scene.
Each call records an event, and `audio.py` turns those events into blips, thuds and swishes, so sound stays in sync when you move things.

## Soundtrack

`audio.py` synthesizes the track with numpy: a four-on-the-floor groove, a pumping bass and pad under D-A-Bm-G, a lead hook every two bars, a riser into the end card, and one sound per visual event.
Nothing is sampled, so the track is free to publish.

## Rendering

The renderer drives the timeline with `window.seek(t)`, screenshots each frame with headless Chrome, writes `out/events.json`, runs `audio.py`, mixes with ffmpeg, and encodes 1920x1080 at 60 fps.

```bash
npm install --no-save puppeteer-core
```

```bash
node render.cjs
```

Set `CHROME_PATH` to a Chrome or Chromium binary if the default Playwright headless shell is not installed.
`node stills.cjs 4.6 14.6` renders single frames into `out/` for layout checks.

## Assets

- `assets/Inter.woff2`: Inter, from Google Fonts (OFL).
- `assets/gsap.min.js`: GSAP 3.12.5 (free under the GSAP standard license).
- `assets/icons/`: agent logos from lobe-icons (MIT); the marks belong to their owners.
