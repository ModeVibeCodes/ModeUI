# The Mode design language

This is ModeUI's visual standard. Every frame, bar, border, window and settings
page follows it. Its one look is **Mode-Obsidian** (owner, November 20, 2026;
the approved page is https://claude.ai/artifact/FmYkTTQsWESUUoz21vBuvG, kept as
`design/obsidian/approved-mock.html`, with the labeled art in
`design/obsidian/README.md`). When this file and the code disagree, the code is
wrong. A visual change starts here: update this file first, then
`Shared/Style/`, then the modules.

The rules are enforced by `tests/design.lua` (no colors, borders, masks,
texture paths or font files outside `Shared/Style/`), `tests/style.lua` (the
tokens, presets and art themselves) and `tests/obsidian.lua` (every module's
defaults are the look; see "Defaults").

The look before it, Mode-Blizz (cut-corner Specular and Bevel borders in
Silver, Steel and Gunmetal, the Matte, Gradient, Button, Glass, Cast, Panel,
Title and old BG textures, and the Geist typeface), was retired the same day.
Its art, the data and the builder that drew it are kept outside the addon in
`archive/mode-blizz/` and never load; the last code with both looks is commit
`3b601cd`. The history of the redesign is in `docs/MODE_REDESIGN.md` and
`docs/OBSIDIAN.md`.

## Principles

- **Dark first.** Frames, bars and panels are black glass and graphite. Color
  stays in hints: names, spell names, portrait rings, power, and anything that
  needs attention (procs, dispels, aggro, focus, quality). Health is the dark
  part of its bar; damage shows as gray, never as color.
- **Gameplay colors keep their meaning.** Reaction, cast, dispel, quality,
  threat and power colors are never softened or recolored for the look
  (nameplates keep reaction-colored health; cast bars keep their cast colors).
- **One source for everything visual.** Colors come from `Style.Tone`, borders
  from `Style.Edge`, bars from `Style.Bar`, textures from `Style.Asset`, fonts
  from `Style.Font`. Modules never hard-code any of these.
