# Mode redesign: status, decisions and plan

The working record of the Mode design-language rollout: what is built, what
the owner decided along the way, how the work is done, and what comes next.
Read this, `AGENTS.md` and `docs/DESIGN_LANGUAGE.md` before continuing on a new
machine or in a new session. Last updated November 18, 2026 (Phases 0-8
built and confirmed November 15. The revisions and tweaks phase is under way:
borders, type, ModeCDM's bars and the Mode-Default layout, each waiting on
its in-game gate; see the revisions below).

## Goal

Rebuild every ModeUI module in the Mode design language
(`docs/DESIGN_LANGUAGE.md`): one set of color tokens (`Style.Tone`), border
presets (`Style.Edge`), bar textures ("Mode <Name>" in `Style.Asset`), the
Mode typeface (Expressway when installed, else Geist) and the `Style.Bar` / `Style.Shield` / `Style.Comet` factories, all in
`ModeUI/Shared/Style/`. Modules never hard-code colors, borders, masks,
texture paths or font files; `tests/design.lua` enforces it.

The work goes phase by phase. Each phase (and each module within a phase)
ends at an **in-game gate**: the owner checks it in WoW Forever and confirms
before the next starts.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0 | Baseline screenshots | Done |
| 1 | The standard: `DESIGN_LANGUAGE.md`, `tests/design.lua` + legacy list | Done, confirmed |
| 2 | Assets: Mode textures (`tools/build_mode_assets.lua`), Geist, LibSharedMedia | Done, confirmed |
| 3 | Style core: Tone, Edge, Bar, Shield, Comet, Fonts, Names, `/modeui style` sheet | Done, confirmed |
| 4 | Settings window: hybrid window, widgets, page layouts, tile packing | Done, confirmed |
| 5 | Frames: Unit Frames, Party Frames, Nameplates | Done, confirmed |
| 5b | Texture retune after in-game look (see below) | Done, confirmed |
| 6 | Bars and buttons: **Action Bars**, then **Cooldown Manager** (the ModeCDM addon) | Done, confirmed (November 15) |
| 7 | Windows and panels: Skin layer + Windows, Chat, Damage Meters, Tooltip, Bags, Minimap | Done, confirmed (November 15), one gate per module |
| 8 | Cleanup: delete legacy border systems and palettes | Done (November 15): legacy list empty, probes retired |
| 9 | Release 0.2.0: notes, notices | Only with the owner's go-ahead |
| 10 | New coverage (optional) | Waits on decision 2 |

### What each finished module carries now

- **Unit Frames** (layout version 24): Mode Matte health, Mode Gradient power,
  Mode Cast casts, Mode BG empty bars, Geist, Gradient names, health text
  colored by health with a soft glow, a 3px portrait ring in the true class or
  reaction color (Ring Style, Mode-Blizz by default, in tones of the color;
  Ring Finish: a metal, Class Color or Custom) between a 1px shadow ring and a 1px black line,
  Combined shields; no Class Color Softness.
  See `docs/UNIT_FRAMES.md`.
