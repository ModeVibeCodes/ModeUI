> Moved from Play The Game Tools to ModeUI on November 12, 2026. File paths
> below that start with `PlayTheGameTools/` now live under `ModeUI/`, and the
> settings now live in `ModeUIDB` (imported once from the active PTG profile).
> The history below is kept as written.

# Interface: Unit Frames (Player and Target)

## Near-black rim

November 12, 2026, per the owner: the Onyx rim (`Kit.onyx.border`) is now
#25282C instead of slate #6A737D, so frame borders read close to black. The
portrait ring's Default color follows it.

## Mode Gradient on every bar (layout version 12)

November 12, 2026, per the owner: every ModeUI bar uses one texture, **Mode
Gradient** (`Kit.ModeGradient`: a flat fill with a soft white gradient over its
top half, the look the old "Mode" choice gave). The Bar Texture setting is gone,
and layout version 12 removes the saved `texture` key from both frames. ModeUI's
text and interface default to Expressway, with the bundled Lato as the fallback.

November 11, 2026. First module of the **Interface** category and the start of
the Play The Game Tools UI suite. Opt-in (default off), Forever only, built into
PTG with no dependency on ModeTools or any other addon. Static/mock validated
only; **native acceptance is pending**.

## Sky names, lifted shadow on all text, Target copies the Player (layout version 11)

After testing layout version 10 in-game, the owner asked for three changes:

- try their own name color, #91C6FF
- make the crisp shadow treatment the default text style for the UI
- make the Target's text match their Player frame by default

Their Player has health text on the right with Level Offset X −45, so the level
sits at the bar's left end. The mirrored Target flipped the health text to the
left and the offset to +45. That pushed the level onto the health text
("927 25 00%").

