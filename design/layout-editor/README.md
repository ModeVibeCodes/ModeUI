# Layout editor (November 18, 2026)

The owner's layout editor for ModeUI's built-in layouts: the DPS / Tank
screen (the **Mode-Default** layout and profile), the plan for building it,
and the notes for the Healer layout that comes next. It is a planning page,
not addon code: nothing here loads in game. What it planned is built: see
`docs/ARCHITECTURE.md`, "Layouts", and `docs/MODE_REDESIGN.md`, "Revision:
Mode-Default layout and ModeCDM default bars".

Live editor (private to the owner):
https://claude.ai/artifact/6FWUxBmvD5qerXYSV5vYuT

The files here are copies, so the work can be read, compared or republished
from any machine:

| File | What it is |
|---|---|
| `index.html` | The editor page as published (version 5 of the artifact): tabs DPS / Tank (a to-scale screen at 1080p, 1440p or UI scale 1.0 where every element can be dragged and edited, with overlap checks), Healer (the owner's notes) and Plan (files, steps, decisions). |
| `dps-tank.json` | The owner's saved DPS / Tank layout (the artifact's database, `layouts/dps-tank`, saved November 18, 2026, 20:49 UTC). Every value the build used came from here. |

## Opening it

- **On claude.ai** (the live link): the page loads the saved layout, and
  **Save layout** stores changes for Claude to read (the `db` capability).
- **From disk** (`index.html` in a browser): the page works, but it can't
  save, and it shows its built-in proposal instead of the saved layout. The
  two differ only in the Damage Meter, 182 wide in the proposal and 230 in
  the saved layout.
- **Republishing** (another machine, through Claude): publish `index.html`
  as an Artifact with `capabilities: { db: {} }`, then write `dps-tank.json`
  to its database as `layouts/dps-tank` (ArtifactData `set`); the page then
  opens on the saved layout.

## The saved layout's format

Positions are in UI units at 1080p pixel-perfect (1 unit = 1 pixel), centered
on the screen, Y up. Each element has an `anchor` (`to` another element or
`screen`, its `point` on that element's `rel` point, plus `x`, `y`), its
size (`w` × `h` for icons, `barWidth`/`health` for unit frames, `rows`/`rowH`
for meters, `size`/`diff` for the minimap) and how it lays out (`per` per
line, `spacing`, `grow`, `lines`). `overrides["1440"]` holds the X and Y an
element takes at 1440p instead (the center block 25 higher, Ultra further
right, the party frames lower). `character` is the editor's estimate of the
player's character, for the overlap check.

## Where the build differs from the editor

The editor draws a simplified model; the build matched what shows on screen
and recorded each difference in the module's doc ("Mode-Default layout"):

- **Minimap:** the editor kept size 176 after the meters were widened to 230;
  the build uses size 224 (its edge shows 3 past each side: 230, as wide as
  the meters) and places it 11 in so what shows sits 8 in.
- **Buffs & Debuffs:** the icon borders sit inside the icon, so rows are
  shorter than drawn: the Debuffs sit 73 above the minimap's bottom (the
  editor's 82) and both bars 10 left of the map's element.
- **Party Frames:** 136 wide (a frame is an even number of pixels), each
  member 28 tall; the Edit Mode element is sized for five members, so its
  place is offset to center the four shown.
- **Focus:** unit frames anchor only to the screen, so its place is worked
  out from the Target's; it doesn't follow the Target if that moves.
- **Chat:** drawn in the editor but left out of the layout; its size and
  place are Blizzard's Edit Mode settings.