- **Party Frames** (settings version 7): the `group` edge, 150 x 34 + 3, Mode
  Glass health (owner's pick), Shields tab (texture, color, opacity), Gradient
  names, aggro/target/dispel rim swaps, dispel Gradient. See
  `docs/PARTY_FRAMES.md`.
- **Nameplates** (settings version 11): `frameThin` edge, Ivory target line,
  Rosewood focus line, Mode BG fills, Mode Cast with the Comet spark, gradient
  names, health text by health with glow. See `docs/NAMEPLATES.md`.
- **Aura icons** everywhere (`Shared/Kit/AuraIcon.lua`): the `frameThin` edge,
  Border Size 1 or 2, dispel type tints the rim.
- **Action Bars** (settings version 6): 40 x 34 buttons in the `frame` edge
  outside each button, Mode Button face, Ivory hover line, Celadon proc rim,
  Mode icon tints (range, power, unusable), Geist Bold texts. See
  `docs/ACTION_BARS.md`.
- **Cooldown Manager** (settings version 5, built and confirmed November 15): icons 40 x 34 / 32 x 28 in the `frameThin` edge outside the icon
  (the approved probe), a Mode Button face, Spacing between the shadows,
  Border glows as a Mode Empty rim swap (Celadon procs and buffs, Ivory active
  and ready), Rosewood out of range, Geist Bold texts; Tracked Bars 220 x 16 in
  Mode Gradient on Mode BG with the Comet spark in your class color; Resource
  Bars in the `frameThin` edge, Mode BG at 60%. Ships as the companion addon
  **ModeCDM** (`ModeCDM/`), nested under ModeUI in the AddOn list. See
  `docs/COOLDOWN_MANAGER.md` and "Companion addons" in `docs/ARCHITECTURE.md`.
  A provenance audit (November 15) found no code from other authors in it;
  its racial spell list follows Blizzard's `TrackedCooldowns.lua`.

- **Windows** (settings version 3): every Blizzard window a Mode window
  (Graphite panel in Mode Panel, the `window` edge, a Mode Title strip),
  controls by template (Mode buttons, one-line fields, text tabs with an Ivory
  bar, side tabs, glyph buttons, faint scroll tracks), insets in Mode Grain,
  item quality on slot edges, readable parchment text. See `docs/WINDOWS.md`.
- **Chat** (settings version 6): each window a Mode window on its box (no drop
  while see-through), Mode tabs on the edge (open one Ivory), a Graphite edit
  band with an Ivory line while typing, the button compartment as a Mode
  control; Blizzard's Edit Mode selection laid over the Mode box so it snaps
  flush to a corner. See `docs/CHAT.md`.
- **Damage Meters** (settings version 9): Mode windows with a Mode Title
  header, Mode Panel bars on Mode BG, Ivory accents, the menu a Mode window.
  See `docs/DAMAGE_METERS.md`.
- **Tooltip** (settings version 5): Mode windows, the rim in the item's
  quality, the first line SemiBold, reactions in the gameplay tones. See
  `docs/TOOLTIP.md`.
- **Bags** (settings version 3): a Mode window, Mode slots (wider than tall,
  `group` edge colored by quality), the Clean Up broom, quest marks, Bold
  cooldown numbers, and a footer with the Bag Bar (equip bags there), a free
  count over a capacity bar and the money. See `docs/BAGS.md`.
- **Minimap** (settings version 2): the owner's design on the Mode `frame`
  edge ("keep what fits": Thin or Mode rim, Border Color as its tint, fixed
  corners), up to 48 px wider than tall, Mode tiles for Blizzard's buttons and
  the addon tray. See `docs/MINIMAP.md`.

### Phase 7 decisions and preferences (owner, November 15)

- **Typeface:** Expressway when the client has it (an installed addon's
  copy; ModeUI ships none), Geist otherwise; "Mode" names whichever it is.
- **Brand:** "Mode" in the wordmark in warm gold (`brand`, #E2B866), "UI"
  white, wherever ModeUI's name shows (Game Menu, addon menu, AddOn list,
  chat messages).
- **Edges inside boxes** where boxes sit side by side or must sit flush
  (windows, controls, chat, tooltips, bags), and a box's face stops where an
  inside edge starts (a see-through face showed its square corners).
- **No soft drop under anything see-through.**
- **Rebuilt modules drop border settings** the Mode edge can't honor (border
  color, size, corners, rounded); the Minimap keeps Thin/Mode and its color.
- **Bags:** slots wider than tall as the probe; a Bag Bar in the footer;
  the free count as a number over a capacity bar; a broom for Clean Up; a
  quest mark on quest items.
- **Minimap:** wider shapes up to 48 px; the corner pickers name corners.

### Phase 8 cleanup (November 15)

- Deleted: `Shared/Kit/Border.lua` (Kit.ModeBorder, ModeBoxBorder, BoxFill,
  the corner masks), `Shared/Kit/Capsule.lua`, `Kit.Rim`/`Kit.PlaceRim`,
  Skin's pre-Mode palette and panels, `Shared/Border` (the LSM backdrop
  border) and `Media:ApplyBackdrop`; 36 unused textures and their generator
  entries; Lato (typeface step 3 moves saved Lato choices to "Mode").
- Moved into Style: every color a module held (new Tone tokens: power types,
  threat, debuff types, stats, combo points, heal prediction, aura glow,
  name accents, combat ring, macro; the pre-Mode palettes into
  `Style.LEGACY`, which `Kit.palette`/`Kit.onyx` alias), the texture root,
  other addons' media (`Style.PROVIDER_MEDIA`), bar fill files
  (`Style.SetBarTexture`), the minimap's shape mask (`Style.SetShapeMask`)
  and colored text (`Style.ColorText`). `Style/Tone.lua` loads before
  `Shared/Domain`.