- **Sky** (#91C6FF) is the new default Name Color and `M.ACCENT`. Champagne,
  Lilac, Frost, Class Color and Custom remain.
- **Suite text style.** Every unit frame text (name, level, health and power)
  now has the fully opaque shadow one screen pixel down-right plus the lifted
  shadow: one black copy 2 pixels down-right at 45%. Each text has its own
  `lift` font string. Every write goes to both through `Write`/`Formatted`, so
  secret health and power values reach the lift through
  `SetText`/`SetFormattedText` only.
  - **Lifted Shadow** moved to the Text tab, under Text Shadow, and applies to
    all text.
  - Later suite pieces (action bars, nameplates) are meant to reuse this style
    (`M.LIFT_PIXELS`, `M.LIFT_ALPHA`).
- **Matched Target copies the Player's text layout.** With Match Player Frame
  on, the Target uses the Player's alignment and offsets as they are, so its
  health, level and name sit where the Player's do. Portrait-side text still
  clears the Target's own portrait curve.
- **Mirror Player Text** (`mirrorText`, Target only, off by default) is shown
  on every element tab while the Target is matched, next to Match Player
  Frame. It flips the alignment and horizontal offsets to the other side.
  - The grouped level and health text now read in mirror order: health first,
    then the level beside it, toward the portrait.
  - The result is the exact mirror image, so a level moved by its offset no
    longer lands on the health text.
  - It is an identity key, so Copy Style leaves it alone.

Layout version 10 → 11:

- Champagne, Lilac and Frost become Sky, so the new color shows straight away.
  Class Color and Custom are kept.
- `nameLift` becomes `liftedShadow`.
- `mirrorText` starts off.

`/reload` is enough; no new textures were added.

## Champagne, Lilac and Frost names with a lifted shadow (layout version 10)

The owner asked for the Mist names to "pop more", with more contrast and a
slight glow. A brightened Mist (#9EF0DD) with a 12-copy soft glow (commit
267fe03) looked fuzzy in-game, because translucent copies 1–2 pixels apart
smear the letter edges. From an eighth design canvas the owner then asked to
test three colors that contrast the cool Onyx/slate skin, with the cleanest
effect that still gives a slight pop, and no accent line or mark.

- **Name Color** is Champagne (#F2DFB8, default; warm ivory against the slate
  rim), Lilac (#C9BBFF; cool but clearly colored, unlike every reaction
  color), Frost (#EAF1F8; near-white with a cool tint), Class Color (pastel)
  or Custom. The colors are `M.nameAccents`; `M.ACCENT` is Champagne and seeds
  the Custom Name Color and Portrait Ring Color defaults.
- **Lifted shadow** replaces the glow. The name's own shadow is fully opaque
  and exactly one screen pixel down-right (`g.px`; other text keeps the 90%
  shadow at 1 unit). Under it, one black copy of the name sits 2 pixels
  down-right at 45% opacity (`M.LIFT_PIXELS`, `M.LIFT_ALPHA`). It uses whole
  pixels and no blur, so it adds depth while staying crisp. The copy uses the
  name's font, size and outline flag, has no shadow of its own, and a secret
  name goes straight to its `SetText`.
  - **Lifted Shadow** (Name & Level tab, on by default) turns the copy off
    and leaves the crisp shadow.
  - The lift needs Text Shadow (Text tab), so the toggle is hidden while Text
    Shadow is off.

Layout version 9 → 10 sets Name Color to Champagne unless it is Class Color or
Custom, and deletes the retired `nameGlow` and `nameGlowStrength` keys. A
saved Custom Name Color keeps its value. `/reload` is enough; no new textures
were added.

## Locked Onyx skin, class-gradient portrait ring and Mist names (layout version 9)

From a seventh design canvas the owner asked for three changes:

- Onyx colors everywhere, with health defaulting to #1C1E21
- a full portrait border in a subtle class-color gradient
- plain-text names in an accent color

They picked the Mist accent and asked for the skin to be locked to Onyx for
every frame.

- **One skin.** Every frame uses the Onyx look: the round portrait caps one
  rounded bar block inside a 2px slate rim (#6A737D) and a 2px black gap, with
  a 1px hairline between health and power. These are fixed, along with the
  empty bar (#0A0B0C) and the background.
  - Retired: the Palette presets and Custom palette, rim/gap/hairline
    thickness and color, background color and opacity, and border color and
    opacity.
  - Also retired: the Satin Matte, Inset Wells, Mode Rounded, Thin Line and
    None border styles, with their bezels, trim, name plate and level badge.
    Their unused textures (Panel, PanelEdge, Well, WellBezel, Ring, Hairline,
    TileMask) were removed. These styles remain in Git history.
- **Health Color** is Default (Onyx #1C1E21), Class Color (pastel class for
  players, pastel reaction for NPCs) or Custom.
- **Portrait ring.** The portrait frame now sits above the bar block, so its
  whole ring is drawn over the bar's end, followed by the black gap and the
  image. Portrait Ring is one of:
  - Class Gradient (default): a vertical gradient from the pastel
    class/reaction color lightened 35% at the top to 72% of it at the bottom
  - Default: the slate rim
  - Custom
- **Names** are plain text with no sheen or texture. Name Color is Accent (Mist
  #A9D9CF, default), Class Color (pastel) or Custom. Name Position is Above
  Frame or On Health Bar.
- **Settings:** the Border tab is gone, so the element tabs are Frames,
  Layout, Portrait, Name & Level, Health, Power and Text.

Layout version 8 → 9 migrates each frame as follows:

| Setting | Before | After |
| --- | --- | --- |
| Health Color | Palette Grey, Mode Green | Default |
| Health Color | Reaction | Class Color |
| Health Color | Custom | Custom (kept) |
| Name Color | any | Accent |
| Portrait Ring | any except Custom | Class Gradient |
| Name Position | Name Row | Above Frame |
| Level | Name Row | Shown |

Every retired key is deleted from the frame's settings, and explicit choices
such as the level color stay. Layouts 2–7 keep their effects on the keys that
remain: right-aligned names, the 26 health bar, Expressway and the level size.
`/reload` is enough; no new textures were added.

## Pastel class colors, mirrored Target text and element tabs (layout version 8)

The owner asked for three changes, then chose the Soft (40%) pastel strength on
the design canvas:

- the Target's health text aligned left
- settings that can edit every part of the frame, split up piece by piece
- softer, pastel class colors

What changed:

- **Mirrored Target text.** A Target matching the Player now mirrors text
  alignment when its portrait is on the other side. Name alignment, health
  text position and power text position flip LEFT and RIGHT (CENTER stays),
  and horizontal text offsets change sign. The Player's right-aligned
  "31 54%" therefore reads "33 76%" from the Target's left.
- **Level then health.** When the health text is on the left, the level is
  placed first and the health text follows it, so both sides read level first.
- **Class Color Softness** (default 40%, range 0–100). Class and reaction
  colors are blended toward white by this amount. It applies to class-colored
  names, Class / Reaction and Reaction health, and a Class / Reaction portrait
  ring. 0% gives the original colors.
- **Settings by element.** The page now has one tab per element: Frames,
  Layout, Portrait, Name & Level, Health, Power, Border and Text. Each element
  tab starts with an **Editing: Player | Target** switch, shared by all tabs
  for the session. A matched Target shows the Match Player Frame toggle and a
  note instead of controls. A hidden frame says to turn it on in Frames.
  Frames holds visibility, Target Matches Player, the status line and the
  per-frame Reset and Copy Style tools.
- **New settings.** These make every part of the Minimal Rounded frame editable:
  - **Portrait Size** as a percentage of the bar block (`portraitScale`, 150,
    range 100–200). Portrait Ring now also applies to the round portrait.
  - **Name Sheen Strength** (55%), **Name Offset X/Y**, **Level Font Size**,
    **Level Color**, **Level Offset X/Y**, **Health Text Offset X/Y** and
    **Power Text Offset X/Y**.
  - **Palette Fill Color**, **Empty Bar Color**, **Rim Color** and **Gap
    Color**. Palette is now a preset: editing any of these four colors switches
    the frame to the new **Custom** palette. The edit starts from the preset's
    colors, so the other three stay as they looked.
  - **Rim Thickness** (2px, range 1–6), **Gap Thickness** (2px, range 0–6) and
    **Hairline Thickness** (1px, range 0–4), all in whole screen pixels.

  Health and power text offsets also work in the other border styles. Name and
  level offsets are Minimal Rounded only, so their rows show only there.

Layout version 7 → 8 gives the level its own font size, starting from the
health text size it used to share. Every other new key fills from its default,
so the frame looks the same apart from the softer class colors and the mirrored
Target text. No new textures, so `/reload` is enough.

## Onyx, Expressway, encased outline and matched Target (layout version 7)

The owner asked for four changes:

- a darker grey, closer to black
- Expressway text
- a border that clearly encloses the frame
- a Target frame that matches the Player

From a fifth design canvas they chose **A, Encased Outline**.

- **Onyx palette (new default).** The health fill is #474D53 (Satin tint), the
  empty bar #0A0B0C, the rim #6A737D and the inner gap pure black. The rim stays
  lighter than the fill so the case reads against dark scenery. Slate Grey,
  Graphite, Silver and Smoke remain selectable.
- **Encased outline.** The 2px rim still traces the bar and wraps the portrait
  as one outline. The black gap inside it is now 2px (was 1px), around both the
  bars and the portrait, so every part reads as sitting inside one case. The
  hairline between health and power stays 1px.
- **Expressway text.** It is the default font on both frames. PTG registers
  Expressway from an installed AyijeUI or EllesmereUI copy, so the font itself
  is never bundled (it is a commercial font). If no provider is installed, the
  frames use the bundled PTG Lato.
- **Match Player Frame** (Target only, default on). The Target renders with the
  Player's look, mirrored: the same sizes, palette, texture, text, power bar and
  so on. Only its side, visibility and the toggle stay its own, through one
  cached settings proxy (`FrameDB`). Player changes apply to both. While it is
  on, the Target tab shows only the identity controls and the toggle; turn it
  off to customize the Target separately.

Layout version 6 → 7 sets both frames to Onyx and changes PTG Lato to
Expressway; another explicit font is kept. The Target starts matching the
Player. Choices made afterwards are not migrated. No new textures, so `/reload`
is enough if the previous build's textures are already loaded.

## Palettes, round portrait and pixel-perfect borders (layout version 6)

The owner kept the main bar and asked for these changes to the default
Minimal Rounded frame:

- a circular portrait
- a slightly heavier, noticeable border that follows the bar's outline and
  then wraps the portrait
- a main color closer to a true slate grey
- an easily distinguishable grey health vs background palette
- right-aligned text, with the level staying in the health bar
- a slightly taller health bar, with the bars about 2/3 the portrait's height
- pixel-perfect borders

Three palettes were drawn on a fourth design canvas. They ship, together with
the requested true slate grey (the default), as a per-frame **Palette**
setting so they can be compared in-game:

| Palette | Health (Satin tint) | Empty bar | Border | Inner line |
| --- | --- | --- | --- | --- |
| Slate Grey (default) | #708090 | #1C2127 | #4C5866 | #0B0E11 |
| Graphite on Charcoal | #B4B4B4 | #1F1F1F | #4A4A4A | #0A0A0A |
| Silver on Slate | #DEDEDE | #2C3035 | #5A5F66 | #0A0A0A |
| Smoke on Coal | #969696 | #121212 | #3C3C3C | #050505 |

- **Round portrait, bars at 2/3.** The portrait is 1.5× the bar block's
  height (an even pixel count), so the block is about 2/3 of it and centred on
  it. The block starts under the circle's centre. The bars start where the
  portrait's dark inner disc crosses their top edge, less 1px, so the circle's
  curve meets them with no gap. Text on the portrait side, and the name, are
  pushed in by the disc's reach over the bars (`tuck`, 8 units at defaults).
- **One border outline.** The 2px palette border traces the bar and then wraps
  the portrait as a single shape. Draw order gives the union outline: bar border
  (`FrameFill`), portrait border circle (on the bar's layer), the bar's 1px dark
  inner line (`FrameInner`, radius 3, 2px in), the bars, the portrait's 1px dark
  inner disc, then the portrait with Blizzard's circular mask. Each shape's inner
  fill covers the other's border where they overlap, so only the combined outer
  outline shows, and the inner line continues around the portrait where the bars
  meet it. The inner line also shows as the 1px hairline between health and
  power. Circles use the crisp 128px `Circle.tga`.
- **Pixel perfect.** One physical pixel in the frame's units is Blizzard's
  `PixelUtil.GetPixelToUIUnitFactor()` divided by the frame's effective scale.
  Borders, lines, bar heights, insets and the portrait size are whole pixels.
  Frame width and height are even pixel counts, so the centre anchor stays on
  the grid, and Edit Mode positions are snapped to whole pixels too.
  `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`, both registered by Blizzard's
  Forever UI in `SharedUIPanelTemplates.lua`, re-snap the frames. Without
  `PixelUtil`, the size falls back to whole UI units.
- **Text.** The name is right-aligned above the frame. The health text is
  right-aligned in the bar, with the muted level just to its left. With Health
  Text set to None, the level sits alone at the right.
- **Health bar.** The default height is 26, up from 22; a 1px adjustment may be
  added to keep the frame an even pixel height.
- **Health Color → Palette Grey** (Slate Grey by default) is the new default. Class/Reaction, Reaction,
  Mode Green and Custom remain.

Layout version 5 → 6 right-aligns both names (owner request), grows a 22
health bar to 26, and switches health to Palette Grey so the palettes show
immediately. A previous custom health color stays saved; choosing Custom
restores it. Choices made afterwards are not migrated.

## Minimal Rounded (layout version 5)

From a third design canvas (minimal integrated frames), the owner chose
**A, Integrated Tile**, with soft rounded corners rather than a hard edge.
Their brief: a thin, minimal border around the whole frame, no separate borders
on the health/resource bars, the portrait part of the bars with no separation,
no name background, and a class-colored name with a themed text texture.

- **One thin rounded border.** A near-black rounded backing (`FrameFill.tga`,
  32×32, radius 5, slice 6) is the frame's edge. It also shows through as the
  1px hairlines between portrait, health and power. A faint 1px inner highlight
  (`Hairline.tga` at 8% white, 1 unit inside) keeps the edge clean against dark
  scenery. Content sits 2 units in, inside the corner curve, so nothing square
  pokes past the rounded silhouette.
- **Portrait tile.** The portrait fills the outer end of the bar block at its
  full height (health + hairline + power). It uses an unmasked square portrait
  (`SetPortraitTexture(texture, unit, true)`), zoomed 8% to fill, and its
  corners are rounded by `TileMask.tga`. Portrait Side moves it; Portrait Size
  and Ring don't apply.
- **No bar borders.** Health and power sit directly on a #1A1A1A track, with
  the Satin bar fill by default.
- **Level** is a small muted (#B9B9B9) number inside the health bar, opposite
  the health text. Hidden with Level Display → Hidden.
- **Name** sits just above the frame with no plate, spanning the bars and
  aligned by Name Alignment (Player left, Target right). It is class colored for
  players and in Mode reaction colors for NPCs. **Name Sheen** (default on) is
  the text texture: WoW can't fill text with a texture, so a lighter copy of the
  name (55% toward white, no shadow) is clipped to the upper 62% of the font
  height over the base text. Both copies only receive `SetText`, so secret names
  still work. The sheen applies to every border style.
- Background Color/Opacity, Border Color/Opacity, Trim and bar-bezel settings
  are hidden for Minimal Rounded. Its edge is fixed near-black so it stays thin
  and consistent.

Layout version 4 → 5 changes only values still at the previous defaults:
Satin Matte → Minimal Rounded, and text-colored names → class-colored names.
Every other style and explicit choice is kept, and later choices are never
migrated. Satin Matte, Inset Wells, Mode Rounded, Thin Line and None remain.
The three new textures come from `tools/build_unit_frame_textures.py`, and the
others rebuild byte-identically. New media needs a client restart.

## Bar bezels, no outer edge

After seeing Satin Matte in the client, the owner asked to remove the outer
frame border and frame the health/resource bars instead, with a lighter
grey/white border that has its own texture.

- **Show Frame Edge** (per frame, default off) controls Satin Matte's black
  rounded outer edge. Existing profiles take the off default, because the key is
  new.
- Each health/power well sits in a 3-unit **bezel** made from
  `WellBezel.tga` (32×32, outer radius 7, slice 8, built by the same script). It
  has a crisp bright top edge, a softer grey lower half, a horizontal brushed
  grain that stretches naturally along the bars, and a darker inner lip so the
  well reads as set into it. **Bar Border Color** (default #D8D8D8) and **Bar
  Border Opacity** (default 100%) tint it. The bezel replaces the faint
  highlight line under each well, and the two bezels sit 2 units apart.
- The name plate keeps its dark edge, and the portrait keeps its black edge and
  silver trim. Bezels belong to Satin Matte only; other styles are unchanged.

## Satin Matte finish (layout version 4)

From a second design canvas (rounded grey finishes) the owner asked for "a
clean, matte with sheen and texturing to make an elegant look". **Satin Matte**
is now the default Border Style and bar texture for both frames. It keeps the
Inset Wells layout (name plate, recessed wells, silver trim), but rounds every
part and draws it with custom textures. Inset Wells remains available.

Textures are built by `tools/build_unit_frame_textures.py` into
`Media/Textures/UnitFrames/`. The build is deterministic: fixed grain seeds,
8× supersampled anti-aliased silhouettes and byte-identical rebuilds. All five
are neutral grey (R=G=B), multiplied in-game by the frame's colors:

| File | Size | Use |
| --- | --- | --- |
| `Panel.tga` | 64×64, radius 7, slice 8 | Panel and name plate body: soft top-lit satin falloff, a broad highlight band, a 1px inner top highlight and fine softened grain. The grain stretches into a faint brushed texture across wide panels. |
| `PanelEdge.tga` | 64×64, slice 8 | 1.5px anti-aliased rounded outline, tinted black (#0B0B0B) |
| `Well.tga` | 32×32, radius 4, slice 5 | Rounded recessed bar slot with a black rim and baked inner top shadow, tinted #0E0E0E. A faint highlight line sits below it. |
| `Ring.tga` | 64×64 circle | Satin portrait-ring and level-badge body with a curved top rim light |
| `BarSatin.tga` | 64×32 | Satin health/power fill (bright top line, gentle falloff, light grain), tinted by the bar color |

The default tint is #585858 (Background Color); the satin luminance tops out
near 0.9, so the visible body runs from about #4B4B4B to #303030. Background
Color and Opacity tint the satin, and Trim Color recolors the silver
hairlines. Border Color/Opacity are hidden for Satin Matte because its outer
edge is always black. If a satin texture fails to load, the frame falls back to
the crisp Inset Wells lines rather than going transparent. New media files need
a full client restart.

Layout version 3 → 4 changes only values still at the previous defaults:
Inset Wells → Satin Matte, the Mode bar texture → Satin, and a #2B2B2B
background → #585858. Explicit choices are kept, such as another bar texture, a
custom background color, or any opacity, including 0%.

## Inset Wells border (layout version 3)

The owner reviewed three border concepts on a design canvas and chose **B,
Inset Wells**, Blizzard-like but neater. It is now the default
**Border Style**:

- The panel has a crisp double edge: a 1px black outer line (#0B0B0B) and a
  1px inner line in Border Color (#424242). These are flat line textures, so
  they stay sharp at any scale. Vertical lines stop short so corners never
  double up.
- The name sits in a darker **name plate** straddling the panel's top edge
  (about 62% of the bar width, with the same double edge). Name Alignment moves
  the plate (Target defaults to Right, beside its portrait). A row-style level
  sits at the plate's end.
- Health and power each sit in a recessed **well**: a 1px black edge around
  #0E0E0E, a soft top shadow inside, a faint #3A3A3A highlight below, and 3
  units of padding around the colored fill.
- The portrait and level badge keep a black outer edge with a **silver trim**
  hairline (Trim Color, default #9A9A9A) around a graphite ring. Portrait Ring
  "Match Frame" uses Trim Color here; Class / Reaction, Mode Cyan and Custom
  recolor the trim.

Mode Rounded, Thin Line and None remain. Profiles saved at layout version 2
that were still on the previous default (Mode Rounded) adopt Inset Wells once,
and Target's left-aligned name mirrors to the right. Any other border choice is
kept.

**In-game fixes found after the first native look:**

- **Edit Mode registration.** Position Manager measures the stand-in with
  `GetCenter`, which is nil until the frame has an anchor, so registration
  failed in the client. The stand-in now gets a default anchor first. This fix
  came from the owner's checkout and is kept unchanged.
- **Bar fill draw order.** The screenshot showed a gray health bar: the opaque
  track could draw over the colored fill. The fill is now pinned to the
  ARTWORK layer and the track to BACKGROUND −8.
- If the Mode surface texture fails to load, the panel falls back to a flat
  opaque fill instead of the asset's transparent fallback.

## Blizzard-style Mode redesign (layout version 2)

The owner asked for simple Blizzard-style frames using the PTG **mode**
theme's colors, textures, text and borders, with expanded per-frame options.

- **Layout.** A circular portrait sits on the outer edge (Player left, Target
  right, either can be switched) and overlaps a rounded panel. The panel holds
  a name row, health bar and power bar. The level shows in a small badge on the
  portrait, like Blizzard's level circle.
- **Mode materials.** The panel uses `ModeSurface` (rounded satin) and
  `ModeBorder`, tinted with the Mode graphite (#2B2B2B) and line (#424242)
  colors. The portrait ring and level badge use `ModeThumb`. Bars are flat with
  a soft Mode sheen over a #252525 track. Text uses **PTG Lato** in #D4D4D4.
  Health defaults to Mode green (#7FDB97), hostile/neutral reactions use Mode
  red/amber, and Mode cyan (#00F0FF) is available as a ring accent. Panels
  shorter than the rounded slice fall back to a flat fill with a thin line.
- **Every frame is customized independently.** Settings are grouped as Layout,
  Portrait, Name & Level, Health, Power, Background & Border, Text and Style
  Tools. Style Tools has **Reset** and **Copy Style to …**; copying mirrors the
  look but keeps the target frame's side, visibility and Blizzard-hiding choice.
- **Migration.** Phase-1 profiles (no `layoutVersion`) are migrated once. Values
  the user changed from phase-1 defaults carry into each frame. Untouched values
  adopt the Mode defaults. Retired top-level keys stay in the profile, unused.

## Suite plan

One part at a time, each accepted in-game before the next starts:

1. **Unit Frames: Player and Target** (this document).
2. Unit Frames, later phases: target of target, pet, party, then raid; cast
   bars and auras on the PTG frames.
3. Action bars (secure buttons; layout changes only outside combat).
4. Nameplates.
5. Minimap, chat, bags and tooltips. Chat may merge with the planned Reskins →
   Chat Window page rather than duplicate it.

## Reference research

The owner chose **AyijeUI 1.06** (installed in the Forever AddOns folder) as
the reference. Its `License.txt` is *All Rights Reserved* with no permission to
copy, modify or redistribute. EllesmereUI (References\Addons) is likewise
all-rights-reserved. **No code, layout values or media from either addon were
copied.** Only general patterns were studied: one `SecureUnitButtonTemplate`
button per unit, `RegisterUnitWatch` for visibility, `*type1=target` /
`*type2=togglemenu` attributes, frame styling deferred until combat ends, and
`GetClassAtlas` for class-icon portraits. The Mode look reuses PTG's own
character-panel portrait technique (`ModeThumb` rim plus Blizzard's
`TempPortraitAlphaMask`), which the owner has already seen render natively.

## Blizzard API findings (Forever branch of Gethe/wow-ui-source)

- [Blizzard_UnitFrame.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitFrame/Blizzard_UnitFrame.toc)
  loads mainline `[Family]` files with Camelot (`[Game]`) overrides. Forever is
  the mainline client, so Midnight-style secret values apply.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua):
  `UnitHealth` has `SecretReturns = true`. `UnitHealthMax`, `UnitPower`,
  `UnitPowerMax` and `UnitName` are secret under restriction conditions.
  `UnitHealthPercent` and `UnitPowerPercent` take an optional curve.
  `SetPortraitTexture(texture, unitToken)` exists; plain unit tokens are allowed
  from addon code. Every event the module registers is listed there or in
  SystemDocumentation.lua, including `UNIT_PORTRAIT_UPDATE`,
  `UNIT_MODEL_CHANGED` and `PORTRAITS_UPDATED`.
- [SimpleStatusBarAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua):
  `SetMinMaxValues`, `SetValue` and `SetStatusBarColor` are
  `SecretArguments = "AllowedWhenTainted"`.
- [SimpleFontStringAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua):
  `SetText` and `SetFormattedText` accept secret arguments when tainted.
- [CurveConstants.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXMLBase/CurveConstants.lua)
  defines `CurveConstants.ScaleTo100`, which maps a 0–1 percentage to 0–100.
- [SecureTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
  supports the `togglemenu` secure action.
- Mainline PlayerFrame.xml / TargetFrame.xml: the art and bars live in
  `PlayerFrameContainer`/`PlayerFrameContent` and
  `TargetFrameContainer`/`TargetFrameContent`. PetFrame is parented to
  PlayerFrame, and the target cast bar, auras and target of target are children
  of TargetFrame.

## Design

- **Secure buttons.** `PlayTheGameToolsPlayerUnitFrame` and
  `PlayTheGameToolsTargetUnitFrame` use `SecureUnitButtonTemplate`, with
  left-click to target and right-click for the unit menu, plus a unit tooltip on
  hover. They are created on first enable and never in combat.
  `RegisterUnitWatch` shows and hides them. The whole frame, portrait included,
  is clickable.
- **Secret-safe rendering.** Values are passed straight to status bars and
  `SetText`/`SetFormattedText`, never compared, tested or used in arithmetic.
  Percent text comes from `UnitHealthPercent`/`UnitPowerPercent` with
  `CurveConstants.ScaleTo100`. Booleans (dead/connected/player/tapped) count
  only when public `true`; a secret or failed answer is treated as unknown.
  Names may be secret and go straight to `SetText`.
- **Portraits.** Character Portrait uses `SetPortraitTexture`. Class Icon uses
  `GetClassAtlas(class)` only when the function exists and
  `C_Texture.GetAtlasInfo` confirms the atlas; NPCs, unknown classes and missing
  helpers fall back to the character portrait, then to a question-mark icon. The
  image is masked to a circle inside a tinted `ModeThumb` ring: Match Border,
  Class / Reaction, Mode Cyan or Custom.
- **Edit Mode.** PTG's Position Manager refuses protected frames, so each
  frame has a plain stand-in, `PlayTheGameTools<Unit>UnitFramePreview`,
  registered as `unitFramesPlayer`/`unitFramesTarget` (screen anchoring only).
  The stand-in uses the same Mode face with sample values. The secure button
  copies its anchor and scale outside combat. Saved positions live in the shared
  `positions` table.
- **Native frames.** "Hide Blizzard … Frame" sets the alpha of the native
  Container and Content parts to 0 (re-applied if Blizzard restores it) and
  disables the native frame's mouse input. Nothing is reparented and no events
  are unregistered, so the pet frame, combo points/class resources, target auras,
  target cast bar and target of target keep working. Turning the option or
  module off restores the saved alpha and mouse input outside combat.
- **Combat.** Show/hide, size, position, unit-watch and native-frame changes
  are protected. Requests made in combat are kept and applied on
  `PLAYER_REGEN_ENABLED`. Settings controls refuse changes in combat. Health,
  power, text and portrait updates continue in combat.
- **Events.** One event frame with unit-filtered `RegisterUnitEvent` for
  player/target, plus `PLAYER_TARGET_CHANGED`, `PLAYER_ENTERING_WORLD` and
  `PORTRAITS_UPDATED`, registered only while a frame is shown. No polling.

## Settings (`modules.unitFrames`)

`layoutVersion` is 11. `player` and `target` each hold the full set below
(defaults shown). The Target differs only in portrait side (right) and
`matchPlayer` (on). The Onyx rim, gap, empty bar and background are constants
(`M.onyx`), not settings.

| Group | Keys (default; range or choices) |
| --- | --- |
| Visibility | `enabled` (true), `hideBlizzard` (true) |
| Matching | `matchPlayer` (Target on): render with the Player's look and text layout; `mirrorText` (Target, off): mirror the Player's text alignment and horizontal offsets |
| Layout | `scale` 100 (50–200%), `barWidth` 180 (100–400), `healthHeight` 26 (10–60), `showPower` (true), `powerHeight` 10 (2–30), `texture` satin / mode / flat / default / LibSharedMedia status bar |
| Portrait | `showPortrait` (true), `portraitStyle` portrait / class, `portraitSide` left (Target right), `portraitScale` 150 (100–200% of the bar block), `portraitRing` class / border / custom, `portraitRingColor` Mist |
| Name | `showName` (true), `namePosition` above / bar, `nameAlign` RIGHT / LEFT / CENTER, `nameFontSize` 12 (8–24), `nameColorMode` sky / champagne / lilac / frost / class / custom, `nameColor` Sky #91C6FF, `nameOffsetX`/`nameOffsetY` 0 (−100–100), `classSoftness` 40 (0–100%) |
| Level | `levelStyle` badge (shown) / none, `levelFontSize` 11 (6–24), `levelColor` #B9B9B9, `levelOffsetX`/`levelOffsetY` 0 |
| Health | `healthColorMode` default / class / custom, `healthColor`, `healthText` percent / current / both / none, `healthTextPosition` RIGHT, `healthFontSize` 11 (8–24), `healthTextOffsetX`/`healthTextOffsetY` 0 |
| Power | `powerColorMode` type / custom, `powerColor`, `powerText` none / percent / current / both, `powerTextPosition` CENTER, `powerFontSize` 9 (6–20), `powerTextOffsetX`/`powerTextOffsetY` 0 |
| Text | `font` game, `fontMedia` Expressway, `outline` (off), `shadow` (on: opaque, one screen pixel), `liftedShadow` (on; needs `shadow`), `textColor` #D4D4D4 |

"Class Color" uses Global Settings class colors for players and Mode reaction
colors for NPCs, softened by Class Color Softness.
`UnitFrames.Initialize` validates detached profile copies (profile import and
validation). Settings change only through `SetFrameOption`, `ResetFrame` and
`CopyStyle`.

## Limitations and open questions

- Native taint/security behavior, rendering, rounded-slice fit at small sizes,
  portrait masking and unit-menu operation are **unverified in the client**.
  The mock models intent only.
- Whether Forever actually returns secret health/power for player or target in
  ordinary play is unknown. Both paths are supported.
- `AbbreviateNumbers` (Current text) is a client global with no generated
  documentation for secret arguments on Forever. If it errors, the text falls
  back to the percentage.
- `GetClassAtlas` is not confirmed in the Forever source. It is used only when
  present and confirmed by `C_Texture.GetAtlasInfo`; otherwise class style shows
  the character portrait.
- "Above Frame" names sit outside the clickable area.
- Hidden native parts keep their screen space. The native pet frame and class
  resources stay where Blizzard places them; move them with Blizzard's Edit
  Mode if needed.
- No cast bar, auras, combat feedback, threat or raid icon on PTG frames yet.
  Focus, target of target, pet, party and raid frames are later phases.

## Manual checks (native acceptance)

New texture files were added in earlier versions, so restart the client fully
before testing if this is your first build since then (`/reload` cannot find
new media). Check M covers layout version 11 and check N covers version 10
(since version 11, names start in Sky and Lifted Shadow is on the Text tab).
Check O covers version 9 and check P covers version 8 (the mirrored Target text in
check P now needs Mirror Player Text on);
version 9 removed the Border tab and its controls from check P. Checks 1–10 below describe earlier styles;
use check 0 for the current default, and checks 3, 4 and 8–10 still apply as
written.

M. Sky names, lifted shadow on all text, Target copies the Player (layout version 11).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target an NPC. **Required state:** OOC.
     **Confirmation:**
     - Both names are Sky blue.
     - The name, level and health text all have a solid dark shadow with a
       fainter second shadow just below it.
     - The Target's level and health text sit like the Player's: the level
       toward the bar's left end and the health text on the right, with no
       overlap.
   - **Navigation:** `/ptg` → Interface → Unit Frames → Layout tab →
     Editing: Target → Mirror Player Text. **Action:** turn it on, then off.
     **Required state:** OOC. **Confirmation:**
     - With it on, the Target's text is the mirror image of the Player's: the
       health text on the left, the level toward the portrait, and the name
       aligned to the other side, with no overlap.
     - With it off, the text matches the Player again.
   - **Navigation:** Text tab → Editing: Player → Lifted Shadow.
     **Action:** turn it off, then on. **Required state:** OOC.
     **Confirmation:** the fainter second shadow disappears from every text on
     both frames, then returns; the crisp shadow stays.

N. Champagne, Lilac and Frost names with a lifted shadow (layout version 10).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target an NPC. **Required state:** OOC.
     **Confirmation:** both names are warm ivory Champagne with sharp edges
     (no halo), a solid dark shadow and a fainter second shadow just below it.
   - **Navigation:** `/ptg` → Interface → Unit Frames → Name & Level tab →
     Editing: Player → Name Color. **Action:** choose Lilac, then Frost, then
     Champagne. **Required state:** OOC. **Confirmation:** both names turn soft
     violet, then near-white, then Champagne; the shadows stay black.
   - **Navigation:** Text tab → Editing: Player → Lifted Shadow.
     **Action:** turn it off, then on. **Required state:** OOC.
     **Confirmation:** the fainter second shadow disappears and returns; the
     name and its crisp shadow stay.
   - **Navigation:** Text tab → Editing: Player → Text Shadow. **Action:** turn it
     off, open the Name & Level tab, then turn Text Shadow back on.
     **Required state:** OOC. **Confirmation:** with Text Shadow off the name has
     no shadows and Lifted Shadow is hidden; both come back with Text Shadow on.

O. Locked Onyx skin (layout version 9).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target an NPC. **Required state:** OOC.
     **Confirmation:**
     - Health fills are the very dark Onyx grey #1C1E21.
     - Each portrait has a complete ring with no gap where the bar meets it,
       and the ring is a soft gradient of your class color (the NPC's reaction
       color on the Target).
     - Names are plain text with no lighter upper half (now Champagne with a
       lifted shadow; see check N).
   - **Navigation:** `/ptg` → Interface → Unit Frames. **Confirmation:** the
     tabs are Frames, Layout, Portrait, Name & Level, Health, Power and Text,
     with no Border tab, and no Palette, Border Style or Background controls.
   - **Navigation:** Health tab → Editing: Player → Health Color.
     **Action:** choose Class Color, then Custom (pick a color with Custom
     Health Color), then Default. **Required state:** OOC.
     **Confirmation:** the fill turns pastel class color, then your color, then
     Onyx again.
   - **Navigation:** Portrait tab → Editing: Player → Portrait Ring.
     **Action:** choose Default, then Custom (pick a color with Portrait Ring
     Color), then Class Gradient. **Required state:** OOC.
     **Confirmation:** the ring turns slate, then your color, then the class
     gradient.
   - **Navigation:** Name & Level tab → Editing: Player → Name Color.
     **Action:** choose Class Color, then Champagne. **Required state:** OOC.
     **Confirmation:** the name turns pastel class color, then Champagne.

P. Pastel colors, mirrored Target text and element tabs (layout version 8).
   - **Navigation:** game world, Unit Frames on, Target Matches Player on.
     **Action:** `/reload`, then target a player of another class or an NPC.
     **Required state:** OOC. **Confirmation:** the Player reads "level
     health%" right-aligned. The Target reads "level health%" from its left
     edge, away from its portrait. Class-colored names look softer and pastel,
     not saturated.
   - **Navigation:** `/ptg` → Interface → Unit Frames. **Action:** look at the
     tab strip. **Confirmation:** the tabs are Frames, Layout, Portrait, Name &
     Level, Health, Power, Border and Text. Each tab except Frames starts with
     the Editing row and its Player and Target buttons.
   - **Navigation:** Name & Level tab → Editing: Player → Class Color Softness.
     **Action:** drag the slider to 0%, then to 100%, then back to 40%.
     **Required state:** OOC. **Confirmation:** the name goes from the
     original class color, to white, to pastel.
   - **Navigation:** Border tab → Editing: Player → Rim Thickness, Gap
     Thickness and Hairline Thickness. **Action:** change each by 1.
     **Required state:** OOC. **Confirmation:** each line changes by one
     crisp screen pixel. The Target follows while it matches.
   - **Navigation:** Border tab → Editing: Player → Rim Color → Pick.
     **Action:** choose a color. **Required state:** OOC.
     **Confirmation:** the rim around the bars and the portrait changes, and
     Health tab → Palette now shows Custom. Picking Onyx restores the preset.
   - **Navigation:** Layout tab → Editing: Target. **Required state:** OOC.
     **Confirmation:** only Match Player Frame and the note show. Turn Match
     Player Frame off, and the Target's own controls appear. Turn it back on.
   - **Navigation:** Portrait tab → Editing: Player → Portrait Size; Health tab
     → Health Text Offset X/Y; Name & Level tab → Name Offset X/Y, Level Font
     Size, Level Color. **Action:** change each. **Required state:** OOC.
     **Confirmation:** only that part of the frame changes.

0. **Navigation:** game world, Unit Frames enabled. **Action:** restart WoW,
   log in and target an enemy. **Required state:** OOC.
   **Confirmation:** each frame is a rounded bar block about 2/3 the height of
   a larger round portrait at its outer end (Player left, Target right). One
   noticeable 2px slate border runs along the bar and wraps around the portrait,
   with a thin dark inner line that continues around the portrait where the bars
   meet it. Health is a slate grey satin fill over a dark slate empty bar, with the power bar below it, split by
   a 1px line. The level and health text are right-aligned in the health bar, and
   the class-colored name with its sheen is right-aligned above. Edges are crisp,
   not blurred, at your UI scale.
   **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Health →
   Player Palette (and Target tab → Health → Target Palette). **Action:** set
   Player and Target to different palettes and compare, then try the third.
   **Required state:** OOC. **Confirmation:** the health fill, empty bar,
   border and portrait ring change together, per frame.
   **Navigation:** WoW Settings → Graphics → UI Scale (or the window size).
   **Action:** change it. **Confirmation:** the frames re-snap and stay crisp.

1. **Navigation:** `/ptg` → Interface → Unit Frames → header toggle.
   **Action:** switch to Enabled. **Required state:** OOC.
   **Confirmation:** a Blizzard-style Player frame appears left of center. It
   has a circular portrait with a black edge and silver trim on the left, and a
   dark panel with a crisp black and gray edge. The name sits in a plate on the
   panel's top edge, above a **green** health bar and a power bar, each in a
   recessed well, with a level badge on the portrait. Blizzard's player art fades
   out; your pet frame and combo points remain.
2. **Navigation:** game world. **Action:** target an enemy NPC, a friendly
   player and yourself; clear the target. **Required state:** OOC, then in
   combat. **Confirmation:** the mirrored Target frame (portrait on the right)
   shows/hides with your target. It shows the portrait, name, reaction or class
   color, and level badge (`??+` for unknown-level elites), and updates health
   in combat. Blizzard's target auras and cast bar still appear.
3. **Navigation:** game world, PTG Player/Target frames. **Action:**
   left-click, right-click and hover each, including the portrait.
   **Required state:** OOC and in combat. **Confirmation:** left-click targets,
   right-click opens the unit menu, hover shows the unit tooltip, and no
   "Interface action failed" or BugSack error appears.
4. **Navigation:** `/ptg` → window header → Edit Mode. **Action:** drag the
   Player Frame and Target Frame stand-ins, then click Exit.
   **Required state:** OOC. **Confirmation:** Mode-styled stand-ins appear.
   After each drag ends, the real frame jumps to the new spot at the same size.
   Positions survive `/reload`.
5. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Layout and
   Portrait. **Action:** change Player Scale, Player Bar Width, Player Health
   Bar Height, Show Player Power Bar, Player Power Bar Height, Show Player
   Portrait, Player Portrait Style (Class Icon), Player Portrait Side, Player
   Portrait Size and Player Portrait Ring (each option; Custom shows Player
   Portrait Ring Color). **Required state:** OOC. **Confirmation:** each change
   applies immediately. Class Icon shows your class emblem, or the portrait if
   the client lacks it. The Target frame is unchanged.
6. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Name &
   Level, Health, Power. **Action:** try every Player Name Position, Player Name
   Alignment, Player Name Color, Player Level Display, Player Health Color,
   Player Health Text, Player Health Text Position, Player Power Color and
   Player Power Text option, plus the font-size sliders. **Required state:** OOC.
   **Confirmation:** text moves and recolors as labeled. Current text shows
   values such as `3,450`, or falls back to a percentage. Dead/ghost/offline
   units show `Dead`/`Ghost`/`Offline`.
7. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Background &
   Border, Text. **Action:** change Player Bar Texture, Player Background
   Color/Opacity, Player Border Style (Inset Wells, Mode Rounded, Thin Line,
   None), Player Border Color/Opacity, Player Trim Color (Inset Wells only),
   Player Font, Player Text Outline/Shadow and Player Text Color.
   **Required state:** OOC. **Confirmation:** Inset Wells shows the name plate,
   wells and silver trim, and Trim Color recolors the portrait and badge
   hairlines. The other styles switch to the rounded Mode border, a thin line or
   no border, without plate or wells. Text follows the chosen font.
8. **Navigation:** `/ptg` → Interface → Unit Frames → Player tab → Style Tools.
   **Action:** click "Copy Style to Target", then switch to the Target tab and
   click "Reset Target Frame". **Required state:** OOC. **Confirmation:** Target
   first takes the Player look while keeping its portrait on the right, then
   returns to defaults. The Player frame is unchanged by the reset.
9. **Navigation:** `/ptg` → Interface → Unit Frames → Frames tab → Hide
   Blizzard Player Frame / Hide Blizzard Target Frame. **Action:** turn each off
   and on. **Required state:** OOC. **Confirmation:** off restores Blizzard's art
   and click handling; on fades it again.
10. **Navigation:** `/ptg` → Interface → Unit Frames → header toggle.
    **Action:** start combat, switch to Disabled, then leave combat.
    **Required state:** in combat, then OOC. **Confirmation:** Status reads
    "Changes are waiting until you leave combat." After combat the PTG frames
    hide and Blizzard's frames return, with no errors.

## Validation

`python tests/unit_frames.py` covers:

- Defaults and validation.
- Phase-1 migration: changed values carried over, untouched values adopting
  Mode, and repeated runs changing nothing.
- Deferral of in-combat enable/disable; secure attributes and unit watch.
- Mirrored geometry with bars past the portrait.
- Mode surface/border/ring textures and palette.
- Portrait and class-atlas paths, ring and health/power color modes, name and
  level placements, power text, border and texture styles.
- Copy Style and Reset; independence of the two frames.
- Public versus secret rendering. A secret fixture errors on any arithmetic,
  comparison, concatenation or tostring.
- Edit Mode stand-ins and the anchor/scale copy.
- Native fade/restore, and persistence across a profile round trip.

The smoke suite expects 16 modules and 7 categories.
