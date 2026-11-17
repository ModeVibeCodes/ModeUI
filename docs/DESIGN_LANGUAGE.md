# The Mode design language

This is ModeUI's visual standard. Every frame, bar, border, window and settings
page follows it. It was finalized with the owner in November 2026; the
interactive reference is the "ModeUI Visual Language" study. When this file and
the code disagree, the code is wrong. A visual change starts here: update this
file first, then `Shared/Style/`, then the modules.

The rules are enforced by `tests/design.lua` (no colors, borders, masks,
texture paths or font files outside `Shared/Style/`) and `tests/style.lua`
(the tokens and presets themselves).

## Principles

- **Blizzard plain, Mode finished.** Default-UI layouts and meanings, with
  near-black surfaces, light metal rims and one warm accent.
- **One source for everything visual.** Colors come from `Style.Tone`, borders
  from `Style.Edge`, bars from `Style.Bar`, textures from `Style.Asset`, fonts
  from `Style.Font`. Modules never hard-code any of these.
- **Pixel perfect.** Sizes and offsets land on whole physical pixels
  (`Kit.PixelSize`). Every border is one even ring.
- **No masks for borders.** Rim art covers its own inner corner, so content
  under a border is never masked. (A frame's own shape, the minimap's
  rectangle, is the one mask, through `Style.SetShapeMask`.)
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
  outside `Shared/Style/` and `Libs/`; none is exempt (Phase 8).

## Color tokens (`Style.Tone`)

Two neutral ramps. Frames and buttons use **Mono**, windows and panels use
**Graphite**.

| Step | Role | Mono | Graphite |
|---|---|---|---|
| 1 | void | `#000000` | `#000000` |
| 2 | base | `#050505` | `#0A0A0B` |
| 3 | panel | `#0E0E0E` | `#121213` |
| 4 | raised | `#161616` | `#1A1A1C` |
| 5 | track | `#1E1E1E` | `#222224` |
| 6 | line | `#282828` | `#2C2C2F` |
| 7 | rim | `#383838` | `#3D3D41` |
| 8 | rimStrong | `#555555` | `#5A5A5F` |
| 9 | muted | `#808080` | `#85858B` |
| 10 | secondary | `#A6A6A6` | `#A9A9AE` |
| 11 | text | `#DADADA` | `#D8D8DB` |
| 12 | white | `#FFFFFF` | `#F5F5F6` |

| Token | Value | Use |
|---|---|---|
| `darkFill` | `#1C1D1C` (Graphite `#1D1D1F`) | dark-mode health fill (every "Dark"/"Default" health color) |
| `slate` | `#575757` at 60% (`emptyAlpha`) | every empty bar, behind every fill; semi-transparent |
| `ivory` | `#EFE6D2` | main accent: highlights, selected tabs, card titles, primary buttons |
| `celadon` | `#B4CDB6` | specialty accent; ON |
| `rosewood` | `#CF6A6F` | specialty accent: focus, priority, destructive; OFF |
| `rosewoodDeep` | `#743B3E` | the OFF toggle block (white text on it) |
| `brand` | `#E2B866` | "Mode" in the ModeUI wordmark ("UI" stays white): the Game Menu button, the minimap addon menu, the AddOn list. A warm gold from the Ivory family, strong enough to read in bold button text where Ivory looks white (owner, November 15, 2026) |
| `gunmetal` | light `#5B5E63`, mid `#46494D`, dark `#33363A` | flat rim colors: the minimap's Rim color, auras without a type, Character slot lines |
| `steel` | light `#8C8F95`, mid `#74777D`, dark `#5B5E63` | portrait rings, settings control faces |
| `metal.silver` | hi `#F2F4F6`, light `#D9DCE0`, mid `#9A9EA4`, dark `#5C6066`, deep `#3A3D41` | border metal: Mode-Blizz and Mode-Round |
| `metal.steel` | hi `#D4D7DC`, light `#A3A6AB`, mid `#6E7176`, dark `#3D4044`, deep `#26282B` | border metal: Mode-Thin |
| `metal.gunmetal` | hi `#A5A9AF`, light `#7C8086`, mid `#4E5156`, dark `#2C2E31`, deep `#1A1B1D` | border metal (an option on every border) |