- The probe addons are deleted (every design built); the probe kit, build
  script and test stay for the next redesign.

### Texture retune (owner's in-game feedback, November 15)

- Module bars draw a Mode texture's **base plus its white lift** over the fill
  (`Style.ApplyBarLook` via `Kit.BarForeground`), not the single baked file:
  the multiply was hiding the light on dark fills. The baked files are only for
  other addons through LibSharedMedia.
- `darkFill` is `#1C1D1C` (owner's pick); Unit Frames' Default health uses it.
- Empty bars are Slate `#575757` at 60% (`Tone.emptyAlpha`) with no black
  plate behind them, so the world shows through.
- Mode Matte has a gentle sheen lift (`MatteLift`); the settings window keeps
  the plain face (`MatteBase`).
- Borders keep one physical pixel even when the host's scale changes after
  layout: each `Style.Edge` holder ignores parent scale and takes Blizzard's
  pixel factor (fixed huge rims on nameplate aura buttons).
- Health text glow: on by default, 22%, a soft round halo sized from the
  format (health text is never measured; it can be secret).

The owner may keep tuning textures; expect small edits to
`tools/build_mode_assets.lua` profiles and `Style.Tone` values.

## Next steps, in order

1. **Revisions and tweaks** (started November 16): adjustments to
   finished elements from play. Keep each one focused, tested and gated in
   game; follow the design doc first, then Style, then the module. In
   progress: Revision 1, borders, and Revision 2, type and text glow (below).
2. **Phase 9 release** 0.2.0: release notes and notices. Only when the owner
   says so.
3. **Phase 10** (new coverage) only after decision 2 (below).

New module on the owner's request (November 17, 2026): **Buffs & Debuffs**
(`docs/BUFFS_DEBUFFS.md`), planned on the canvas
https://claude.ai/artifact/73o8fB82wKRQUS314hvg5E and built on branch
`t3/buffs-debuffs`: Mode bars on Blizzard's aura containers standing in for
Blizzard's buff frames, the Player frame's auras moved out of Unit Frames,
custom bars and a blacklist. Run in game by the owner and merged into
`main` (November 17); the last round (Player Debuffs (Boss & Important), the
bar picker row) still waits on its in-game recheck.

### Revision 1: borders (checkpoint, November 16)

The owner felt the shipping Mode edge (Round 4, 2px Gunmetal, top row lit)
"isn't quite what I wanted" and asked for a border with more detail that
still reads clean and Blizzard-like. Study: `design/border-study/` (its README
holds every recipe, the metals, the lighting models and the research notes)
and the live canvas https://claude.ai/artifact/2g21nREnhBy9fkDph2nUkY.

Decided so far (owner):

- **D · Cut Steel is the base border**: 45° cut corners (5px; 3px thin), a
  2px Steel band lit from the top, 1px black inside, 1px shadow outside
  (reach 4px). "D looks the most Blizzard like."
- **C · Corner Caps on some elements**: brighter Steel brackets on the
  corners. Which elements is still open.
- **Soft round is liked too**: D's material with a 12px radius (8px buttons,
  6px controls and nameplates). Whether it is an option, or the shape for
  certain elements, is still open.
- Capsule and oval ends were looked at; not chosen (they would need shape
  masks on the bars).

The metal and lighting questions were settled on November 17 (below). Still
open: C's corner caps (not part of the picks, so not built) and the inner
glint (not built).

**Picks (owner, November 17, 2026), built the same day** on branch
`t3/mode-revisions-borders` (not yet committed or confirmed in game):

- **Mode-Blizz** (`blizz`): D's cut corners, the revised Specular band,
  Silver. Unit Frames and Party Frames (plus cast bars, action buttons, the
  Cooldown Manager and the minimap).
- **Mode-BlizzEmpty** (`blizzEmpty`): the same shape, a flat band a state
  color tints (proc and ready glows, aggro, dispel and target rims).
- **Mode-Thin** (`thin`): cut corners, Bevel, Steel (Gunmetal the option).
  Every window and panel, controls, cards and aura icons.
- **Mode-Round** (`round`): Soft round, Bevel, Silver (Gunmetal the option).
  Nameplates; on a nameplate's height it reads as the pill shape.
- Every module with borders got **Border Style** and **Border Metal**
  (`edgeStyle`, `edgeMetal`; new keys filled from defaults, nothing reset).
- Every style keeps its role's reach, so no layout moved: on frames and
  windows the 1px black line sits just inside the host's edge.
