# Interface: Windows

November 13, 2026. Sixth module of the **Interface** category (the roadmap's
"Blizzard UI Windows"). Off by default (turn it on with the switch in the page
header). Static/mock validated only; **native acceptance is pending**. APIs and
their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-chat-and-windows--november-13-2026).
Design canvas: https://claude.ai/artifact/E9m1Krqr6LXYaJJvjAUAPL (Windows artboard).

## What it does

ModeUI restyles Blizzard's windows in place. It never moves, shows or hides a
window (a window's own Scale aside), so Blizzard keeps opening, closing and
placing them. Blizzard's art is faded (alpha only); ModeUI's textures go on
top. **Window Style** swaps every window between ModeUI (the default) and
Blizzard's own look; each window can also be kept Blizzard's on its own.

| Part | Look |
|---|---|
| Frame | NineSlice pieces (one by one, so the Settings panel's title survives), parchment (`Bg`), `TopTileStreaks`, portrait (`PortraitContainer`, and the Guild window's `PortraitOverlay`), glow and the older corner and edge textures are faded. The Mode window (since November 15, 2026; docs/DESIGN_LANGUAGE.md, "Windows and panels"): the Graphite panel (Background Color, `#121213`) in Mode Panel at Background Opacity (100%) to the window's edges, and the `window` edge outside them (Mode-Thin by default: a 2px Steel bevel, a 1px black line just inside, shadow and drop) on its own frame 520 levels up, above everything the window stacks (NineSlice at 500, buttons at 510). **Border** switches the edge; **Border Style** and **Border Metal** (Look tab, Frame group) choose its look for every window. Controls, cards and the Character window's slot lines keep their own. |
| Title | A 22 px Mode Title strip in Graphite raised over a 1px Graphite line, at the window's top. Portrait-window titles are centered on the strip, clear of the window buttons; the title is Geist SemiBold 13 in Graphite white. Header and dialog titles (Game Menu, Settings) keep their place. |
| Window buttons | Close: an 18 px `control` box (Mode Button face) with a thin cross, 2 px inside the window's top-right corner. Maximize/minimize (`MaximizeMinimizeButtonFrameTemplate`, the Guild window's): the same box with a corner arrow, just left of Close. Glyphs in Graphite secondary; hover lights the glyph and the outer line Ivory. |
| Window text | With **Window Text** on, every font string in the window (and in list rows Blizzard fills later) gets the Mode face at the game's own size and outline. Titles and tabs use Title Size and Tab Text Size. Dark text Blizzard draws for its parchment (quest, gossip, book and letter text in dark brown or black) takes the Graphite text color, also each time Blizzard sets a dark color again; colors with light in them and inline color codes stay. |
| Decoration | Found anywhere inside a window: gold filigree (`FilligreeOverlay`, `TopFiligree`, `BottomFiligree`), inset border pieces, tiled list backgrounds (`Bg`), column header backgrounds, a scroll bar's marble `Background`. |
| Insets | A card: a Mode Matte face in Graphite raised (a step lighter than the window), drawn on the inset's **parent** under the content, inside the `card` edge on the inset. (The Guild roster's inset is raised over its rows at level 100; a fill on it tinted every name.) |
| List rows | Rows in a ScrollBox get the Mode face when Blizzard fills them (`ScrollUtil.AddInitializedFrameCallback`); the Guild roster's row strips are faded so the window shows through. |
| Tabs | Text tabs in Geist SemiBold: the chosen tab Ivory with a 2 px Ivory bar on its window side, the others Graphite muted. Follows `PanelTemplates_SelectTab`/`DeselectTab` and TabSystem's `SetTabSelected`. Side tabs (Character, Collections, ...) and right side tabs (the Guild window's Chat, Roster, Benefits and Info) are `control` boxes, in the chosen tone with an Ivory line when checked; the right side tabs' icons are cropped inside them. |
| Dropdowns | `WowStyle1/2DropdownTemplate` (the Guild window's channel picker) and the legacy `UIDropDownMenuTemplate`: a Graphite field in the `control` edge with a chevron, Ivory while hovered or open. The menu a WowStyle dropdown opens gets a Mode window under its entries (its own background faded), lent from ModeUI and taken back when it closes, since Blizzard reuses menu frames for every menu. |
| Buttons | Mode Button faces (base and lift) in Graphite raised inside the `control` edge, Geist SemiBold text, for `UIPanelButtonTemplate` and `ThreeSliceButtonTemplate` (the Game Menu's); hover lights the outer line Ivory; disabled text is muted. |
| Fields | Edit boxes (`InputBoxTemplate`, search boxes): a Graphite base inside the `control` edge, Ivory with focus. |
| Scroll bars | `MinimalScrollBar` and `WowTrimScrollBar`: a 4 px Graphite track and thumb; the arrows stay clickable but invisible. (Chat's scroll bar shares it.) |

Controls are recognised by the keys their templates give them
(`Shared/Skin/Controls.lua`, `Skin.Kind`), six levels into each window, and
again each time the window shows, so lists Blizzard fills later are caught.

## Windows

Character, Spellbook and Talents, Professions, Social, Guild and Communities,
Group Finder, Collections, Achievements, World Map (border and strip only: the
map draws under its border frame), Quests and Gossip, Merchant, Mail, Bank,
Trade, Inspect, Trainer, Auction House, Dressing Room, Pet Stable, Raid,
Macros, AddOn List, Game Menu and Game Settings. On the **Windows** tab each
has a row: its switch (ModeUI look on or off) and a chevron that expands its
own settings, all collapsed at first:

- **Scale** (50–150%, every window but the World Map), applied whichever look
  it has; protected windows are scaled outside combat.
- **Own Look**: its own Background Opacity, Border and Title Bar instead of
  the Look tab's.

Windows from load-on-demand Blizzard addons are skinned when the addon loads
(`ADDON_LOADED`). Collections and Professions hold secure buttons; windows
like these are skinned (and their buttons placed) only outside combat,
through `Defer`; plain windows are skinned at once, in combat too.

## Character window

On the **Character** tab, working with either look:

- **Style**: ModeUI or Blizzard for the Character window (its switch on the
  Windows tab).
- **Stats pane** (with the ModeUI style): Blizzard's class art, stone,
  ornate category bars and gold dividers are faded; the pane is an Onyx field
  with a one-pixel divider, each category ("General", "Primary Attributes")
  an Onyx strip with a white title, and the alternating row stripe a faint
  gray. The rock strip behind the level line and the pane's page arrow are
  restyled too.
- **Stats Display**: a small block over the character model, one line per
  picked stat (Main Stat, Stamina, Armor, Crit, Hit and Haste by default;
  also Strength, Agility, Intellect, Spirit, Attack Power, Ranged Attack
  Power, Spell Power, Healing, Spell Crit, Ranged Crit, Spell Hit, Spell
  Haste, Expertise, Dodge, Parry, Block and Mana Regen per 5 seconds while
  casting). Main Stat is the specialization's primary stat, or the highest of
  Strength, Agility and Intellect. Labels are in each stat's color (**Stat
  Colors**, one row per shown stat): Strength red, Agility yellow, Intellect
  blue, Stamina amber, Spirit green, attack power orange, spell power violet,
  crit red, hit amber, haste light blue, avoidance pale blue; Main Stat takes
  its attribute's; values are white. The block lives in the model area
  between the slot columns, above the weapons (a frame anchored to the head,
  wrist and hands slots): **Stats Anchor** is one of nine points of that
  area, **Offset X/Y** and **Nudge** (one pixel at a time) are kept inside
  it, and the block is never wider than it, so it never reaches a slot.
  **Stats Text Size**, **Stats Background**.
  Every value comes from the functions Forever's own paper doll calls; a
  secret (stats restricted) or missing value shows a dash.
- **Rarity Borders**: a crisp square border round each equipment slot,
  Border Size thick, in the item's quality color from Uncommon up (lower and
  empty slots take the window's border color). Blizzard's quality ring is
  faded; with the ModeUI style, the gear slot frame too.
- **Enchant Text**: beside each slot, over the model: right of the left
  column, left of the right column, above the weapons. The enchant's name in
  cyan; a weapon without one shows its temporary enhancement (a poison, oil
  or stone) in green. Under it, the stat it gives: from the line itself
  ("+15 Agility" is shortened to "+15 Agi", "(+8 Damage)" to "+8 Dmg", and
  "and" reads "&": "+3 Str & Agi"), or for
  a few well-known proc enchants and poisons (Crusader, Fiery Weapon,
  Lifestealing, Icy Chill, Unholy Weapon, Demonslaying, Instant, Deadly,
  Crippling, Mind-numbing and Wound Poison) from a short English table.
  There is no enchant name API: the text is the item tooltip's enchant line
  (`C_TooltipInfo.GetInventoryItem`, the permanent enchant line type, or the
  timed line of a temporary one).

## Settings

Tabs pinned above the scrolling cards: **Look** (Status, Window Style, Frame,
Text, Controls, Defaults), **Windows** (a row per window) and **Character**
(Character Window, Stats Display, Rarity Borders, Enchant Text). Changes
repaint every skinned window right away. Turning a window, a control kind,
Window Text or the module off, or picking Blizzard, brings Blizzard's look
back on the next reload; ModeUI asks for one. Reset to Defaults resets the
Look tab only.

Saved under `modules.windows` (version 3): `style` (`modeui` or `blizzard`),
`windows` (window ID → on), `looks` (window ID → `custom`,
`backgroundOpacity`, `border`, `titleBar`, `scale`), `backgroundColor`,
`backgroundOpacity`, `border`, `titleBar`,
`font`, `fontMedia`, `titleSize`, `tabSize`, `outline`, `shadow`, `bodyFont`,
`tabs`, `buttons`, `fields`, `dropdowns`, `scrollBars`, `insets`,
`charStats`, `charStatsBackground`, `charStatsAnchor`, `charStatsX`,
`charStatsY`, `charStatsSize`, `charStatList` (stat ID → on), `charStatColors`
(stat ID → color), `charBorders`,
`charBorderSize`, `charEnchants`, `charEnchantSize`.

Version 3 (November 15, 2026): the Mode design language. Values still at a
version 2 default take the new one (the #0B0B0D fill: the Graphite panel;
94%: 100%, also in each window's own look; Expressway: Geist); Border Color
and Border Size retire (the `window` edge); anything chosen stays. Rarity
borders are the `line` edge inside the slot (Border Size 2 or more: a 2px
rim), Gunmetal on Common and empty slots; enchant names Ivory, temporary
enhancements Celadon.

Version 2 (November 13, 2026, per the owner): a border still at version 1's
default color (#25282C) moves to the unit frames' rim color; everything new
is filled in from the defaults.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the window registry, stats list, defaults, ranges |
| `Migrations.lua` | `Initialize(db)`: version 1 → 2, validation; fills in windows added later |
| `Driver.lua` | lifecycle, load-on-demand, skinning on show, style, looks, scale, settings |
| `CharacterStats.lua` | the stats display |
| `Character.lua` | rarity borders, enchant text, Character window events |
| `CharacterPanel.lua` | the stats pane, top strip and pane button in Onyx |
| `Settings.lua` | the page: Look and Windows tabs |
| `SettingsCharacter.lua` | the page's Character tab |

The skinning itself is shared: `Shared/Skin/Frame.lua` (windows),
`Shared/Skin/Controls.lua` (controls) and `Shared/Skin/Extras.lua`
(dropdowns and menus, right side tabs, window buttons, lists, text). Tests:
`tests/windows.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Windows** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Open the
  Guild window (Guild & Communities), click the channel dropdown at its top,
  hover the minimize button, and switch between its right-side tabs. Open the
  Character window. Back on the settings page, open the **Windows** tab and
  click the chevron on the Social row, then open the **Character** tab and
  click **Up** under Nudge.
- **Required state:** out of combat, in a guild, wearing some enchanted gear.
- **Confirmation:** the Guild window is a Graphite panel with the thin lit
  Steel window edge and its soft shadow, a slightly lighter title strip with
  a hairline under it, no round portrait, gold corners or blue filigree; the
  minimize and close buttons are small boxes whose glyph and outline turn
  Ivory on hover; tabs are plain text, the chosen one Ivory with a short
  Ivory bar; the dropdown is a dark field with a chevron and its menu opens
  on a Graphite window; roster names are in full color (offline members in
  Blizzard's gray), without a gray film over them; all text is Geist. The Character window shows the
  stats block on the model, colored borders round your gear and short enchant
  names beside enchanted slots. Every window row starts collapsed and the
  Social row opens to Scale and Own Look; the stats block moves up one pixel.
  The settings tabs sit above the cards. No Lua errors, and no "blocked"
  messages when using toys or casting from the spellbook afterwards.