Gameplay colors keep their meaning everywhere and are never softened:

| Group | Values |
|---|---|
| Reaction | hostile `#E5484D`, neutral `#F2C744`, friendly `#46C46B`, tapped `#8C8C8C` |
| Cast | casting `#F2B13C`, channeling `#3FBF7F`, not interruptible `#7D838C`, interrupted `#E5484D` |
| Dispel (Blizzard) | Magic `#3399FF`, Curse `#9900FF`, Disease `#996600`, Poison `#009900` |
| Item quality | common `#9D9D9D`, uncommon `#1EFF00`, rare `#0070DD`, epic `#A335EE`, legendary `#FF8000` |
| Debuff type (`debuffType`) | aura rims and glows on nameplates and group frames: Magic `#3399FF`, Curse `#AA55FF`, Disease `#CC8833`, Poison `#55BB55`, Enrage `#FF5555`, Bleed `#C82D2D`; crowd control without a type `#FF5948` |
| Power (`powerType`) | Mana `#4096FF`, Rage, Energy, Focus, Happiness (Mode-toned), any other type a neutral gray |
| Threat (`threat`) | aggro `#FF4848`, losing or pulling `#FFA040` |
| Stats (`stat`) | the Character window's stats: Strength `#E85C50`, Agility `#FFD140`, Stamina `#E8B04B`, Intellect and mana regen `#4096FF`, Spirit and healing `#7FDB97`, physical power `#FF8A3D`, spell power `#B07CFF`, crit `#FF6B6B`, hit `#FFB12F`, haste `#7FDBFF`, avoidance `#9AD0EC`, armor `#B9B9B9` |
| Other | cooldown text `#FFB12F`; quest lines in tooltips `#FFB12F` (`quest`); lit combo points `#F05454` (`comboPoint`); incoming heals `#5CD684` (`healPrediction`); a custom aura glow `#FFD15C` (`auraGlow`); the portrait's combat ring `#FF6B6B` (`combatRing`); macro names `#69A5B9` (`macro`); unit frame name accents Sky `#91C6FF` (default), Champagne, Lilac, Frost (`nameAccent`); class colors come from `Domain.UnitColor` (Class Colors may override) |

`Style.LEGACY` holds the pre-Mode defaults that saved settings still hold or
migrations recognize (the Onyx palette `Kit.palette` / `Kit.onyx` alias it,
old window, meter, bag, slot and tooltip defaults). New code never reads it
except to recognize an old value.

Changing a token's value is a migration: saved colors that still equal the old
value move to the new one; anything the player chose stays.

## Borders (`Style.Edge`)

One factory. A border is a **role** (a preset: how far it reaches and which
rings it has) drawn in a **style** (its shape and lighting) and a **metal**.
Every ring steps in by its own thickness, so each ring is the same width all
round, and the innermost ring fills its own inner corner, so the content under
it needs no mask. The look was chosen in the border study (Revision 1,
`design/border-study/`, owner, November 17, 2026).

### Styles

| Style | Shape | Lighting | Metal (default; options) | Default for |
|---|---|---|---|---|
| **Mode-Blizz** (`blizz`) | 45° cut corners: 5px heavy, 3px thin | Specular band | Silver; Steel, Gunmetal | Unit Frames, Party Frames, cast bars, action buttons, Cooldown Manager, the minimap |
| **Mode-BlizzEmpty** (`blizzEmpty`) | as Mode-Blizz | Flat: one color, tinted by state | Silver's mid when untinted | proc and ready glows, aggro, dispel and target rims; a choice for colored fills |
| **Mode-Thin** (`thin`) | as Mode-Blizz | Bevel | Steel; Gunmetal, Silver | every window and panel (Blizzard windows, Chat, Damage Meters, Tooltip, Bags, the settings window), controls, cards, auras (Buffs & Debuffs bars: Mode-Blizz by default, Border Style per bar) |
| **Mode-Round** (`round`) | Soft round: 12px heavy, 6px thin | Bevel | Silver; Gunmetal, Steel | nameplates |