- **Pixel perfect.** Sizes and offsets land on whole physical pixels
  (`Kit.PixelSize`). Every border is one even ring. The settings window is
  laid out in whole UI units, which at a UI scale that isn't pixel perfect
  (Blizzard's default) fall between pixels, so its borders snap onto the
  nearest whole pixels (`Style.SnapEdges`, redone on show, page layout,
  scroll, drag and popups) and button faces follow the snapped rect. The
  Cooldown Manager's resource bars do the same in game: each bar's frame
  hangs from its Edit Mode stand-in nudged onto whole pixels and is checked
  again as the stand-in moves (owner, in game, November 18, 2026).
- **No masks for borders.** Rim art covers its own inner corner, so content
  under a border is never masked. (A frame's own shape, the minimap's
  rectangle, is the one mask, through `Style.SetShapeMask`. A texture holds at
  most 3 masks; a 4th errors and stops ModeUI loading.)
- **Edges inside boxes.** A window, control or card whose edge must stay
  inside its rect (side by side with others, or flush to a screen edge) lays
  the edge inside (`Skin.Box` with `inset` = the preset's reach), and its
  face stops where the edge starts, so no square corner shows past the round
  one.
- **No soft drop under see-through.** A window or panel below 100% opacity
  (or a tooltip, a chat window, a meter) has no soft drop: it would only
  darken what shows through.
- **Every color is a token.** A color a module needs (a gameplay meaning, a
  stat, a default) is a `Style.Tone` token; an old default kept for saved
  settings or migrations is a `Style.LEGACY` entry. Colored text goes through
  `Style.ColorText(text, color)`. `tests/design.lua` checks every file
  outside `Shared/Style/` and `Libs/`; none is exempt.

## Defaults

**Every module's defaults are the look** (owner, November 20, 2026). A new
profile, a module's **Reset**, and a layout's profile all start in
Mode-Obsidian from the module's own defaults; nothing is applied afterwards to
make them so.

- Theme parts (`Modules/<Name>/Theme.lua`,
  `addon.Themes:Contribute("obsidian", moduleId, fn(db))`) only move a profile
  from before November 20, 2026 off its Mode-Blizz defaults, once per profile
  (`profile.themeParts`): a saved color still at its old token takes the new
  one (`Themes.SwapColor`), a border's metal goes back to its style's own
  (`Themes.DefaultMetal`), and the module's look keys take their defaults'
  values. Whatever the player changes afterwards stays.
- `tests/obsidian.lua` builds a profile from defaults alone and runs every
  part over it: a part that still changes anything means a default is not the
  look, and the test fails. A new look value goes into the module's defaults
  (and, for old profiles, its part), never into the part alone.
- A token's value change is a migration: saved colors that still equal the old
  value move to the new one; anything the player chose stays.

## Color tokens (`Style.Tone`)

Two neutral ramps. Frames and buttons use **Mono**, windows and panels use
**Graphite**. The values are Mode-Obsidian's: `Style.ApplyTheme()` sets them in
place at load (so defaults copied from tokens are Mode-Obsidian's) and again
once the profile is checked. The Mode-Blizz values (`Style.BlizzTone`) are kept
only so migrations recognize old saved colors.

| Step | Role | Mono | Graphite |
|---|---|---|---|
| 1 | void | `#000000` | `#000000` |
| 2 | base | `#040405` | `#070708` |
| 3 | panel | `#09090A` | `#0B0B0C` |
| 4 | raised | `#111112` | `#131314` |
| 5 | track | `#19191B` | `#1A1A1C` |
| 6 | line | `#222224` | `#232325` |
| 7 | rim | `#333336` | `#343438` |
| 8 | rimStrong | `#4D4D52` | `#4E4E54` |
| 9 | muted | `#808080` | `#8A857C` |
| 10 | secondary | `#A6A6A6` | `#ADA79C` |
| 11 | text | `#DADADA` | `#E6E1D7` |
| 12 | white | `#FFFFFF` | `#F6F2EA` |

| Token | Value | Use |
|---|---|---|
| `text`, `textBright` | `#E8E3D9`, `#F7F3EA` | warm whites: general text, numbers and counts |
| `darkFill` | `#161618` (Graphite `darkFillGraphite` the same) | dark health: every "Dark"/"Default" health color |
| `slate` | `#46464B` at 85% (`emptyAlpha`) | every empty bar, behind every fill (Mode-BG); semi-transparent on health and power |
| `fillEnd` | `#D6EBFF` at 85% | the ice-white fill-end line |
| `shadow` | black; `shadowAlpha` 65%, `softAlpha` 55% | a border's outer shadow ring, its soft drop |
| `emptyRim` | `#343438` | Mode-Empty's neutral, darker rim: the Cooldown Manager's icons (owner, November 20, 2026) |
| `ivory` | `#EFE6D2` | main accent: highlights, selected tabs, card titles, primary buttons, the target |
| `celadon` | `#B4CDB6` | specialty accent; ON; procs |
| `rosewood` | `#CF6A6F` | specialty accent: focus, priority, destructive; OFF |
| `rosewoodDeep` | `#743B3E` | the OFF toggle block (white text on it) |
| `brand` | `#E2B866` | "Mode" in the ModeUI wordmark ("UI" stays white): the Game Menu button, the minimap addon menu, the AddOn list (owner, November 15, 2026) |
| `gunmetal` | light `#5B5E63`, mid `#46494D`, dark `#33363A` | flat rim colors: the minimap's Rim color, auras without a type, Character slot lines |
| `steel` | light `#8C8F95`, mid `#74777D`, dark `#5B5E63` | settings control faces |
| `metal.obsidian` | hi `#6E6E74`, light `#8C806A`, mid `#2A2A2D`, dark `#18181A`, deep `#19191C` | Mode-Border's own metal (every border's default) |
| `metal.silver`, `metal.steel`, `metal.gunmetal` | five tones each (`Shared/Style/Tone.lua`) | Border Metal options: the same lighting in cooler, grayer tones |

Gameplay colors keep their meaning everywhere and are never softened:

| Group | Values |
|---|---|
| Reaction | hostile `#E5484D`, neutral `#F2C744`, friendly `#46C46B`, tapped `#8C8C8C` |
| Cast | casting `#6CB8FF` (light blue), channeling `#3FBF7F`, not interruptible `#FF6B3D` (orange-red), interrupted `#E5484D`: every Mode cast bar (owner, November 23, 2026; amber `#F2B13C` and gray `#7D838C` before, kept in `Style.LEGACY` for migrations) |
| Dispel (Blizzard) | Magic `#3399FF`, Curse `#9900FF`, Disease `#996600`, Poison `#009900` |
| Item quality | common `#9D9D9D`, uncommon `#1EFF00`, rare `#0070DD`, epic `#A335EE`, legendary `#FF8000` |
| Debuff type (`debuffType`) | aura rims and glows on nameplates and group frames: Magic `#3399FF`, Curse `#AA55FF`, Disease `#CC8833`, Poison `#55BB55`, Enrage `#FF5555`, Bleed `#C82D2D`; crowd control without a type `#FF5948` |
| Power (`powerType`) | Mana `#4096FF`, Rage, Energy, Focus, Happiness (Mode-toned), any other type a neutral gray |
| Threat (`threat`) | aggro `#FF4848`, losing or pulling `#FFA040` |
| Stats (`stat`) | the Character window's stats: Strength `#E85C50`, Agility `#FFD140`, Stamina `#E8B04B`, Intellect and mana regen `#4096FF`, Spirit and healing `#7FDB97`, physical power `#FF8A3D`, spell power `#B07CFF`, crit `#FF6B6B`, hit `#FFB12F`, haste `#7FDBFF`, avoidance `#9AD0EC`, armor `#B9B9B9` |
| Other | cooldown text `#FFB12F`; the role layouts' Cooldown Manager numbers `#FF3948` (`cooldownHot`, owner, November 18, 2026); quest lines in tooltips and the quest and gossip windows' button rims `#FFB12F` (`quest`); lit combo points `#F05454` (`comboPoint`); the totem bar's element rims Earth `#C9924F`, Fire `#E8664F`, Water `#4FA8E8`, Air `#A98FE6` (`totem`); incoming heals `#5CD684` (`healPrediction`); the shield and spark end lines `#F6F8FB` (`finishLine`); a custom aura glow `#FFD15C` (`auraGlow`); Buffs & Debuffs stack counts `#53F24F` (`auraStack`) and time text white (`mono.white`); the portrait's combat ring `#FF6B6B` (`combatRing`); macro names `#69A5B9` (`macro`); unit frame name accents Sky `#91C6FF`, Champagne, Lilac, Frost (`nameAccent`); class colors come from `Domain.UnitColor` (Class Colors may override) |

`Style.LEGACY` holds the pre-Mode defaults that saved settings still hold or
migrations recognize (the Onyx palette `Kit.palette` / `Kit.onyx` alias it,
old window, meter, bag, slot and tooltip defaults). New code never reads it
except to recognize an old value.

## Borders (`Style.Edge`)

One factory. A border is a **role** (a preset: how far it reaches and which
rings it has) drawn in a **style** (its shape and lighting) and a **metal**.
Every ring steps in by its own thickness, so each ring is the same width all
round, and the innermost ring fills its own inner corner, so the content under
it needs no mask. The data is `Shared/Style/EdgeData.lua`, which
`tools/build_mode_assets.lua` also reads, so the art always matches it.

### Styles

| Style | Shape | Lighting | Metal | Use |
|---|---|---|---|---|
| **Mode-Border** (`obsidian`) | soft round corners: 6px heavy, 4px thin | obsidian: dark glass band, lit top row, champagne bottom row | `obsidian` (Silver, Steel, Gunmetal as options) | every border |
| **Mode-Empty** (`obsidianEmpty`) | as Mode-Border | flat: one color | the metal's `hi` when untinted; a state or custom color otherwise | proc, ready, aggro, quest and dispel rims; the Cooldown Manager's icons (in `emptyRim`) |

**The obsidian lighting**, over the ring's own height (top 0%, bottom 100%):
the band's base is the metal's `deep` (dark glass). Over it, a lit top row in
`hi` (100% at the top, 85% at 8%, gone by 42% down the sides) and a warm row
along the bottom in `light`, the champagne caustic (from 62% down, 70% at 92%,
100% at the bottom). A 2px band keeps its outer row dark glass and lights the
inner one. The fades are long and soft (owner, November 20, 2026: the change at
the edge read too dark), and the shadow ring outside the band is black at 65%.
**Flat** is one color (Mode-Empty, and any rim tinted for a state).

**The portrait ring** (`Style.Ring`) is a disc, so its lighting runs over the
disc's whole height (`obsidianRing`): the color (`mid`), a lit top (`hi`, gone
by 32%) and a deeper bottom (`dark`, from 60%, 85% at the bottom). A colored
ring (class or reaction, custom, the combat red) takes five tones made from the
color (`Style.ColorTones`: hi and light 60% and 30% toward white, the color,
dark and deep 45% and 65% toward black). The unit frames draw it in the true
class or reaction color by default, with Ring Style and Ring Finish (a metal,
Class Color or Custom) to change it. Every ring has a 1px black line between
its band and the portrait, on the band's inner pixel, so the color has a fine
black edge on both sides and the ring keeps its size.

The art is white and tinted in game: each lit band is a base ring in one metal
tone with up to two lighting layers over it (each a ring whose alpha follows
the lighting).

### Roles (`Style.EDGE_PRESETS`)

Both styles have the same rings in a role, so changing style never moves a
layout. Outside in: the 1px shadow ring, the band, the 1px black line. On the
heavy roles the black line is drawn just inside the host's edge, over its
outermost pixel.

| Role | Size | Band | Shadow | Black line | Reach | Use |
|---|---|---|---|---|---|---|
| `frame` | heavy | 2px | 1px + soft drop (Player and Target: **Drop Shadow**, off in the role layouts, where icons sit on their borders) | 1px, inside the host | 3px | player, target, action buttons, the minimap |
| `frameThin` | thin | 1px | 1px | — | 2px | minor and boss frames, cast bars, nameplates, icons, auras |
| `group` | thin | 1px | — | — | 1px | party and raid frames (1px apart) |
| `window` | heavy | 2px | 1px + soft drop | 1px, inside the host | 3px | every window and panel, the settings window, popups |
| `card` | thin | 1px | — | 1px | 2px | settings cards (a window border without the shadow) |
| `control` | thin | 1px | 1px | — | 2px | buttons, dropdowns, fields, the slide toggle |
| `line` | thin | 1px flat color | 1px | — | 2px | aura dispel rims, item quality |
| `empty` | thin | 1px or 2px, any color (Mode-Empty) | 1px | — | 2-3px | an element's only border in a custom color: proc ready, aggro, quest and gossip buttons |
| `ring` | circle | 2px: the ring lighting over the whole disc, in a metal or in tones of one color | 1px | 1px, inside the band | 4px | portraits (`Style.Ring`) |

A 1px band on a heavy role (`SetRim(1)`: Minimap Map Border Thin) or a 2px band
on a thin one (aura Border Size 2) keeps the role's other rings.

### Choosing a border

Every module with borders has **Border Style** (Mode-Border, Mode-Empty) and
**Border Metal** (Default, Silver, Steel, Gunmetal; Default is the style's own
metal) on one line (`W.BorderPickers`), saved as `edgeStyle` and `edgeMetal`.
Every module defaults to Mode-Border in its own metal, but the Cooldown
Manager's icon bars, which default to Mode-Empty in `emptyRim`. A module that
could already hide its border keeps that switch (Action Bars and Cooldown
Manager Border Mode/None, Tooltip Border) and shows the pickers while the
border is on. The module's main elements take the choice; its controls, cards,
item slots and aura icons keep their role's default.

An aura rim the game colors by dispel type goes flat first
(`Kit.DispelAuraRim`), so no lighting layer covers the type's color.

**Height floor.** Every ring's corners are drawn 1:1 from sliced art, so a host
must be tall enough for two slice margins on each ring
(`Style.EdgeMinHeight(role, style)`): 6px in the thin roles and 12px in the
heavy ones, either style. A thin bar in its own border draws no shorter than
its floor (its saved height is kept); bars inside a shared border have no
floor of their own.

**Pieces** (`Style.Edge(host, role, { pieces = true })`). The client draws a
sliced texture on a region shorter than its art (64 rows) scaled down: the
corners shrink to specks and a 1px edge to a fraction of a pixel (owner, in
game, November 18, 2026). A border on a thin host draws each ring as eight
textures instead, four corners 1:1 and four edges between them, like
Blizzard's NineSlice frames. The resource bars, the Cooldown Manager's icons
and bars, the nameplates' health and cast boxes, the unit and party frames'
blocks and cast bars, every aura icon and the chat's controls use pieces;
other borders keep one sliced texture per ring. An aura icon on Blizzard's aura
containers hands each of its rim's eight pieces to `AddDispelTypeTexture`
(`Edge:RimTextures()`): the container recolors every one.

**Rim Color** (the Cooldown Manager's resource bars and Cast Bar): one picker
in place of Border Metal: Default Metal, Silver, Steel, Gunmetal (saved in
`edgeMetal`), Bar Color or Custom, which paint the band flat in that color
(`Edge:SetTint`).

**Highlight:** the outer shadow ring takes the accent (1px), so the band keeps
its look. Target uses Ivory; focus uses Rosewood. Group frames tint their band
instead, so their size never changes.

## Prism glow and Backlit dispels

- **Prism glow** (`Style.Glow`, Mode-Prism art): a soft light 8px round a frame
  (`GLOW_OUTSET`), sliced at 14, added light at 55% (`GLOW_ALPHA`), in the
  unit's class or reaction color. A supplement, never a main element: Unit
  Frames show it on mouseover (**Prism Glow**: Off, Mouseover, Always; the
  Focus frame Always); Party Frames on mouseover and on your focus (**Hover
  Glow**, **Focus Glow**, with the white mouse tint off); Nameplates take it
  as the focus style (**Glow**). While it shows, the Player and Target frames'
  soft drop steps aside.
- **Backlit dispels:** the Party Frames' dispel Gradient rises from the bottom
  edge (**Gradient From**: Bottom; 56% fading over 72% of the health), so the
  type's color pools up inside the glass; Top stays an option, and Rim and
  Inner glow remain the other effects.

## Action buttons

- **Shape:** 40 x 34 by default (icons are wider than tall), the icon filling
  the button, cropped, over a Mode-FG face (its base) in Mono panel
  (Background Color and Opacity; it shows in empty slots).
- **Border:** the `frame` edge outside the button (Mode-Border: 2px band, 1px
  black line, 1px shadow and the soft drop; Border Style and Border Metal per
  bar); buttons sit 4px apart outside their shadows (Spacing counts from the
  shadow). Border None hides it.
- **States:** hover lights the outer line Ivory (the edge highlight). A proc
  swaps the rim for Celadon (Mode-Empty, 2px; Proc Glow: Border); Mode Glow,
  Blizzard and None stay options, and a Border ready glow swaps the rim for a
  moment the same way. Pushed darkens the icon, checked tints it Ivory.
- **Icon tints:** out of range Rosewood, not enough power the power blue mixed
  70% toward white, unusable Graphite muted; usable keeps full color.
- **Text:** keybind top right in the Mode typeface Bold 10, Graphite secondary
  (Rosewood out of range); count bottom right in Bold 11, Text bright;
  cooldown numbers centered in Bold 13, the cooldown color; macro names
  Medium. One shadow.
- **Totem bar** (Blizzard's multi-cast bar; owner, November 20, 2026): its
  totem, Call and Recall buttons are Mode buttons in Action Bar 1's look, at
  Blizzard's 30 x 30 and places (Blizzard's Edit Mode still places the bar).
  Each element slot's rim is that element's color, flat (Mode-Empty's way:
  `totem` Earth, Fire, Water, Air), the hint in place of Blizzard's colored
  frames; the empty slots show the face and the same rim. The totem picker
  (flyout) is a Surface panel in Mode-Border with Mode buttons, and its
  arrows the Mode chevron in Ivory. The totem timers under the Player frame
  (Blizzard's TotemFrame) are Mode icons (24 x 20, cropped, not round) in the
  `frameThin` edge, the rim in the element's color for a Shaman's totems, a
  flat swipe, and the time in the Mode typeface Bold 10, Text bright. They
  hang from the Player frame's bar block: under it, 1px outside, growing
  left from its right edge (default, Mode-DPS/TANK), or over its left end
  past the portrait, growing right, with the time on the icon (Mode-Healer).

## Cooldown icons

The Cooldown Manager's icons, tracked bars and resource bars:

- **Icons:** Essential 40 x 34; Utility, Tracked Buffs and Buff Bars 32 x 28;
  Cooldown Bars 40 x 34. The icon fills the item (cropped) over a Mode-FG face
  (its base) in Mono panel, with the `frameThin` edge outside it in
  **Mode-Empty**, its flat band in `emptyRim` (Border Color), a neutral, darker
  rim that lets the icon carry the color (owner, November 20, 2026). Rows leave
  room for the edges, so Spacing (2px) counts between the shadows and a matched
  width includes them. Border None hides the edge and gives its room back.
  Every icon edge is drawn in pieces; a bar's **Border Size** is the band's
  width, 1 or 2px (the reach grows with it); Spacing goes down to -2 (-1:
  neighbours share one shadow pixel, -2: the bands touch).
- **Glows:** Border swaps the rim (a Mode-Empty rim in the glow color over the
  edge, so the icon keeps its size): Celadon for procs and buffs, Ivory for an
  active effect and off cooldown (Mode Glow by default). Mode Glow, Pixel,
  Blizzard and GCD stay options. The Border glow's rim follows the bar's style
  and band width.
- **Cooldown:** a black swipe at 70%; out of range Rosewood (as on action
  buttons).
- **Text:** the Mode typeface Bold; cooldown numbers 13 (10 on the small rows)
  in the cooldown color, counts 11 (10) in Text bright; bar names and times 10.
- **Tracked bars:** 220 x 16; the icon 4px wider than the bar is tall, in the
  `frameThin` edge, 2px from the bar's own edge; Mode-FG in your class color
  (Custom: Ivory) over Mode-BG at 85%, with the Comet spark.
- **Resource bars** (owner, November 17, 2026): each bar in the `frameThin`
  edge (Mode-Border in its own metal), Mode-FG over Mode-BG at 85%, Bold text.
  **Dark** by default: every fill in `darkFill`, combo points too, the fill-end
  line kept, the text in the bar's own color (Power Type; Class Color or
  Custom the options). Combo points in the hostile red, **Grouped** (one edge,
  a 1px Divider Color line between points) or **Separated** (an edge each,
  Spacing between the shadows), the count on their left. **Tick Marks**: up to
  three 1px Ivory lines at power values. **Group Resources** puts Power, Combo
  Points and Alternate Mana in one edge with a 1px black line between them;
  only the block has a floor, so its strips can be thinner.
- **Cast Bar** (the player's, on its own): the resource bars' look, filled in
  your class color by default (owner, November 20, 2026) with the full Comet;
  Not Interruptible and Interrupted keep their own colors. Dark stays a
  choice, with the Comet head alone (`Comet:SetTrail(false)`; a light trail on
  a dark fill read odd). The spell icon in its own border.

## Bars (`Style.Bar`)

- **Fill: Mode-FG**, every bar (health, power, cast, nameplate, meter,
  resource, status, timer; aura timers flat): a dark glass base (100% to 82%
  down the bar) multiplied by the fill color, plus its white lift over the fill
  on its own layer (a faint 1px top line and a soft band of light fading out by
  the middle). Modules draw the base and the lift, never the single baked file
  (its light would multiply away on dark fills); the baked file is for other
  addons.
- **Dark health:** health is `darkFill` (`#161618`) in Mode-FG, on Unit Frames
  and Party Frames by default (**Dark**/Default; Class and Custom remain
  options), but the Target frame's, which is its class or reaction color by
  default (owner, November 20, 2026; its own even while it matches the Player). Nameplates keep reaction and class colors; power keeps its power
  color; cast bars their cast colors.
- **Empty part: Mode-BG** on Slate (`#46464B`): the lighter graphite empty
  part (100% to 76% down), for every bar. Never tinted, class-colored bars
  included. Health and power empty parts are semi-transparent (85%,
  `emptyAlpha`): no black plate sits behind them, so the world shows through
  the gray. Modules offer the opacity; cast bars stay solid.
- **Fill end:** a 1px ice-white line (`fillEnd` at 85%) where the fill stops,
  1px in from the bar's top and bottom so it stays inside the border
  (`Style.FillEnd`); none on bars with a spark.
- **Spark (Comet):** a thin oval head on the fill's leading edge (drawn 10px
  wide, 1px taller than the bar each way) with a 21px trail in the bar's color
  lightened 45%. Cast, channel, nameplate cast and timer bars.
- **Shields (Combined):** below max health the shield attaches to the end of
  health and stops at the end of the bar (no finish line when cut off); at full
  health the whole shield fills back from max, 9% lighter. Texture Mode Shield
  (Hairline): a faint lift tinted from the bar's own color (ADD blend) with a
  45° 1px line every 8px along the bar, drawn at 45% alpha. A bright 1px finish
  line marks the end. A module may offer the shield's look (`Shield:SetLook`):
  its **Texture** (any Mode bar texture; Mode Shield by default), its
  **Color** (follows the health bar by default, or custom) and its
  **Opacity** (100% is the standard look; up to 200%, capped at full alpha).
- **Spark end line** (`Style.EndSpark`): the shield's finish line on a bar
  that rides on another (Party Frames incoming heals): a bright 1px line
  (`finishLine`, `#F6F8FB`) on the fill's end with the Line Glow (5px)
  behind it, tinted from the bar's color lightened 45%. It sits in a clip
  that follows the fill, so an empty bar shows no line, and a bar cut off at
  the health bar's end shows none either.
- **Power bars:** 3px on every unit and group frame.

## Text (`Style.Font`, `Style.SetName`)

- **The Mode typeface: Urbanist** (owner, November 20, 2026: "Everything else
  in this look crushes. Including the font change."): Regular, Medium,
  SemiBold, Bold, static TTF, OFL, bundled, registered as **Mode-Urbanist**
  (Medium, SemiBold, Bold) with LibSharedMedia. Modules store the font name
  "Mode", which points at it. ruRU and CJK clients use Blizzard's font
  (Urbanist has no Cyrillic). An installed Expressway (EllesmereUI, AyijeUI or
  a media pack) is only a font a player may pick; ModeUI ships none.
- **Mode Script: Damion** (owner's pick, November 17, 2026; OFL, bundled): the
  word "Mode" in ModeUI's own wordmark only, in Ivory (`Style.SCRIPT_FONT`).
  Never in game frames. It doesn't follow the interface Font setting.
- One shadow: 1px offset (1, −1) at 95% black (no second, lifted copy);
  OUTLINE only as a player choice.
- **Names:** in SemiBold, in the class or reaction color by default
  everywhere (color only in hints): solid on Unit Frames and Nameplates, Soft
  Class on Party Frames. The Gradient (the color fading to 50% color + 50% white
  across the name, one color per letter, reaching the end color sooner: the
  square root of their place) is an option in each module, also on the unit frames (**Name Color**: Gradient, Sky, Champagne,
  Lilac, Frost, Class Color, Custom); the Party Frames also offer Soft Class
  (55% class + 45% white) and Text Color. Names Forever returns as secret fall
  back to Soft class.
- **Text in bars** (health, power, cast) in Bold. Health text is colored by
  health: Rosewood at 30% and under, through Ivory, to Celadon at full (the
  client evaluates a color curve, since the health percent is secret).
- **Text glow, Halo** (`Style.TextHalo`; owner's picks, November 17, 2026):
  light that hugs the letters. Eight copies of the text sit under it, 1px out
  (N, NE, E … NW), at the glow strength, without outline or shadow; low
  strengths read (5% to 40%). A glowing text has no drop shadow. Glow colors:
  **Deep** (the text's hue, saturation × 1.25 + 0.12, lightness halved:
  `Style.Deep`), **Ink** (the shadow black) and **Match Text**. Off by default
  (no glow behind text in Mode-Obsidian); switched on, Unit Frames health
  numbers take Deep 15% and names Ink 20%. Health text colored by health takes its Deep glow from a
  second color curve, since the color is secret.
- **Health text glow on Party Frames and Nameplates** (a module toggle): a soft
  capsule behind the health numbers in the text's own color (added light, 22%,
  `Style.TextGlow`), 5px past the digits, its width from the format
  (characters × 0.62 × size), on the text's justified side.
- **Placement:** the name sits just above the top border, 9px in from the side
  opposite the portrait: its line's bottom 1px over the frame's edge, on the
  border's shadow pixel, so no letter crosses the rim (owner, November 19,
  2026). Health is right-aligned inside the health bar (padded past a portrait
  on that side).

## Sizes

| Element | Size |
|---|---|
| Player, target | 184 wide; 34 health + 1 + 3 power; portrait ring 165% of the bar block, overlapping, in the true class or reaction color with its 1px black line between band and portrait, the image centered and cropped 16% on every side so the face fills the ring (owner, November 18, 2026) |
| Target of target, focus, pet | 22 health + 3 power, 12px text; no portrait by default |
| Boss | 24 health + 3 power; no portrait by default |
| Cast bar under a frame | 14px with icon, 1–2px below (default 2), edges on the frame's edges; with a portrait it starts where the ring ends |
| Nameplate, enemy | 156 × 16 health box inside the rim; cast bar 12, 1px below (the shadows share a pixel); aura icons with their band: your debuffs 24 × 20, buffs 22 × 18 (as tall as the health box), crowd control 35 × 31; quest 18, raid marker and elite 14 (owner, November 23, 2026) |
| Party, standard | 150 × 34 + 3 power |
| Party, healer | 104 × 54 + 3 |
| Raid, standard / healer | 74 × 34 / 92 × 48 + 3 |
| Party, vertical fill | 62 × 66 + 3 |
| Group spacing | exactly 1px, no shadow |
| Icons (buttons, auras, cooldowns, slots) | wider than tall: 4px shorter up to 35px wide, 6px from 36px (40 x 34); Buffs & Debuffs bars start the same, with width and height each adjustable (owner, November 17, 2026) |
| Auras inside group frames | flush in the corner by default (the frame's rim is their outer border) |

## Windows and panels

Large panels are **Surface**: a flat fill in Graphite panel (`#0B0B0C`) with
the approved mock's sheen (white 4.5% at the top, gone 40% down, no top line,
which would read as a band stretched over a tall panel). Buttons, title strips,
icon faces and cards are **Mode-FG** (its base, or base and lift). Faces with a
lift draw their base times the color plus the white lift, as bars do, never a
baked file. Every window has the `window` edge in Mode-Border.

Blizzard's windows (the Skin layer, `Shared/Skin`, through `Skin.Box` and
`Skin.PaintBox`):

- **Window:** Surface in Graphite panel to the window's edges (at its
  Background Opacity, 100% by default), the `window` edge outside them on a
  layer above everything the window stacks, a 22px Mode-FG title strip in
  Graphite raised over a 1px Graphite line; the title in SemiBold 13, Graphite
  white, centered on the strip clear of the window buttons.
- **Window buttons:** 18px `control` boxes (a Mode-FG face in Graphite raised)
  2px inside the window's top-right corner, the glyph in Graphite secondary;
  hover lights the glyph and the outer line Ivory.
- **Buttons:** Mode-FG faces in Graphite raised inside the `control` edge,
  SemiBold; hover lights the outer line Ivory; disabled text is muted. The
  quest and gossip windows' buttons (Accept, Decline, Complete Quest,
  Continue, Goodbye) take the `empty` edge in the quest tone (`#FFB12F`)
  instead, the same reach (owner, November 17, 2026); disabled, the rim goes
  Graphite rim. **Fields** and **dropdowns:** a Graphite base inside the
  `control` edge, Ivory with focus, hover or an open menu; a dropdown's menu is
  a Mode window.
