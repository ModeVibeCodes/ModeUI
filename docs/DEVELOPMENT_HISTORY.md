# Unit Frames development history

> Moved from Play The Game Tools docs/DEVELOPMENT.md on November 12, 2026. Branch
> names refer to the PTG repository; `python tests/unit_frames.py` is now
> `lua tests/unit_frames.lua` in this repository.

Unit Frames suite text style (November 12, 2026): branch
`claude/unit-frames-sky-text`, layout version 11.
- `M.nameAccents` holds Sky, Champagne, Lilac and Frost; `M.ACCENT` is Sky.
- Each of the four texts has a `.lift` font string (ARTWORK, 2 pixels down-right
  at 45% black). `Write`/`Formatted` write a text and its lift together, and
  `LayoutLift` places it.
- The matched-Target proxy mirrors only with `mirrorText` and exposes
  `mirrored`, which makes `ApplyLayout` read grouped level/health text health
  first.

It replaced layout version 10's name-only `f.nameLift`
(`claude/unit-frames-name-colors`). [Details](UNIT_FRAMES.md).

Unit Frames locked Onyx skin (November 11, 2026): branch
`claude/unit-frames-onyx-skin`, layout version 9. A single display path:
`M.onyx` holds the fixed skin colors and `M.ACCENT` the Mist accent.
`M:HealthColor` and `M:NameColor` resolve the three-way choices, and
`M:PaintRing` draws the class gradient with `SetGradient` on the portrait's
circle. Seven unused textures were removed from Media and
`tools/build_unit_frame_textures.py`. [Details](UNIT_FRAMES.md).

Unit Frames pastel and element tabs (November 11, 2026): branch
`claude/unit-frames-pastel`, layout version 8. `FrameDB` mirrors alignment and
X offsets for a matched Target on the other side. `M:Palette` serves a reused
Custom palette table, and `SetPaletteColor` converts a preset to Custom.
`AppearanceOwner` accepts a unit function for the page's Editing switch, and
`M:Soften` applies Class Color Softness. No new media. [Details](UNIT_FRAMES.md).

Unit Frames Onyx (November 11, 2026): branch `claude/unit-frames-onyx`, layout
version 7. Display code reads settings through `M:FrameDB(unit)`, so a matched
Target renders the Player's look. `M:FontPath` resolves Expressway with a PTG
Lato fallback. No new media. [Details](UNIT_FRAMES.md).

Unit Frames palettes (November 11, 2026): branch `claude/unit-frames-palettes`,
layout version 6. Minimal Rounded geometry takes a pixel size (PixelUtil
factor over effective scale); tests stub `PixelUtil` at 1440p to check
whole/even pixels. Union border: the portrait's border circle is `panel.ringBorder`
(bar layer); bars tuck under the portrait disc (`g.tuck`). New textures: Circle, FrameInner. Client restart needed.
[Details](UNIT_FRAMES.md).

Unit Frames Minimal Rounded (November 11, 2026): branch `claude/unit-frames-minimal`,
layout version 5. `ApplyMinimalLayout` is a separate path; other styles restore
their portrait ring, mask and back textures when re-selected. New textures:
FrameFill, Hairline, TileMask (`tools/build_unit_frame_textures.py`). Client
restart needed. [Details](UNIT_FRAMES.md).

Unit Frames bar bezels (November 11, 2026): branch `claude/unit-frames-bar-bezels`
adds `WellBezel.tga` to `tools/build_unit_frame_textures.py`; the other textures
rebuild byte-identically. New keys `showFrameEdge`, `barBorderColor` and
`barBorderOpacity` fill as defaults, so no layout version bump. Client restart
needed for the new texture. [Details](UNIT_FRAMES.md).

Unit Frames Satin Matte (November 11, 2026): branch `claude/unit-frames-satin`.
Rebuild the five UnitFrames textures with
`python tools/build_unit_frame_textures.py` (Pillow; deterministic, so a
rebuild is byte-identical). `tests/unit_frames.py` checks their format, neutral
grey, rounded alpha and visible sheen. New media needs a client restart.
Layout version 4. [Details](UNIT_FRAMES.md).

Unit Frames Inset Wells (November 11, 2026): branch `claude/unit-frames-inset-wells`
adds the owner-chosen border (layout version 3, `trimColor`), keeps the
owner's stand-in anchoring fix and pins bar fills above their tracks. The test
now asserts stand-ins are anchored before Position Manager registration, since
the mock's GetCenter works without one. No new files; `/reload` is enough.
[Details](UNIT_FRAMES.md).

Unit Frames Blizzard-style Mode redesign (November 11, 2026): branch
`claude/unit-frames-blizzard-style` from `claude/interface-unit-frames`. Settings
are per frame (`layoutVersion` 2) with a one-time phase-1 migration; layout,
materials and the portrait technique are in [UNIT_FRAMES.md](UNIT_FRAMES.md).
No new files; restart the client if the phase-1 files were never loaded. Run
`python tests/unit_frames.py` with smoke/build. Native acceptance is pending.

Interface suite phase 1 (November 11, 2026): branch `claude/interface-unit-frames`
from `codex/character-panel-reskin` adds the Interface category and opt-in Unit
Frames (Player/Target). Run `python tests/unit_frames.py` with smoke/build;
smoke now expects 16 modules / 7 categories. The package is 125 Lua / 227 files.
New TOC files need a client restart, not just `/reload`. AyijeUI and
EllesmereUI are all-rights-reserved references: study patterns only, never
copy. Native acceptance is pending. [Design, API findings and checks](UNIT_FRAMES.md).