Lighting, over the ring's own height (top 0%, bottom 100%):

- **Specular band**, 2px: mid, hi at 16%, mid 32%, dark 56%, mid 82%, light at
  the bottom (the bottom edge stays lit). 1px: mid, hi 16%, mid 34%, dark 58%,
  light.
- **Bevel**, 2px: a lit outer lip (hi, light 40%, mid) over a shaded inner row
  (mid, dark 50%, deep). 1px: hi fading to mid.
- **Flat**: one color (Mode-BlizzEmpty, and any rim tinted for a state).

The art is white and tinted in game: each lit band is a base ring in one metal
tone with up to three lighting layers over it (each a ring whose alpha follows
the lighting), so every metal draws the study's gradient exactly.

### Roles (`Style.EDGE_PRESETS`)

Every style has the same rings in a role, so changing style never moves a
layout. Outside in: the 1px shadow ring, the metal band, the 1px black line.
On the heavy roles the black line is drawn just inside the host's edge, over
its outermost pixel, so they reach exactly as far as before the line (no
layout moved for it).

| Role | Size | Band | Shadow | Black line | Reach | Default style | Use |
|---|---|---|---|---|---|---|---|
| `frame` | heavy | 2px | 1px + soft drop | 1px, inside the host | 3px | Mode-Blizz | player, target, action buttons, the minimap |
| `frameThin` | thin | 1px | 1px | — | 2px | Mode-Blizz | minor and boss frames, cast bars, nameplates, icons, auras |
| `group` | thin | 1px | — | — | 1px | Mode-Blizz | party and raid frames (1px apart) |
| `window` | heavy | 2px | 1px + soft drop | 1px, inside the host | 3px | Mode-Thin | every window and panel, the settings window, popups |
| `card` | thin | 1px | — | 1px | 2px | Mode-Thin | settings cards (a window border without the shadow) |
| `control` | thin | 1px | 1px | — | 2px | Mode-Thin | buttons, dropdowns, fields, the slide toggle |
| `line` | thin | 1px flat color | 1px | — | 2px | Mode-Thin | aura dispel rims, item quality |
| `empty` | thin | 1px or 2px, any color | 1px | — | 2-3px | Mode-BlizzEmpty | an element's only border in a custom color: proc ready, aggro |
| `ring` | circle | 3px Steel, edge-lit | 1px | — | 4px | — | portraits, badges (`Style.Ring`) |

A 1px band on a heavy role (`SetRim(1)`: Minimap Map Border Thin) or a 2px band
on a thin one (aura Border Size 2) keeps the role's other rings.

### Choosing a border

