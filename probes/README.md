# ModeUI probes

Probes are small addons that preview a planned redesign in game without
changing ModeUI. Each one draws plain (insecure) preview frames with ModeUI's
own design system through the `ModeUI-Core` LibStub API
(`ModeUI/Shared/Runtime/API.lua`). A probe never reads or writes `ModeUIDB`,
never touches ModeUI's modules or Blizzard's frames, and can be deleted at any
time.

| Addon | Phase | Opens with | Tabs |
|---|---|---|---|
| `ModeUI_ProbeFrames` | 5 | `/mprobe frames` | Group Frames, Nameplates |
| `ModeUI_ProbePanels` | 7 | `/mprobe panels` | Tooltip, Bags, Minimap |

`/mprobe` lists the loaded probes; `/mprobe <name> <tab>` opens one on a tab
(for example `/mprobe panels bags`). Esc closes a probe window.

## Build and install

`powershell -ExecutionPolicy Bypass -File tools/build_probes.ps1` copies the
shared `probes/Kit/ProbeKit.lua` and the license into each probe and writes
`dist/probes/<Probe>.zip` plus `ModeUI_Probes_All.zip`. Extract a zip into
`Interface\AddOns` (each zip holds its addon folder), then reload. The probes
need the current ModeUI (with `ModeUI-Core`); with an older one they print a
note and draw nothing.

## Rules

- Everything visual comes from `Style` (Tone, Edge, Bar, Shield, Font,
  Asset), exactly like a module. Game icons are the only file paths.
- Live values go through `Domain` readers; values the game keeps secret reach
  only widgets documented as accepting them.
- Files stay under 400 lines. `tests/probes.lua` loads every probe on top of
  ModeUI, opens every tab with secret live values, and checks the rules.
- When a redesign is approved, it is built into the ModeUI module itself and
  its probe is retired.
