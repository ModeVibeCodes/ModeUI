# Border study (revisions phase, November 16, 2026)

The owner's study of a more detailed, Blizzard-like border for the Mode
design language. It is a design canvas, not addon code: nothing here loads in
game, and `ModeUI/` is unchanged by it.

Live canvas (private to the owner):
https://claude.ai/artifact/2g21nREnhBy9fkDph2nUkY

The files here are a copy of that canvas's own files, so the study can be read
or republished from any machine. The `.dc.html` artboards run inside the
canvas's Design runtime (`./support.js`); opened straight from disk they will
not render. To rebuild the canvas, publish `canvas.json` and every
`.dc.html` to a canvas made from the Design artifact type, at their
`project/<name>` paths.

## Artboards

| File | What it shows |
|---|---|
| `Main.dc.html` | Overview: the shipping Mode edge beside five families (A Forged Bevel, B Twin Rail, C Corner Caps, D Cut Steel, E Gilded Edge), each on a unit frame, action buttons, a nameplate with auras and the corner at 6× |
| `Swatch.dc.html` | One family's card (the overview imports it once per family) |
| `Scene.dc.html` | Interactive: a mock HUD (window, unit frames, action bar, tooltip, nameplate, 8× corner) with a switcher for the six families |
| `Ends.dc.html` | D's material on six end shapes for unit frames: cut corners, cut ends, soft round, capsule, oval, capsule with C's end caps; and three with a portrait ring |
| `Lab.dc.html` | Interactive: D beside Soft round on the same elements, with switchers for 7 metals, 6 lighting models and an inner glint |
| `Materials.dc.html` | Every metal under every lighting model, D above Soft round in each cell |

## Recipes (outside in)

All the borders are rings drawn outside the host:

- **D · Cut Steel:** 1px shadow (black, 85%), 2px Steel band lit top to
  bottom (`#A3A6AB` → `#6E7176` at 45% → `#3D4044`), 1px black; 45° corners
  cut 5px (3px on thin borders). Reach 4px (thin: 1px shadow + 1px band,
  `#8C8F95` → `#4A4D51`).
- **Soft round:** D's rings with a 12px outer radius on frames and windows,
  8px on buttons, 10px on tooltips, 6px on controls and nameplates, 5px on
  auras; each inner ring's radius steps in by its own width.
- **C · Corner Caps:** brighter Steel brackets over the rim at each corner
  (2px, 10px arms; thin 1px, 6px arms), top `#A9ACB1`, bottom `#7C7F85`.

Metals (hi / light / mid / dark / deep):

| Metal | hi | light | mid | dark | deep |
|---|---|---|---|---|---|
| Steel | `#D4D7DC` | `#A3A6AB` | `#6E7176` | `#3D4044` | `#26282B` |
| Gunmetal | `#A5A9AF` | `#7C8086` | `#4E5156` | `#2C2E31` | `#1A1B1D` |
| Silver | `#F2F4F6` | `#D9DCE0` | `#9A9EA4` | `#5C6066` | `#3A3D41` |
| Dark Iron | `#B3AAA2` | `#8A817A` | `#55504B` | `#2E2B28` | `#1B1917` |
| Cobalt | `#CCD9E8` | `#9FB2C8` | `#5F7288` | `#313D4A` | `#1C232B` |
| Bronze | `#E8C9A2` | `#C9A27A` | `#8A6440` | `#4A3420` | `#2A1D12` |
| Gold | `#FFF0B8` | `#E8C978` | `#A8843E` | `#5C4620` | `#33270F` |

Lighting models for the 2px band (gradient stops top to bottom of the frame):

- **Top lit:** light, mid 45%, dark (D as drawn).
- **Polished:** hi, light 10%, dark 45%, deep 60%, mid 85%, dark.
- **Bevel:** two 1px rows: hi, light 40%, mid over mid, dark 50%, deep.
- **Specular band:** mid, hi 16%, mid 32%, dark 70%, deep.
- **Edge catch:** hi on the top row only, then light, mid 40%, dark.
- **Two-tone:** light, mid 48%, deep 52%, dark.

## Research notes (Forever, November 16, 2026)

From the `forever` branch of Gethe/wow-ui-source (1.60.1.70938):

- Blizzard's borders are NineSlice layouts (`Blizzard_SharedXML`): corner
  pieces anchored with outward offsets, edges running between the corners'
  inner sides; `_` atlases tile horizontally, `!` vertically. Ornament lives in
  the corners; edges stay plain. Metal panels (`UI-Frame-Metal-*`), dialogs
  (`UI-Frame-DiamondMetal-*`) and the 7px tooltip kit are the references.
- `Texture:SetTextureSliceMargins` / `SetTextureSliceMode` exist on Forever,
  so every family can stay sliced Mode art from `tools/build_mode_assets.lua`
  drawn by `Style.Edge`. Corner caps (C) would be separate corner pieces over
  the rim, as NineSlice does.
- Shapes beyond Soft round (capsule, oval) cannot rely on the rim covering
  its inner corner: they need the bars clipped by a shape mask
  (`Style.SetShapeMask`), which stretches with the frame; that needs research
  before it is chosen.
- Pixel scale: 768 / screen height (0.711 at 1080p, 0.533 at 1440p).
  `SetIgnoreParentScale`, `SetScale` and `SetRoundLayoutToNearestPixel` are
  protected: never on secure frames in combat.