Every module with borders has **Border Style** (Mode-Blizz, Mode-BlizzEmpty,
Mode-Thin, Mode-Round) and **Border Metal** (Default, Silver, Steel, Gunmetal;
Default is the style's own metal) on one line (`W.BorderPickers`), saved as
`edgeStyle` and `edgeMetal`. A module that could already hide its border keeps
that switch (Action Bars and Cooldown Manager Border Mode/None, Tooltip Border)
and shows the pickers while the border is on. The module's main elements take
the choice; its controls, cards, item slots and aura icons keep their role's
default. Defaults: Mode-Blizz for Unit Frames, Party Frames, Action Bars, the
Cooldown Manager and the Minimap; Mode-Round for Nameplates; Mode-Thin for
Windows, Chat, Damage Meters, Tooltip and Bags.

An aura rim the game colors by dispel type goes flat first
(`Kit.DispelAuraRim`), so no lighting layer covers the type's color.

Highlight: the outer shadow ring takes the accent (1px), so the metal band keeps
its look. Target uses Ivory; focus uses Rosewood. Group frames tint their band
instead, so their size never changes.

## Action buttons

- **Shape:** 40 x 34 by default (icons are wider than tall), the icon filling
  the button, cropped, over a Mode Button face in Mono panel (Background
  Color and Opacity; it shows in empty slots).
- **Border:** the `frame` edge outside the button (Mode-Blizz: 2px Silver
  Specular band, 1px black line, 1px shadow and the soft drop; Border Style
  and Border Metal per bar); buttons sit 4px apart outside their shadows
  (Spacing counts from the shadow). Border None hides it.
- **States:** hover lights the outer line Ivory (the edge highlight). A proc
  swaps the rim for Celadon (Mode Empty, 2px; Proc Glow: Border); Mode Glow,
  Blizzard and None stay options, and a Border ready glow swaps the rim for a
  moment the same way. Pushed darkens the icon, checked tints it Ivory.
- **Icon tints:** out of range Rosewood, not enough power the power blue
  mixed 70% toward white, unusable Graphite muted; usable keeps full color.
- **Text:** keybind top right in Geist Bold 10, Graphite secondary (Rosewood
  out of range); count bottom right in Geist Bold 11, Text bright; cooldown
  numbers centered in Geist Bold 13, the cooldown color; macro names Geist
  Medium. One shadow.

## Cooldown icons

The Cooldown Manager's icons, tracked bars and resource bars (the approved
Phase 6 probe):

- **Icons:** Essential 40 x 34; Utility, Tracked Buffs and Buff Bars 32 x 28;
  Cooldown Bars 40 x 34. The icon fills the item (cropped) over a Mode Button
  face in Mono panel, with the `frameThin` edge outside it (Mode-Blizz: 1px
  Silver Specular band, shadow ring; Border Style and Border Metal per bar).
  Rows leave room for the edges, so Spacing (2px)
  counts between the shadows and a matched width includes them. Border None
  hides the edge and gives its room back.
- **Glows:** Border swaps the rim (a Mode Empty rim in the glow color over the
  edge, so the icon keeps its size): Celadon for procs and buffs, Ivory for an
  active effect and off cooldown (Mode Glow by default). Mode Glow, Pixel,
  Blizzard and GCD stay options.
- **Cooldown:** a black swipe at 70%; out of range Rosewood (as on action
  buttons).
- **Text:** Geist Bold; cooldown numbers 13 (10 on the small rows) in the
  cooldown color, counts 11 (10) in Text bright; bar names and times 10.
- **Tracked bars:** 220 x 16; the icon 4px wider than the bar is tall, in the
  `frameThin` edge, 2px from the bar's own edge; Mode Gradient (base and lift)
  in your class color (Custom: Ivory) over solid Mode BG, with the Comet spark.
- **Resource bars:** each box in the `frameThin` edge, Mode Gradient over Mode
  BG at 60%, Geist Bold text; combo points in the hostile red, Spacing between
  the shadows.

## Bars (`Style.Bar`)

- **Empty part:** Mode BG on Slate, for every bar (unit, group, nameplates,
  cast, tracked, power, status). Never tinted, class-colored bars included.
  Health and power empty parts are semi-transparent (60%, `emptyAlpha`): no
  black plate sits behind them, so the world shows through the gray. Modules
  offer the opacity; cast bars stay solid.
- **Light:** a fill texture with a lift (Matte, Gradient, Button, Glass, Cast,
  Panel) draws as its base multiplied by the fill color plus the white lift
  over the fill on its own layer, in every module (not the single baked file,
  whose light the multiply would darken away on dark fills). The baked files
  are only for other addons.