- **Tabs:** text tabs in SemiBold: the chosen one Ivory with a 2px Ivory bar
  on its window side, the others Graphite muted. When they don't fit (a
  narrow page, such as Edit Mode's panel), `<` and `>` buttons at both ends
  step through them and a 6px scroll bar under the hairline (a Graphite
  track, the thumb as long as the share in view, muted, lighter under the
  mouse) shows how far along they are and drags them. **Side tabs:** `control`
  boxes, the chosen tone (Graphite track) and an Ivory line when checked.
- **Insets:** cards: a Mode-FG face in Graphite raised (a step lighter than the
  window) inside the `card` edge. When the edge sits inside a box, the face
  stops where the edge starts. **Scroll bars:** a 4px Graphite track and thumb
  (rimStrong).
- **Item quality:** the `line` edge in the quality color, inside the slot.
- **Text on Graphite:** dark parchment text (quest, gossip, books) takes the
  Graphite text color, its color fixed so dark inline codes give way too; this
  holds with Window Text off. A window whose content draws under its border
  frame (the World Map), or a see-through one, has no soft drop.
- **Chat:** each window Surface on its message box (the `window` edge inside
  it, Graphite panel at the chat's Background Opacity); the edit box a field in
  the `control` edge in Mode-Border, its outer line Ivory while typing: inside
  the window, see-through on a band shaded a little darker than the window
  (black at 15%) with 3px round it; Below, a Mode field with a Graphite base.
  Tabs are `control` panes resting on the edge (Mode-FG, at 75% with the Glass
  tab style or solid): the open one full height in the chosen tone with an
  Ivory label and line, the others tucked down in Graphite raised. The button
  compartment is one `control` box with 1px Graphite dividers.
- **Damage Meters:** each window Surface (Graphite panel at its Background
  Opacity, the `window` edge inside it), a Mode-FG header in Graphite raised
  over a 1px Graphite line, the title in Graphite text and the timer in
  Graphite muted; rows are Mode-FG bars in class colors on Mode-BG (Slate),
  names and values pure white and outlined; the fight letter is Ivory. The
  header menu is a Mode window.
- **Tooltips:** each Surface (Graphite panel at the tooltip's Background
  Opacity, the `window` edge inside it), the edge's rim in the item's quality
  color (or a player's class color, when chosen); the first line in SemiBold;
  reactions in the gameplay tones and quest lines in the quest tone.
- **Bags:** a Mode window with a Mode-FG header and a Mode field for search;
  slots are Mode slots (Slot Size wide, `Style.IconHeight` tall), a Mono panel
  face with the icon cropped to it, in the `group` edge 1px apart, the rim in
  the quality color (Ivory for new items, the quest tone for quest items), a
  small quest mark on quest items, cooldown numbers in Bold at the count size.
  The header's Clean Up is the broom glyph. The footer holds the Bag Bar, the
  free count in Bold over a thin capacity bar (Celadon, Ivory near full,
  Rosewood full) and the money. The Sort menu is a Mode window.
- **Minimap:** the map in the `frame` edge (Mode-Border; rim 2px, or 1px with
  Map Border Thin; Border Color other than Metal tints it flat), its mask
  square (the rim covers the corners); Blizzard's buttons and the addon
  buttons on Mode tiles (a Mode-FG face in Mono raised, in the `group` edge);
  clock Bold above the zone SemiBold; zone colors are the gameplay reaction
  tones.

## Settings window

A hybrid window, its palette rebuilt from the tokens (`Style.OnThemeApplied`):

- **Main panel:** 1000px wide; header (the "Mode" wordmark in Mode Script,
  Ivory 22, search, profile, close) on a Mode-FG strip; 184px sidebar of
  categories (Interface, Panels, System) on Mode-FG's base, with module icons
  ("Mode Icon&lt;Name&gt;" art) and Celadon/Rosewood status dots; the General
  page's global cards four across (186px); footer with Edit Mode, Copy To…
  (a module's copies), Reset… (Rosewood: the module's reset scopes) and Done
  (Ivory) on the right, and Reload and Preview on the left. The canvas and
  preview pane are Surface.
- **General** holds only global settings that already work; modules add their
  own cards (`module:BuildHomeCard`). **UI Scale** (Optimizations): the screen
  ModeUI detected ("1440p") and one button, "Use 53.33%", that sets the Pixel
  Perfect scale. Pixel Perfect is a whole number of screen pixels per UI unit:
  one up to 2159 pixels tall (1080p 71.11%, 1440p 53.33%), two from 2160 (4K
  71.11%), so every 1px edge lands on a pixel.
- **Visual modules** (`layout = "split"`): the sidebar folds into a 48px icon
  rail, settings sit in a 432px column of cards two across, and a live preview
  fills the rest. The header shows "‹ All modules" and a breadcrumb. Split is
  for tall previews (Party Frames).
- **Small previews** (`layout = "strip"`: Unit Frames, Nameplates, Action
  Bars): the icon rail, the preview in a strip across the top, cards across
  the full width below.
- **Simple modules** (`layout = "page"`): sidebar plus cards four across.
- **Back:** the rail's home icon, "‹ All modules", the wordmark, or Esc
  (module → main panel → close). Esc works through `UISpecialFrames`, so it
  also works in combat without capturing the keyboard.
- **Cards:** a Mode-FG face (its base) in Graphite raised inside the `card`
  border, an 11px uppercase Ivory title, labels above controls, cards 10px
  apart. A page sets `cardColumns` (4 on a sidebar or strip page, 2 in the
  432px split column).
- **Tile packing:** tiles pack in bands, in page order. Each tile goes to the
  shortest column while that column is at least 48px short of the tallest, so
  a long tile on one side takes several short ones on the other. When the
  columns are nearly level the band closes, and the last tile in each column
  stretches so every column ends on the same line.
- **Untitled cards** (a page's status line and quick actions) have no tile:
  they run as a plain strip across the page above the tiles.
- **Segmented choices** (`W.Exclusive`) sit side by side only while every
  label fits on one line; otherwise the same choices turn into a compact
  dropdown in the same place. Segments never stack vertically, wrap, or push
  the controls below them. For more than four options or long labels, use a
  dropdown (`W.Select`) from the start.
- **Text in tiles:** notes wrap to the full width of their tile; row labels are
  sized by their row.
- **Nothing past its tile.** Dropdowns fill their row or column cell. Column
  cells wrap onto another line when a line can't give each one 120px. A
  fixed-width control or label shrinks to its room. Things to pick several of
  are buttons that stay lit while chosen (`page:ChoiceGrid`), not toggles. A
  result line sits under the buttons that produce it. `tests/settings_fit.lua`
  opens every page and tab at the window's real widths and fails on any
  control or text past its tile; every new or rebuilt page must pass it.
- **Notes are tips only.** No descriptions of what a setting does, how ModeUI
  works inside, or a module's status. A note is shown only when the player
  needs it to use something: a hidden interaction, a syntax, a game option the
  feature depends on, a conflict with another addon, or why a tab is empty. In
  code, a module's notes go through `W.Note` (hidden) and the keepers through
  `W.Tip`; rows titled "Status" are hidden.
- **Combat:** the window closes itself when combat starts.
- **Controls:** Slide toggle (Celadon ON with dark text; Rosewood Deep OFF with
  bold white text), rail slider (2px rail, Ivory fill, 4 × 14 blade),
  dropdowns, cards, color swatches, 1px nudges, anchor compass. Labels sit
  above controls with the value on the label line.

### Standard tabs

The owner's settings review (November 21, 2026): the same idea lives in the
same place in every module. Every Interface and Panels module page (and its
Edit Mode panel) uses these tabs, in this order, showing only the ones it has
(`W.STANDARD_TABS`, `Shared/Settings/Taxonomy.lua`); System pages keep their
own. Edit Mode adds **Place**.

| Tab | Sections, in order | Holds |
| --- | --- | --- |
| General | Show, Link, Size, Arrange | a part's own switch, Hide Blizzard's, Match Player, width, height, scale, count, rows, growth, Spacing |
| Fill | Bars, Empty part, Shields, Background | textures, color modes and colors, the empty part, absorbs, background color and opacity |
| Border | Border, Icon borders, Rims | Border (Mode-Border, Mode-Empty, None), Border Metal, Border Size, Padding; aura, button and slot borders; rims recolored by meaning (quality, class, debuff type, target, aggro) |
| Glow | Effects, Highlights, Aura glows, Text glows | proc, ready, Prism and pulse glows with their style, color and time; mouseover, hover and focus highlights; crowd control and dispel glows; name and health text glows |
| Text | Text style, then one card per text | Font, Outline, Shadow, Slug Text; each text's Show, Size, Anchor, Offset, Color |
| Auras | Which auras, Icons, Timer, Stacks | filters, groups, lists, icon size and growth, swipe and timer text, stacks |
| Behavior | When it shows, Fade, Paging and clicks | conditions, combat, fades, paging, click behavior |

Where one tab holds several parts (Unit Frames' health, power and cast bars
all in Fill), each part gets its own card, named for the part. In code a
module opens a tab with `page:Tab(title)` (a later call goes back to the same
tab, so a part's cards can be added from one block of code) and finishes with
`W.StandardTabs(page[, pinned])`.

**One term per idea** (`W.RETIRED_LABELS` lists the retired ones):

| Use | Means | Not |
| --- | --- | --- |
| Show &lt;Part&gt; | a part's own switch | Turn On, Enabled (except the module switch) |
| Spacing | room between items in a row or grid | Gap |
| Padding | room between an edge and what's inside it (below zero: the rim over the icon) | Border Gap, Border Shift |
| Border | which rim: Mode-Border, Mode-Empty or None | Border Style |
| Border Size | a rim's thickness in pixels | Border Thickness |
| Size | a text's size, in its own card | Font Size, Text Size |
| Outline, Shadow | text edge treatment | Text Outline, Text Shadow, Drop Shadow |
| Background Opacity, Bar Opacity | always prefixed by what fades | Opacity on its own |
| None, Class Color | the same menu values everywhere | Hidden or Off for none, Class |
| Copy To…, Reset… | the only two actions, each with a scope menu | Copy & Apply, Copy Style to…, Reset to Defaults |

`tests/settings_taxonomy.lua` builds every element page and fails on a tab
outside the standard set or order, an empty tab, or a retired label.

### Suite defaults (Global › Appearance)

The suite owns the look; elements own their fit. **Appearance** (System)
sets the **Font** every module's text follows and the **Border Metal** every
border follows. A module's Font shows "Suite" and its Border Metal "Suite"
while it follows; picking anything else makes it the module's own, and the
Appearance page lists those modules under **Customized**, each with **Back to
suite**. Changes apply after a reload. Saved: `globalMedia.font` (a font key,
"media:Mode" by default) and `globalMedia.edgeMetal` ("default": each style's
own metal); a module follows with `fontMedia = ""` and `font = "game"`, and
`edgeMetal = "default"`. The settings window itself keeps the Mode typeface.
**Border** (Mode-Border, Mode-Empty or None) stays the element's own: which of
the two rims it wears is part of its role. The Cooldown Manager keeps its own
fonts.

## Edit Mode

ModeUI's own Edit Mode (Blizzard's is left alone: ModeUI never writes to
`EditModeManagerFrame`). It is where elements are placed and, In Place, set
up: click an element and its panel opens beside it.

- **Top bar** (across the top, draggable): Edit Mode, **Elements** (every
  element you can pick, including ones hidden behind others), **Names**,
  **Focus**, Center Lines, Grid with its spacing (16-96 px), **Undo**, **Redo** and
  **Done** (Cancel while Anchor To or Match waits for a click). Opened from a
  module's page, that module's first element is selected. `/modeui edit`
  opens and closes it.
- **Selection:** element names in `Tone.edit.name`; the selected element's
  outline and the guides in `Tone.edit.select`, the one under the mouse in
  `Tone.edit.hover`, others in `Tone.edit.idle`. Only the element and its
  chip take the mouse. The selected element has one chip: its name and size
  ("Target Frame 200×52"), X and Y from the screen's center while it is
  dragged or nudged; above it, else below, else inside, clear of the top bar
  and the panel. It glows: the Prism glow (`Style.Glow`) in
  `Tone.edit.select`, lifted with it above the focus dim.
- **Names** (saved for the account, `ModeUIDB.editMode.names`; default
  Inside): **Inside** puts each name in its element's top-left corner, cut
  short to fit (none on elements under 40 × 16); **Fit** gives each name the
  first clear spot of above, below, inside, left and right, smallest
  elements first, and a name with no clear spot waits for the mouse
  (`Shared/Placement/EditLabels.lua`); **On Hover** names only the element
  under the mouse; **Off** names only the selected element; **Hide All**
  hides outlines and names for the session (the old Highlights switch). The
  element under the mouse is always named, except with Off.
- **Focus** (saved for the account, `ModeUIDB.editMode.focus`; default
  Strong): with an element selected, the screen around it darkens with
  `Tone.edit.scrim` at 0.40 (**Dim**) or 0.55 (**Strong**; 0.65 until the
  owner's in-game look, November 22): four plain
  textures around the element in the DIALOG strata at level 20, taking no
  clicks (`Shared/Placement/EditFocus.lua`). Other outlines and names sink
  under it (Strong hides the other outlines); the selected element's and the
  hovered element's decoration lift above it (level 40); the guides (60),
  the panel and the top bar (80) stay on top. It fades in over 0.12 s, halves
  while dragging so snap targets stay visible, and steps away while Anchor
  To or Match waits for a click.
- **Keys:** arrows nudge one pixel (Shift: ten), Tab and Shift-Tab step
  through the elements, Ctrl-Z undoes, Ctrl-Y or Ctrl-Shift-Z redoes, Esc lets
  go of the element and a second Esc closes Edit Mode.
- **Panel** (432 × 560 px by default): the grip in its bottom corner
  (bottom-left while pinned) resizes it, from 432 × 320 up to 900 px wide
  and the screen's height, saved for the account
  (`ModeUIDB.editMode.panelWidth`, `panelHeight`); the page lays out again at
  the new width. It docks beside the selected element on the side with
  more room, top edges level, never over it; dragged, it stays put until you
  pick another module's element; **Pin** keeps it at the screen's right edge.
  It steps aside while Anchor To or Match waits for a click. Header: the
  element's name, its module, Pin and close. **Settings** is the module's own
  page (the same page object as the settings window, borrowed while Edit Mode
  is open), scoped to the element (`module:OpenElementSettings`), one card
  per row, without its preview: the element on screen is the preview.
  **Place**: Position (X, Y, and four arrows that nudge it one pixel), Snap To (what it hangs from, Anchor To…, side,
  Reset Offset) and Match Size. **Open Page** leaves Edit Mode for the page in
  the settings window. A module with its own window (the Cooldown Manager)
  offers Place and Open Page.
- **Guides:** while dragging, a line shows and the drop snaps (8 UI units)
  to an offset of 0, the screen's center and edges, and other elements'
  centers and edges (lining up, or meeting side by side), only on the axes
  the drag moves.
- **Undo** covers drags, nudges, typed offsets, Snap To, Anchor To and Match
  Size for the session (`Shared/Placement/EditHistory.lua`).

## Texture library

Every texture ModeUI draws from its own art is a key in `Style.ASSETS`,
generated by `tools/build_mode_assets.lua` as power-of-two 32-bit TGA under
`Media/Textures/Mode/`. The bar textures register with LibSharedMedia under
their "Mode-&lt;Name&gt;" names so other addons can use them too.

| Name | Key | Job |
|---|---|---|
| Mode-FG | `FG` (`FGBase` + `FGLift`) | every bar's fill (tinted by its color), button and icon faces, title strips, cards |
| Mode-BG | `BG` | every empty bar (tinted Slate) |
| Surface | `Surface` (`Solid` + `SurfaceLift`) | large panels: windows, chat, tooltips, meters, menus (not in bar menus) |
| Mode Shield | `Shield` | absorbs and overshields (a 32x32 Hairline tile) |
| Mode Solid | `Solid` | flat fills |
| Spark | `CometHead`, `CometTrail`, `LineGlow` | the Comet head and trail; the shield finish line |
| Text Glow | `TextGlow` | the health text capsule |
| Mode-Prism | `Prism` | the glow round a frame (not in bar menus) |
| Mode-Border, Mode-Empty | `Edge<ring>` (`softHeavy*`, `softThin*`), `Ringorh`, `Ringord` | border and portrait ring art |

Module icons (`Style.ICONS`, the settings sidebar and icon rail) and control
glyphs (`Style.GLYPHS`: Clean Up's broom, the quest mark) are white line art
from `tools/mode_icons.lua`, 32x32 under `Icons/`, tinted in game; keys
`Icon<Name>`. Older glyphs and masks (chat compartment, damage meter header,
close and window buttons, nameplate glows, minimap masks, the unit frames'
status badges) come from `tools/build_shape_textures.lua` and
`tools/build_minimap_masks.lua` under `Media.Textures`. Other addons' media is
used only by reference (`Style.PROVIDER_FONTS`, `Style.PROVIDER_MEDIA`) when
installed; ModeUI ships none of it.

## Saved settings from before Mode-Obsidian

Profiles keep working across the change (`Shared/Runtime/DB.lua`,
`Shared/Runtime/Themes.lua`):

- `profile.theme` is always `"obsidian"`; a profile from before (`"blizz"` or
  no key) turns Mode-Obsidian the first time it is checked: each module's part
  once, then the steps below.
- **Old border ids** (`blizz`, `thin`, `round`; `blizzEmpty`) stay valid and
  draw as Mode-Border (Mode-Empty) (`EdgeData` `ALIASES`, `Style.ThemeStyle`);
  a settings check still accepts them (`Style.EdgeStyleChoices()`), a picker
  lists only the two styles.
- **Old texture names** draw as the one they became (`Style.OLD_MEDIA`): empty
  parts Mode-BG, every fill and surface Mode-FG (Mode-Obsidian and
  Mode-Obsidian Track became Mode-FG and Mode-BG).
- **Look step 1** moves saved old texture names (Mode BG drawing a fill takes
  Mode-FG) and saved `edgeStyle` and `portraitRingStyle` ids; **typeface
  step 4** moves saved Geist weights to Urbanist's (Geist's regular, once the
  default, to "Mode").

## Role profiles

Mode's layouts (`Shared/Runtime/Layouts.lua`) build whole profiles in this
look: **Mode-DPS/TANK** (DPS / Tank) and **Mode-Healer**, each made once per
account and seed at login (never made active) and on the Profiles page (**New
from DPS / Tank Layout**, **New from Healer Layout**). A layout part sets
places, sizes, what shows and the layout's own tuning (Mode-Border in its own
metal on every frame, text glows off, the Cooldown Manager's numbers in
`cooldownHot` and its icons in Mode-Empty with `emptyRim`); everything else is
the modules' defaults, so a layout profile is Mode-Obsidian from the start
(the parts still run after the layout's and change nothing).

## Companion addons

Companion addons (the first is `ModeCDM`, the Cooldown Manager) need ModeUI,
draw with its design system (their modules run inside ModeUI's addon table),
keep their settings in `ModeUIDB`, and follow this file exactly like a module
does, defaults included.
