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
  under a border is never masked.

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
| `gunmetal` | light `#5B5E63`, mid `#46494D`, dark `#33363A` | frame and group rims |
| `steel` | light `#8C8F95`, mid `#74777D`, dark `#5B5E63` | window rims, portrait rings, settings controls |

Gameplay colors keep their meaning everywhere and are never softened:

| Group | Values |
|---|---|
| Reaction | hostile `#E5484D`, neutral `#F2C744`, friendly `#46C46B`, tapped `#8C8C8C` |
| Cast | casting `#F2B13C`, channeling `#3FBF7F`, not interruptible `#7D838C`, interrupted `#E5484D` |
| Dispel (Blizzard) | Magic `#3399FF`, Curse `#9900FF`, Disease `#996600`, Poison `#009900` |
| Item quality | common `#9D9D9D`, uncommon `#1EFF00`, rare `#0070DD`, epic `#A335EE`, legendary `#FF8000` |
| Other | cooldown text `#FFB12F`; class colors come from `Domain.UnitColor` (Class Colors may override) |

Changing a token's value is a migration: saved colors that still equal the old
value move to the new one; anything the player chose stays.

## Borders (`Style.Edge`)

One factory, named presets. Outer radius 4 ("Round 4"); every inner layer's
radius steps in by its own thickness, so each ring is the same width all
round. The rim art fills its own inner corner, so the content under it needs no
mask. Art: **Mode Light** (lit metal rims) and **Mode Empty** (flat tintable
rims).

| Preset | Shape | Rim | Lighting | Outer | Inner gap | Use |
|---|---|---|---|---|---|---|
| `frame` | Round 4 | 2px Gunmetal | Edge-lit (top 1px catches light) | 1px shadow + soft drop | — | player, target, cast bars, action buttons |
| `frameThin` | Round 4 | 1px Gunmetal | Edge-lit (half strength on 1px, so the top keeps the sides' weight) | 1px shadow | — | minor and boss frames, nameplates, icons, auras |
| `group` | Round 4 or Round 2 | 1px Gunmetal | Solid | — | — | party and raid frames (1px apart), bag slots |
| `window` | Round 4 | 1px Steel | Sheen (light band through the middle) | 1px shadow + soft drop | 1px black | every window and panel, the settings window, popups |
| `card` | Round 4 | 1px Steel | Sheen | — | 1px black | settings cards (a window border without the shadow) |
| `control` | Round 4 | 1px Steel | Sheen | 1px shadow | — | buttons, dropdowns, fields, the slide toggle |
| `ring` | circle | 3px Steel | Edge-lit (light on the top of the ring, fading by its middle) | 1px shadow | — | portraits, badges |
| `line` | Round 4 | 1px flat color | — | 1px shadow | — | aura dispel rims, item quality |
| `empty` | Round 4 | 1px or 2px, any color | Edge-lit, tinted | 1px shadow | — | an element's only border in a custom color: proc ready, aggro, target in group frames |

Highlight: the outer shadow ring takes the accent (1px), so the metal rim keeps
its look. Target uses Ivory; focus uses Rosewood. Group frames swap their rim to
`empty` instead, so their size never changes.

## Action buttons

- **Shape:** 40 x 34 by default (icons are wider than tall), the icon filling
  the button, cropped, over a Mode Button face in Mono panel (Background
  Color and Opacity; it shows in empty slots).
- **Border:** the `frame` edge outside the button (2px Gunmetal, edge-lit,
  1px shadow and the soft drop); buttons sit 4px apart outside their shadows
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

- **Geist everywhere** (Regular, Medium, SemiBold, Bold; static TTF, OFL),
  numbers included. Inter only for special cases. CJK clients fall back to
  Blizzard's font.
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
| Icons (buttons, auras, cooldowns, slots) | wider than tall: 4px shorter up to 35px wide, 6px from 36px (40 x 34) |
| Auras inside group frames | flush in the corner by default (the frame's rim is their outer border) |

## Windows and panels

Graphite panel `#121213` with the Mode Panel texture, title bar `#1A1A1C` with
Mode Title (Solid as an option), `window` border. Dispel indicators: Gradient
from the top edge (56% → 0 over 72%) by default, Rim and Inner glow as options.

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

## Companion addons

Companion addons (the first is `ModeUI_CooldownManager`) need ModeUI, use its
design system through the `ModeUI-Core` LibStub API, keep their settings in
`ModeUIDB`, and follow this file exactly like a module does.