- **Fill textures:** dark-mode health Mode Matte (a soft top-down gradient
  with a gentle sheen: a faint top line and a light band fading out by the
  middle; Mode BG alternate); class
  health Mode Gradient; nameplates Mode BG or Mode Gradient; cast bars Mode
  Cast; power Mode Gradient everywhere; meter bars Mode Panel.
- **Fill end:** a 1px white line at 70% where the fill stops, except on bars
  with a spark.
- **Spark (Comet):** a thin oval head (4px wide) with a 21px trail in the bar's
  color lightened 45%. Cast, channel, nameplate cast and timer bars.
- **Shields (Combined):** below max health the shield attaches to the end of
  health and stops at the end of the bar (no finish line when cut off); at full
  health the whole shield fills back from max, 9% lighter. Texture Mode Shield
  (Hairline): a faint lift tinted from the bar's own color (ADD blend) with a
  45° 1px line every 8px along the bar (about 5.7px apart), drawn at 45%
  alpha. A bright 1px finish line marks the end. A module may offer the
  shield's look as options (`Shield:SetLook`): its **Texture** (any Mode bar
  texture; Mode Shield by default), its **Color** (follows the health bar by
  default, or a custom color for the lift and the lines) and its **Opacity**
  (100% is the standard look above; up to 200%, capped at full alpha). The
  finish line stays bright.
- **Power bars:** 3px on every unit and group frame.

## Text (`Style.Font`, `Style.SetName`)

- **The Mode typeface: Expressway** (owner's decision, November 15, 2026: it
  reads best in WoW, most of all in text-heavy windows), numbers included,
  when the client has it: the copy an installed addon ships (EllesmereUI,
  AyijeUI) or a media pack's LibSharedMedia "Expressway". ModeUI does not ship
  Expressway (a commercial Typodermic font). Without it the typeface is
  **Geist** (Regular, Medium, SemiBold, Bold; static TTF, OFL, bundled). The
  weights below map to Expressway Bold for SemiBold and Bold when present,
  else to Expressway. Modules store the font name "Mode", which points at
  whichever typeface the client has. CJK clients fall back to Blizzard's
  font. (Where this file says "Geist Bold" or "Geist SemiBold", read "the
  Mode typeface" in that weight.)
- One shadow: 1px offset (1, −1) at 95% black (no second, lifted copy);
  OUTLINE only as a player choice.
- **Names:** in SemiBold, and the Gradient is standard (class or reaction
  color fading to 50% class + 50% white across the name, one color per letter,
  the letters reaching the end color sooner (the square root of their place);
  names Forever returns as secret fall back to Soft class). Options: Soft class
  (55% class + 45% white), White.
- **Text in bars** (health, power, cast) in Geist Bold. Health text is colored
  by health: Rosewood at 30% and under, through Ivory, to Celadon at full
  (the client evaluates a color curve, since the health percent is secret).
- **Health text glow** (on by default, a module toggle): a soft halo behind
  the health numbers in the text's own color (added light, 22%), fading out
  round and soft 5px past the digits, with no visible edge. Its width comes from the format (characters × 0.62 × size),
  never from measuring, since health text can be secret; it sits on the
  text's justified side and follows the text's color and visibility.
- **Placement:** the name sits on the top border, 9px in from the side
  opposite the portrait, lifted so the rim runs near its baseline. Health is
  right-aligned inside the health bar (padded past a portrait on that side).

## Sizes

| Element | Size |
|---|---|
| Player, target | 184 wide; 34 health + 1 + 3 power; portrait ring 140% of the bar block (58px), overlapping, Steel Sheen, no gap, the image cropped a little toward the face over a dark disc |
| Target of target, focus, pet | 22 health + 3 power, 12px text; no portrait by default |
| Boss | 24 health + 3 power; no portrait by default |
| Cast bar under a frame | 14px with icon, 1–2px below (default 2), edges on the frame's edges; with a portrait it starts where the ring ends |
| Party, standard | 150 × 34 + 3 power |
| Party, healer | 104 × 54 + 3 |
| Raid, standard / healer | 74 × 34 / 92 × 48 + 3 |
| Party, vertical fill | 62 × 66 + 3 |
| Group spacing | exactly 1px, no shadow |
| Icons (buttons, auras, cooldowns, slots) | wider than tall: 4px shorter up to 35px wide, 6px from 36px (40 x 34); Buffs & Debuffs bars start the same, with width and height each adjustable (owner, November 17, 2026) |
| Auras inside group frames | flush in the corner by default (the frame's rim is their outer border) |

## Windows and panels

Graphite panel `#121213` with the Mode Panel texture, title bar `#1A1A1C` with
Mode Title (Solid as an option), `window` border. Dispel indicators: Gradient
from the top edge (56% → 0 over 72%) by default, Rim and Inner glow as options.

Blizzard's windows (the Skin layer, `Shared/Skin`, through `Skin.Box` and
`Skin.PaintBox`; the approved Phase 7 probe):

- **Window:** the Graphite panel in Mode Panel to the window's edges (at its
  Background Opacity, 100% by default), the `window` edge outside them on a
  layer above everything the window stacks, a 22px Mode Title strip in
  Graphite raised over a 1px Graphite line; the title in Geist SemiBold 13,
  Graphite white, centered on the strip clear of the window buttons.