- Art: `tools/build_mode_assets.lua` draws every ring
  `Shared/Style/EdgeData.lua` names (69 files in `Borders/`); the old Round 4
  rim art is gone.

In-game gate (owner): every module's border, the pickers on each page, and the
dispel-colored aura rims on nameplates and party frames.

**Portrait ring** (owner, November 17, 2026): the ring takes the Mode border
texturing, a style's 2px lighting drawn over the whole disc (new art
`Borders/Ring<profile>` for the Specular and Bevel profiles; the old
`RingLight` and unused `RingSheen` are gone). Its own **Ring Style** (every
Mode border style; Mode-Blizz by default) and **Ring Metal** (Default, Silver,
Steel, Gunmetal; Default is the style's own) sit under Portrait Ring while it
is Metal (`portraitRingStyle`, `portraitRingMetal`; new keys filled from
defaults). Class Color and Custom (and the combat red) draw as
Mode-BlizzEmpty: the flat color, no lighting, where they used to tint the
Steel 70%. Portrait Ring's first option reads Metal (was Steel; the saved id
`border` is unchanged). Waiting on an in-game look.

**Portrait ring, colored** (owner, November 18, 2026): from a reference ring
(a reaction-colored band, lightly shaded, with fine black edges), compared pixel by pixel
in the "Portrait Ring Lab" artifact. Every ring gets a 1px black line between
its band and the portrait, on the band's inner pixel (the owner's pick, "In
band": a 2px band, the line, the whole portrait; the ring keeps its size).
Then, from the owner's in-game look, **Ring Style** (any style) and **Ring
Finish** (Default, Silver, Steel, Gunmetal, Class Color, Custom) replace the
Portrait Ring choice, and the default is Mode-Blizz in Class Color at
Portrait Size 165 (Player and Target). A colored ring is its style's lighting
in tones made from the color (`Style.ColorTones`; the owner's pick in the
lab: Specular at Gradient Strength 100%). Class Color Softness is retired:
class and reaction colors are their true colors (owner: "if wanting to change
later I will bring it back"). Layout version 24 moves rings still on Metal to
Class Color, Player and Target portraits at 140 to 165, and removes
`classSoftness`. Waiting on an in-game look.

### Revision 2: type and text glow (November 17)

Mock: https://claude.ai/artifact/BpVXy6tBm8GMXkAy7E21Hg (Expressway only as
static renders).

- **Expressway** stays "used when installed". The free download's Typodermic
  Desktop EULA forbids bundling it in a mod (§4.3, §4.6); shipping it needs
  Typodermic's written permission (an Application License). The owner keeps
  Expressway as the look for headers.
- **Mode Script**: a bold, flowing script for the word "Mode" only (the
  settings wordmark), in Ivory. The owner picked **Damion** from round 2;
  built the same day (Media/Fonts/Damion, `Style.SCRIPT_FONT`, the header
  wordmark "Mode" at 22, bound with `Media:BindFixedFont` so the interface
  Font setting leaves it alone). Waiting on an in-game look.
- **Text glow, Halo** (owner's picks): Deep for health numbers and stack
  counts (10-15%) and cooldown numbers (20%), Ink for unit frame names, Match
  Text offered. Built for Unit Frames (health numbers Deep 15%, names Ink
  20%, each with Glow, Color and Strength on the Text tab) and merged to
  main on the owner's word, November 17. Next: stack
  counts and cooldown numbers (Action Bars, Cooldown Manager). Blizzard's
  cooldown numbers are written by the client, not Lua, so their glow needs a
  way to follow the text first. Party Frames and Nameplates keep the capsule
  until the owner says.
- **First in-game look** (owner, 11px text): the glow read fuzzy and sat like
  a second shadow, down-right. Causes: the text's own 1px black shadow draws
  over the copies on that side (Ink on a dark bar showed almost only there),
  and the 2px outer ring doubled the glow's width. Fix, same day: one ring
  of 8 copies 1px out, and a glowing text drops its shadows (crisp and
  lifted). Waiting on the next in-game look.
- **Settings borders** (owner, in game, November 17): button, dropdown and
  segment rims read thin or missing on one side, with specks at the cut
  corners. Cause: the owner plays at Blizzard's default UI scale (no
  `uiScale` set), where whole UI units fall between physical pixels, and a
  border holder copied its host's fractional rect. Fix: settings borders snap
  their holders to whole pixels (`Style.SnapEdges`, `W.SnapSettings`), and
  faces follow the snapped rect. In-game frames keep the plain anchor.
  Waiting on an in-game look.

