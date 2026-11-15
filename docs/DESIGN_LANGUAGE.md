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
| `darkFill` | `#1C1C1C` (Graphite `#1D1D1F`) | dark-mode health fill |
| `slate` | `#474747` | every empty bar, behind every fill |
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
| `ring` | circle | 2px Steel | Sheen | — | — | portraits, badges |
| `line` | Round 4 | 1px flat color | — | 1px shadow | — | aura dispel rims, item quality |
| `empty` | Round 4 | 1px or 2px, any color | Edge-lit, tinted | 1px shadow | — | an element's only border in a custom color: proc ready, aggro, target in group frames |

Highlight: the outer shadow ring takes the accent (1px), so the metal rim keeps
its look. Target uses Ivory; focus uses Rosewood. Group frames swap their rim to
`empty` instead, so their size never changes.

## Bars (`Style.Bar`)

- **Empty part:** Mode BG on Slate, for every bar (unit, group, nameplates,
  cast, tracked, power, status). Never tinted, class-colored bars included.
- **Fill textures:** dark-mode health Mode Matte (Mode BG alternate); class
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
  alpha. A bright 1px finish line marks the end.
- **Power bars:** 3px on every unit and group frame.

## Text (`Style.Font`, `Style.SetName`)

- **Geist everywhere** (Regular, Medium, SemiBold, Bold; static TTF, OFL),
  numbers included. Inter only for special cases. CJK clients fall back to
  Blizzard's font.
- Shadow 1px offset (1, −1) at 95% black; OUTLINE only as a player choice.
- **Names:** subtle Gradient is standard (class or reaction color fading to 74%
  class + 26% white across the name, one color per letter; names Forever
  returns as secret fall back to Soft class). Options: Soft class (55% class +
  45% white), White.
- **Placement:** the name sits on the top border, 9px in from the side
  opposite the portrait, lifted so the rim runs near its baseline. Health is
  right-aligned inside the health bar (padded past a portrait on that side).

## Sizes

| Element | Size |
|---|---|
| Player, target | 184 wide; 34 health + 1 + 3 power; portrait 66, overlapping, Steel Sheen ring, no gap |
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
  Split is for tall previews (Party Frames, Action Bars).
- **Small previews** (`layout = "strip"`, Unit Frames and Nameplates): the icon
  rail, the preview in a strip across the top, cards across the full width below.
- **Simple modules** (`layout = "page"`): sidebar plus cards four across.
- **Back:** the rail's home icon, "‹ All modules", the wordmark, or Esc (module
  → main panel → close). Esc works through `UISpecialFrames`, so it also works
  in combat without capturing the keyboard.
- **Cards:** a Mode Matte face in Graphite raised inside the `card` border, an
  11px uppercase Ivory title, labels above controls, cards 10px apart. Pages
  not yet rebuilt show their existing cards as tiles two across (one column in
  the split view, which widens to fit them); a rebuilt page sets `cardColumns`
  (4 on a sidebar or strip page, 2 in the 432px split column).
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
| Light, Empty | border art |

## Companion addons

Companion addons (the first is `ModeUI_CooldownManager`) need ModeUI, use its
design system through the `ModeUI-Core` LibStub API, keep their settings in
`ModeUIDB`, and follow this file exactly like a module does.