- **Window buttons:** 18px `control` boxes (Mode Button face, Graphite
  raised) 2px inside the window's top-right corner, the glyph in Graphite
  secondary; hover lights the glyph and the outer line Ivory.
- **Buttons:** Mode Button faces in Graphite raised inside the `control`
  edge, Geist SemiBold; hover lights the outer line Ivory; disabled text is
  muted. **Fields** and **dropdowns:** a Graphite base inside the `control`
  edge, Ivory with focus, hover or an open menu; a dropdown's menu is a Mode
  window.
- **Tabs:** text tabs in Geist SemiBold: the chosen one Ivory with a 2px
  Ivory bar on its window side, the others Graphite muted. **Side tabs:**
  `control` boxes, the chosen tone (Graphite track) and an Ivory line when
  checked.
- **Insets:** cards: a Mode Matte face in Graphite raised (a step lighter than
  the window) inside the `card` edge. Faces with a lift (Panel, Button, Matte)
  draw their base times the color plus the white lift, as bars do, never the
  baked file (its light vanishes on Graphite). When the edge sits inside a
  box, the face stops where the edge starts (the rim covers its own inner
  corner), so no square corner shows past the round one.
  **Scroll bars:** a 4px Graphite track and thumb (rimStrong).
- **Item quality:** the `line` edge in the quality color, inside the slot.
- **Text on Graphite:** dark parchment text (quest, gossip, books) takes the
  Graphite text color. A window whose content draws under its border frame
  (the World Map), or a see-through one (Background Opacity under 100), has
  no soft drop, which would shade it.
- **Chat:** each window a Mode window on its message box (the `window` edge
  inside it, Graphite panel at the chat's Background Opacity); the edit box
  on a Graphite base band with a 1px Graphite line that turns Ivory while
  typing (or, Below, a Mode field). Tabs are `control` panes resting on the
  edge (Mode Glass at 75% or the Mode Button face): the open one full height
  in the chosen tone with an Ivory label and line, the others tucked down in
  Graphite raised. The button compartment is one `control` box with 1px
  Graphite dividers.
- **Damage Meters:** each window a Mode window (Graphite panel at its
  Background Opacity, the `window` edge inside it), a Mode Title header in
  Graphite raised over a 1px Graphite line, the title in Graphite text and
  the timer in Graphite muted; rows are Mode Panel bars in class colors on
  Mode BG (Slate), names and values pure white and outlined; the fight letter
  is Ivory. The header menu is a Mode window.
- **Tooltips:** each a Mode window (Graphite panel at the tooltip's
  Background Opacity, the `window` edge inside it), the edge's rim in the
  item's quality color (or a player's class color, when chosen); the first
  line in SemiBold; reactions in the gameplay tones and quest lines in the
  quest tone (#FFB12F).
- **Bags:** a Mode window with a Mode Title header and a Mode field for
  search; slots are Mode slots (Slot Size wide, `Style.IconHeight` tall), a
  Mono panel face with the icon cropped to it, in the `group` edge 1px apart,
  the rim in the quality color (Ivory for new items, the quest tone for quest
  items), a small quest mark (the Quest glyph in the quest tone on a dark
  disc) on quest items, cooldown numbers in Bold at the count size. The
  header's Clean Up is the broom glyph. The footer holds the Bag Bar (small
  Mode slots for the equipped bags with their free slots), the free count in
  Bold over a thin capacity bar (Celadon, Ivory near full, Rosewood full)
  and the money. The Sort menu is a Mode window.