### Revision: ModeCDM resource bars and player cast bar (November 17, 2026)

Plan and mockups (owner-approved over four rounds):
https://claude.ai/artifact/QgDguMeW25MVA4hvH5EuVu. Built on branch
`t3/mcdm-bars` (worktree `ModeUI-mcdm`), one gated step at a time.

- **Built, waiting on the in-game gate:** ModeCDM settings version 6. Resource
  bars in Mode-Round and Gunmetal, Dark mode (text in Power Type), thinner
  (Power 10, Combo Points and Alternate Mana 6) with border height floors
  (`Style.EdgeMinHeight`; Mode-Round draws thin bars at 10px), Rim Color
  (metals, Bar Color, Custom), Tick Marks per power type, Grouped or
  Separated combo points with Divider Width and Color, the count on, Full
  Color, and Group Resources. See `docs/COOLDOWN_MANAGER.md`.
- **Next:** the player cast bar moves into ModeCDM (Mode-Round, Dark, icon
  hidden, above Essential; the Unit Frames Player cast bar steps aside while
  it is on; Target and Focus untouched). First the shared pieces move to
  `Shared/` (the Blizzard bar fade from Unit Frames, the interrupt hold from
  Nameplates) with no visible change.
- **Open:** a smaller Mode-Round ring so Mode-Round bars can be thinner than
  10px; the Combo Points default layout (Grouped assumed).
- **First in-game look (owner, November 18, 2026; Rogue):** loads clean;
  dark mode, text, Full Color, Group Resources, Alternate Mana off and Edit
  Mode work. Fixed the same day as settings version 7: the borders showed
  only corner specks (at Blizzard's default UI scale a bar sat between
  pixels; bars now snap onto whole pixels, `ResourceSnap.lua`); heights
  16/10/8; the text always centered with Show Text; Tick Marks behind Show
  Tick Marks, a typed value, one tick plus **+ Add Tick Mark** (up to five),
  each bar's own (Power's tick no longer shows in Combo Points' preview);
  **Full Combo Points Color**. Waiting on the next in-game look.
- **Second in-game look (same day):** much better; the grouped block shows
  its border, but Separate Resources still showed corner specks only. Cause:
  the client draws a sliced texture on a region shorter than its art (64
  rows) scaled down. Fix: `Style.Edge` can draw a ring in pieces (four 1:1
  corners, four edges; DESIGN_LANGUAGE.md, "Pieces"), used by the resource
  bars. The same cause may explain the thin icon and settings rims the owner
  noted earlier; those keep their sliced borders until the owner says.
- **Cast Bar built (November 18, 2026; owner: "It is working, can we
  implement the player cast bar"):** the player's cast bar in ModeCDM
  (settings version 8), in the resource bars' look as tuned in game (pieces,
  whole pixels, Mode-Round Gunmetal, Rim Color, Dark with the Comet head
  alone), above Essential (Buff Icons at their old default move above it),
  icon hidden by default in its own border, Spell Name and Timer each placed
  on its own, any Bar Color, Show Interrupted. Shared first: the Blizzard
  frame fade (`Kit.NativeFade`, from Unit Frames), the interrupt hold
  (`Kit.CastInterrupted`, from Nameplates) and the claim (`Kit.PlayerCast`);
  Unit Frames' Player cast bar steps aside while it's on. See
  COOLDOWN_MANAGER.md, "Cast Bar". Waiting on an in-game look.

### Revision: Mode-Default layout and ModeCDM default bars (November 18, 2026)

Planned with the owner over six rounds in a layout editor (the owner saved
the final layout there): https://claude.ai/artifact/6FWUxBmvD5qerXYSV5vYuT
(a copy of the page and the saved layout: `design/layout-editor/`).
Built on branch `t3/mode-default-layout`.

- **Built:** the layout registry (`Shared/Runtime/Layouts.lua`; ARCHITECTURE.md,
  "Layouts") and the **Mode-Default** profile (DPS / Tank), made once per
  account at login and never switched to on its own. It sets Unit Frames
  (Player and Target either side of Essential, the Player's name on the left
  of its border, a small Focus with its cast bar above the Target, Target of
  Focus off), Party Frames (thin, left of the Player), the Cooldown Manager
  (Essential 46 × 40 seven to a row level with the unit frames, Utility,
  grouped resources, the cast bar and Tracked Buffs stacked on Essential),
  Action Bars (a centered 2 × 2 grid of four bars), Damage Meters (bottom
  right), the Minimap (top right, as wide as the meters) with Buffs &
  Debuffs' Buffs and Debuffs beside it. Places for 1080p and 1440p (the
  center block 25 higher). Icons are 6 wider than tall throughout.