- **Minimap:** the map in the `frame` edge (Mode-Blizz by default; rim 2px,
  or 1px with Map Border Thin; Border Color other than Metal tints it flat),
  its mask square (the rim covers the
  corners); Blizzard's buttons and the addon buttons on Mode tiles (a Mode
  Button face in Mono raised, in the `group` edge); clock Bold above the zone
  SemiBold; zone colors are the gameplay reaction tones.

## Settings window

A hybrid window built one-to-one from the study:

- **Main panel:** 1000px wide; header (MODE wordmark, search, profile, close);
  184px sidebar of categories (Interface, Panels, System) with module icons
  ("Mode Icon&lt;Name&gt;" art) and Celadon/Rosewood status dots; the General
  page's global cards four across (186px); footer with Edit Mode, Reset
  (Rosewood, shown for a module that can reset to defaults) and Done (Ivory) on
  the right, and Reload and Preview on the left.
- **General** holds only global settings that already work. Each redesign
  phase adds the cards its modules obey (Accent, Text, Textures, Borders,
  Shields, Names, Scale, Combat), never a control that does nothing yet.
  Modules add their own cards (`module:BuildHomeCard`). **UI Scale** is there
  now (Optimizations): the screen ModeUI detected ("1440p") and one button,
  "Use 53.33%", that sets the Pixel Perfect scale ("Using 53.33%" once it's
  in use). Pixel Perfect is a whole number of screen pixels per UI unit: one up
  to 2159 pixels tall (1080p 71.11%, 1440p 53.33%), two from 2160 (4K
  71.11%), so every 1px edge lands on a pixel.
- **Visual modules** (`layout = "split"`): the sidebar folds into a 48px icon
  rail, settings sit in a 432px column of cards two across, and a live preview
  fills the rest. The header shows "‹ All modules" and a breadcrumb.
  Split is for tall previews (Party Frames).
- **Small previews** (`layout = "strip"`, Unit Frames, Nameplates, Action Bars): the icon
  rail, the preview in a strip across the top, cards across the full width below.
- **Simple modules** (`layout = "page"`): sidebar plus cards four across.
- **Back:** the rail's home icon, "‹ All modules", the wordmark, or Esc (module
  → main panel → close). Esc works through `UISpecialFrames`, so it also works
  in combat without capturing the keyboard.
- **Cards:** a Mode Matte face (its base, without the bar sheen) in Graphite raised inside the `card` border, an
  11px uppercase Ivory title, labels above controls, cards 10px apart. Pages
  not yet rebuilt show their existing cards as tiles two across (one column in
  the split view, which widens to fit them); a rebuilt page sets `cardColumns`
  (4 on a sidebar or strip page, 2 in the 432px split column).
- **Tile packing:** tiles pack in bands, in page order. Each tile goes to the
  shortest column while that column is at least 48px short of the tallest, so
  a long tile on one side takes several short ones on the other. When the
  columns are nearly level the band closes, and the last tile in each column
  stretches so every column ends on the same line. Order a page's tiles so
  related short tiles follow the long one they sit beside.
- **Untitled cards** (a page's status line and quick actions) have no tile:
  they run as a plain strip across the page above the tiles.
- **Segmented choices** (`W.Exclusive`) sit side by side only while every
  label fits on one line. When they don't, the same choices turn into a
  compact dropdown in the same place (same width, one line). Segments never
  stack vertically, wrap, or push the controls below them. New pages get this
  automatically; for more than four options or long labels, use a dropdown
  (`W.Select`) from the start.
- **Text in tiles:** notes wrap to the full width of their tile; row labels are
  sized by their row.
- **Nothing past its tile.** Dropdowns fill their row or column cell. Column
  cells wrap onto another line when a line can't give each one 120px. A
  fixed-width control or label shrinks to its room. Things to pick several of
  (windows, bars to copy to) are buttons that stay lit while chosen
  (`page:ChoiceGrid`), not on/off toggles. A result line ("Applied to 2
  windows.") sits under the buttons that produce it. `tests/settings_fit.lua`
  opens every page and tab at the window's real widths and fails on any control
  or text past its tile; every new or rebuilt page must pass it.
- **Notes are tips only.** No descriptions of what a setting does, how ModeUI
  works inside, or a module's status. A note is shown only when the player
  needs it to use something: a hidden interaction ("click a spell in the
  preview", "/kb"), a syntax (macro conditions), a game option the feature
  depends on, a conflict with another addon, or why a tab is empty ("This bar
  is off"). In code, a module's notes go through `W.Note` (hidden) and the
  keepers through `W.Tip`; rows titled "Status" are hidden. When a module is
  rebuilt, its hidden notes are deleted rather than carried over.
- **Combat:** the window closes itself when combat starts.
- **Controls:** Slide toggle (Celadon ON with dark text; Rosewood Deep OFF with
  bold white text), rail slider (2px rail, Ivory fill, 4 × 14 blade), dropdowns,
  cards, color swatches, 1px nudges, anchor compass. Labels sit above controls
  with the value on the label line. No description text beyond titles.

## Texture library

Every texture ModeUI draws from its own art is "Mode &lt;Name&gt;", generated by
`tools/build_mode_assets.lua` as power-of-two 32-bit TGA under
`Media/Textures/Mode/`, and registered with LibSharedMedia under that name.
Menus group them under "Mode" with the short name.

| Menu name | Job |
|---|---|
| BG | every empty bar; alternate fill |
| Cast | cast bars |
| Panel | window backgrounds, meter bars |
| Title | title bars |
| Button | button and icon faces, class resource |
| Shield | absorbs and overshields |
| Solid, Matte, Gradient, Glass | general fills |
| Spark | Comet head and trail; shield finish line |
| Text Glow | the health text halo |
| Light, Empty | border art |

Module icons (`Style.ICONS`, the settings sidebar and icon rail) and control
glyphs (`Style.GLYPHS`: Clean Up's broom, the quest mark) are white line art
from `tools/mode_icons.lua`, 32x32 under `Icons/`, tinted in game; keys
`Icon<Name>`. Older glyphs and masks (chat compartment, damage meter header,
close and window buttons, nameplate glows, minimap masks) come from
`tools/build_shape_textures.lua` and `tools/build_minimap_masks.lua` under
`Media.Textures`. Other addons' media is used only by reference
(`Style.PROVIDER_FONTS`, `Style.PROVIDER_MEDIA`) when installed; ModeUI ships
none of it. The pre-Mode art (box corners, caps, rings, the round box, the
glass tab, the old slot and control art) was removed in Phase 8.

## Companion addons

Companion addons (the first is `ModeCDM`, the Cooldown Manager) need ModeUI,
draw with its design system (their modules run inside ModeUI's addon table),
keep their settings in `ModeUIDB`, and follow this file exactly like a module
does.