- **Built:** ModeCDM settings version 9: five default bars (Defensive
  Cooldowns, Emphasized Buffs, Left Buffs, Right Buffs, Ultra Emphasized
  Buffs), ordinary custom bars with a preset tag; up to 15 custom bars.
- **Open:** chat's size and place (Blizzard Edit Mode; research first); the
  6px rule as ModeUI's general icon rule (`Style.IconHeight`); a Max Icons
  setting for Essential; the Healer layout (the owner's notes are in the
  editor's Healer tab).
- Checked against the mock client only; waiting on the owner's in-game look.
- **Owner's tuning (November 18, 2026, tested at 1080p; 1440 follows: the
  same sizes and x, its own heights)**, on branch `t3/mode-default-tweaks`:
  - ModeCDM borders for every bar: icon edges drawn in pieces (they read
    square: an icon is shorter than the ring art), **Border Size** (1 or 2px)
    on every bar including resource and cast bars, **Border Color** for
    Mode-BlizzEmpty, Spacing down to -2, the Border glow's rim following the
    bar (DESIGN_LANGUAGE.md, "Cooldown icons").
  - In the layout: every ModeCDM bar Mode-Round Gunmetal, Spacing -1 (one
    shared shadow pixel; owner's pick over 0 and -2), cooldown numbers
    #FF3948 (`Tone.cooldownHot`); Essential and Emphasized Buffs 38 x 30,
    Defensive Cooldowns 36 x 30 on the Player frame's top border (one shared
    shadow pixel, right ends lined up); Utility 69 under Essential; Power
    filled in class color, Combo Points and Alternate Mana filled in their
    own colors (owner's pick).
  - Player and Target at x ±276 (10px from Essential's band); the name at
    Top Right and health text at Bottom Right inside the bar, the level kept;
    Player Buffs 30 x 24, five to a row, under the bottom border (owner's
    pick); party frames at -399 in Dark.
  - Action Bars 1-4 28 x 24, Spacing 2, Mode-Blizz; Micro Menu 28 x 22, one
    row of 16, Mouseover; Bag Bar 28 x 22, Mouseover. Pet and Stance bars
    keep 30 x 24 (not in the notes).
  - A Mode-Default profile made before this keeps the old values (layouts
    only write new profiles). In-game check: **Navigation:** `/modeui`, then
    **Profiles**. **Action:** pick **Mode-Default** in **Profile**, click
    **Delete**; under **Manage**, leave **New from DPS / Tank Layout** empty
    and click **Create**; pick **Mode-Default**, click **Switch to This
    Profile**, then **Reload**. **Required state:** ModeUI and ModeCDM
    updated, a Rogue with a target, out of combat, 1080p. **Confirmation:**
    the CDM icons have rounded Gunmetal rims with one dark pixel between
    them and red cooldown numbers; the frames sit about 10px from Essential;
    Defensive Cooldowns rest on the Player frame's top border and Player
    Buffs under its bottom border, right ends lined up; the name and health
    text sit inside the bar at the right; the micro menu and bags appear on
    mouseover; party frames are dark. Then `/mcdm`, any bar, **Look**:
    **Border Size** shows, and **Border Color** appears with Border Style
    Mode-BlizzEmpty.
- **Second round (owner, November 18, 2026):** Player and Target as tall as
  an Essential icon (24 health + the line + 3 power: a 32px block, 34 with
  its shadow; frames 230 x 52, at x ±268, party frames at -383); text glow
  off on every unit frame; every module on in the layout (`allModules`, for
  the Healer layout too); nameplate health and cast borders in pieces (aura
  icons keep the sliced ring: their dispel color needs one texture);
  character portraits centered and cropped 16% each side. In-game check as
  above (delete and recreate Mode-Default), plus: **Confirmation:** the
  Player and Target bars line up with Essential's icons top and bottom;
  Bags, Chat, Nameplates, Tooltip and Windows are on; nameplate borders show
  whole rounded corners; the portrait's face fills the ring.
- **Third round (owner, November 18, 2026, from in-game screenshots):** every
  aura icon's rim in pieces (Player Buffs looked thin and uneven), each piece
  handed to `AddDispelTypeTexture` (Blizzard's container keeps a list);
  Player Buffs at Spacing 1 (shared shadows); Player and Target without a
  power bar (28 health keeps the 32px block), Frame Width 166 (frames 212 x
  52 at x ±259; party frames at -365); texts 11 / 10 / 10 so the bar isn't
  crowded. Confirmation: Player Buffs show whole rims one dark pixel apart;
  the frames are shorter, without a power bar; name and health sit apart.
- **Fourth round (owner, November 18, 2026):** Portrait Size 145 (frames 206
  x 46 at x ±256, party frames at -359). Defensive Cooldowns and Player
  Buffs clipped the frame after the owner changed Portrait Size: they hung
  from the frame's element, whose height is the ring's. The Player and Target
  bar blocks are now Edit Mode targets (**ModeUI Player Frame Bars**,
  `unitFramesPlayerBars`), and both hang from the block's border;
  `tests/layouts.lua` sweeps Portrait Size 100-200, Health Height 10-60 and
  Frame Width 161-260 and checks neither touches the ring (five buffs in a
  row need Frame Width 161 or more).
- **Fifth round (owner, November 18, 2026):** the Player and Target frames'
  soft drop read as a dark band under Player Buffs and above Defensive
  Cooldowns. Unit Frames gets **Drop Shadow** (Border group, Player and
  Target; on by default), off in the layout.
- **Next (owner):** the Healer layout, in the same editor (its own tab and
  saved record), from the owner's notes in the editor's Healer tab.

## Decisions

From the plan's "Decisions for you" (owner's answers):

1. **Cooldown Manager window:** stays a separate window, and ships as a
   companion addon. The owner named it **ModeCDM** (November 15): it shows as
   its own entry nested under ModeUI in the AddOn list, and its options and
   settings stay linked with ModeUI (`ModeUIDB`, ModeUI's Edit Mode and
   profiles).
2. **New coverage** (Pet, Boss, Arena and Raid frames, Buffs and Debuffs, XP and
   reputation, breath timer, Loot, Objective Tracker, Extra Action button):
   recommended after Phases 0-9, one at a time, most wanted first. **Open:**
   ask the owner before starting Phase 10.
3. **Fonts:** first Geist replaced Expressway as the default (each rebuilt
   module's migration). Then, November 15, after seeing Geist in text-heavy
   windows in game, the owner chose **Expressway when the client has it**
   (an installed addon's copy; ModeUI can't ship the commercial font), with
   Geist as the fallback. The font name "Mode" points at whichever the client
   has; profile typeface step 2 (`Shared/Runtime/DB.lua`) moves every saved
   "Mode Geist" to "Mode"; anyone who picked a different font keeps it.
4. **Lato:** kept registered for one version, removed in Phase 8 (done).
5. **Options → AddOns entry:** none.
6. **Branches and releases:** one branch per phase (`t3/mode-phase-N-<name>`),
   fast-forwarded into `main`; version 0.2.0 at the end; pushes and releases
   only with the owner's go-ahead.

Owner preferences gathered along the way:

- **Edit Mode** (November 15): a slim strip across the top (Highlights,
  Center Lines, Grid, Exit) and a small element panel under it (Position,
  Snap To, Match Size, a small Settings button), replacing the tall window
  whose toggle labels clipped. Match Width and Match Height follow an element
  you click, independent of the anchor.

- **UI scale** (November 15): ModeUI fits itself pixel perfect at 1080p and
  1440p from the screen the game reports. Optimizations' Set UI Scale starts
  on at Pixel Perfect (version 2 migrates profiles still at the old default,
  off); **General** › **UI Scale** has a one-click "Use <scale>" button.

- **Probe addons first.** New designs ship as probe addons (`probes/`,
  `/mprobe <name> [tab]`, zips from `tools/build_probes.ps1` into
  `dist/probes/`, gitignored) so the live addon is never broken while the
  owner can't check. Once a probe is approved, build it into the real module.
- **Icons** are wider than tall: 4px shorter up to 35px wide, 6px from 36px.
- 1px edge-lit rims use half the edge light (the top read heavier).
- **Settings window:** sidebar captions Interface / Panels / System; footer
  keeps Reload and Preview on the left; "strip" layout (rail, preview across
  the top, cards below) for small previews, "split" only for tall ones; tiles
  pack in bands; the window closes when combat starts; the sidebar uses Mode
  Matte.
- **Notes are tips only:** about 90% of descriptive text was removed;
  `W.Note` hides, `W.Tip` keeps usage tips, game-option dependencies, conflicts
  and empty-tab reasons. Run `tests/settings_fit.lua` after any settings
  change (it audits every page at real widths).
- **Segmented choices** sit side by side only when every label fits, else a
  compact dropdown in place (no vertical stacks). Multi-pick lists are
  ChoiceGrid buttons, not toggles.
- **General page grows per phase:** it shows only cards whose settings the
  modules already obey; Accent/Text/Textures/Borders/Shields/Names/Scale/
  Combat cards arrive with the phase that makes modules follow them.
- **Unit Frames** (owner, in game): Portrait Size 140, no lifted shadow, cast
  icon on the portrait side, SemiBold names, Gradient to 50% white.
- **Party Frames:** Mode Glass health; shields on their own tab.

## How the work is done

- **Order:** design doc first, then `Shared/Style/`, then the modules. Files
  stay under 400 lines. Secure frames change only out of combat. No
  placeholder functionality.
- **Saved variables:** never reset `ModeUIDB`. Each module has a settings
  version and a migration; a new default only replaces a value still equal to
  the old default (`Style.SameColor` for colors). Old defaults needed by
  migrations live in `Style.LEGACY` or as named constants in the module, never
  as color literals in modules.
- **Tests:** run every `tests/*.lua` except `harness.lua`, `wow_mock.lua`,
  `design_legacy.lua` and `*_stubs.lua`. They run in a simulated client (no
  WoW rendering, security or taint), so the owner's in-game check is the real
  gate. No Python is needed; any Lua 5.3+ works (on the owner's Windows
  machine, the `lua-language-server.exe` bundled with the VS Code Lua
  extension runs them). A loop:

  ```sh
  for t in tests/*.lua; do case $t in *stubs.lua|*harness.lua|*wow_mock.lua|*design_legacy.lua) continue;; esac
    lua "$t" >/dev/null 2>&1 || echo "FAIL $t"; done
  ```

- **Textures:** `lua tools/build_mode_assets.lua` from the repository root
  regenerates every Mode texture (deterministic; commit the changed TGAs).
- **Manual checks** given to the owner use Navigation / Action / Required
  state / Confirmation with the real control labels.
- **Commits:** commit on the phase branch, fast-forward `main`, push only with
  the owner's go-ahead. Never force-push or reset; no bare `git stash`.

### Things learned the hard way

- **Secret values** (Forever 12.x): unit values can be secret in combat.
  Pass them only to widgets that accept them (`SetValue`, `SetText`,
  `SetVertexColor`, `SetTextColor`, `SetVertexColorFromBoolean`,
  `SetAlphaFromBoolean`). Never measure a FontString that may hold secret
  text; its sizes become secret too.
- **Aura containers** create their buttons once (`initializeFrame`) at
  whatever scale the plate has then, so anything sized from the host's scale
  at that moment goes stale. Hence the edge holders' own pixel grid.
- **LibSharedMedia vs Mode looks:** modules must draw lifted textures in two
  layers (base + lift); see Texture retune above.
- **Masks** (none left in ModeUI but the minimap's shape): a texture holds at most 3 masks; a 4th errors and stops ModeUI
  loading. Mode borders need no masks.
- **Line endings:** the repository has `* -text`; most files are LF but
  `tests/wow_mock.lua` is CRLF (with some LF lines) and `docs/UNIT_FRAMES.md`
  is mixed. Edit those byte-safe (a small Lua replace script) and check
  `git diff --stat` before committing.
- **Blizzard UI source:** use the local mainline copy or the `forever` branch
  of github.com/Gethe/wow-ui-source to confirm APIs; never assume Retail
  behavior applies to Forever.

## Resuming on another machine

1. Clone the repository and check out `main`.
2. Read `AGENTS.md`, this file, `docs/DESIGN_LANGUAGE.md` and
   `docs/ARCHITECTURE.md`.
3. Run the whole test suite; it should pass.
4. To test in game, link or copy `ModeUI/` and `ModeCDM/` into WoW Forever's
   `Interface/AddOns/`. For probes, run `tools/build_probes.ps1` and extract
   the zips from `dist/probes/` into the same folder.
5. Start the next step above on a new branch.
