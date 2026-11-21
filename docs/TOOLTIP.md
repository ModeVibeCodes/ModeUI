# Interface: Tooltip

November 13, 2026; rebuilt in the Mode design language November 15, 2026
(Phase 7, settings version 5). Seventh module of the **Interface** category.
Off by default (turn it on with the switch in the page header). Mock tested,
and **confirmed in game by the owner, November 15, 2026**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#tooltip--november-13-2026).

## What it does

ModeUI restyles Blizzard's own tooltips and places the main one. It never
makes its own tooltip or measures one (a tooltip's sizes and text can be
secret); it only reads a line's text when the game lets addons see it, to
find the class and level lines.

| Part | Look |
|---|---|
| Tooltips | `GameTooltip`, `ItemRefTooltip` (clicked item links), `ShoppingTooltip1/2` and `ItemRefShoppingTooltip1/2` (comparisons), `GameNoHeaderTooltip`, `GameSmallHeaderTooltip`, `FriendsTooltip`. |
| Frame | Blizzard's NineSlice (border and background) is faded: `SharedTooltip_SetBackdropStyle` re-applies its atlases and colors, never its alpha, so it stays gone. Azerite and corrupted overlays are faded. Each tooltip is a Mode window (docs/DESIGN_LANGUAGE.md, "Windows and panels"): Surface (Solid and its soft sheen) in Background Color at Background Opacity (92%), the `window` edge inside it on its own frame above the lines. A see-through tooltip has no soft drop. **Border** off hides the edge; on, **Border Style** and **Border Metal** choose its look (Mode-Thin in Steel by default). |
| Fill color | Graphite panel (#121213), as every Mode window. |
| Rim color | **Quality Border** (on): the edge's rim in an item's quality color. **Class Border** (off by default): a player's class color. Otherwise the edge's lit metal. A unit the game keeps secret keeps the metal. |
| Screen | The tooltip is kept on the screen, border and all, wherever its anchor sits. |
| Size | **Minimum Width** (0–400 px), **Padding** (extra room around the text, 0–20 px), **Scale**. Blizzard resets width and padding as it restyles a tooltip, so ModeUI sets them each time it fills. |
| Text | Every line in the Mode typeface (Urbanist): the first at Header Size (14) in SemiBold, the rest at Text Size (12). |
| Health bar | Blizzard's bar under unit tooltips is hidden. |

## Text colors

Set each time a tooltip fills (unit tooltips fill again every few frames):

| Text | Default | Choices |
|---|---|---|
| Player names | Class color | Class, Custom, Blizzard |
| NPC names | Reaction: Hostile, Neutral, Friendly (each a color setting, the gameplay reaction tones by default); gray once someone else has tagged it | Reaction, Custom, Blizzard |
| Class line ("Rogue") | Class color | Class, Custom, Blizzard |
| Level | Difficulty: only the number ("Level **33** Orc"), red well above you, then orange, yellow, green and gray well below (Blizzard's difficulty colors) | Difficulty, Custom (the whole line), Blizzard |
| Quest lines | Quest titles and objectives in the quest tone (#FFB12F) | Quest Text on/off, Quest Color |

Quest lines are found by the line types in the tooltip's data
(`QuestTitle`, `QuestObjective`, `QuestPlayer`); the class line is the line
reading the unit's class, and the level line the one starting "Level".

## Placement

Blizzard places the main tooltip with `GameTooltip_SetDefaultAnchor`; ModeUI
post-hooks it:

- **Anchor** (default): the tooltip grows out of **Anchor Point** (bottom
  right) of ModeUI's **Tooltip** anchor. In ModeUI's Edit Mode it shows as a
  Mode box outlined in Ivory: drag it, or attach it to another element (action bars, meter
  windows, unit frames, the minimap, or a frame you pick). It starts where
  Blizzard's does, the screen's bottom right.
- **Cursor**: the tooltip follows the cursor.

Blizzard's own tooltip spot (its Edit Mode HUD Tooltip) no longer applies
while the module is on; ModeUI never moves Blizzard's container. Tooltips
that owners place themselves (action buttons with the classic tooltip style,
bag items, settings) stay where they put them.

In the role layouts (Mode-DPS/TANK, Mode-Healer; `Layouts.lua`, owner,
November 20, 2026) the anchor's bottom-right sits on Damage Done's
bottom-left, 4 left of it, with Anchor Point Bottom Right, so the tooltip
stands just left of the damage meters, its bottom on the bottom meter's, and
grows up and left.

## Combat

**Hide in Combat** hides the main tooltip as it shows while you're in combat,
and when combat starts. With **Shift Shows It**, holding Shift shows it
anyway. Item links you click (`ItemRefTooltip`) still open.

## Settings

Tabs pinned above the cards: **Look** (Status, Frame, Border, Size,
Defaults), **Text** (Font, Names, Class and Level, Quests) and **Position**
(Show At, Anchor Point, Move It, Combat). Turning the module off places the
tooltip Blizzard's way again at once and asks for a reload to bring back
Blizzard's look.

Saved under `modules.tooltip` (version 5): `backgroundColor`,
`backgroundOpacity`, `border`, `qualityBorder`, `classBorder`, `minWidth`, `padding`, `scale`,
`font`, `fontMedia`, `headerSize`, `textSize`, `outline`, `shadow`,
`playerNameColor`, `playerNameCustom`, `npcNameColor`, `npcNameCustom`,
`hostileColor`, `neutralColor`, `friendlyColor`, `classTextColor`,
`classTextCustom`, `levelColor`, `levelCustom`, `questText`, `questColor`,
`position` (`anchor` or `cursor`), `anchorPoint`, `hideInCombat`,
`shiftShows`. The anchor's position is saved with the other Edit Mode
positions (`modeTooltip`). Version 2 (November 13, 2026, per the owner): a
fill still at version 1's #0B0B0D takes the health color, and the health bar
settings (`healthBar`, `healthHeight`, `healthColor`) are removed. Version 3
(same day): a 1px border and Class Border off by default; a border still at
version 2's 2px, and Class Border still on, follow. Version 4 (same day): a
fill still at the old health color #1C1E21 takes #131212. Version 5
(November 15, 2026, Phase 7): the Mode design language. The border is the
Mode window edge, so `rounded`, `gradient`, `borderColor` and `borderSize`
are removed; a fill still at #131212 takes Graphite panel, reaction colors
still at version 4's (#E06666, #FFD140, #7FDB97) take the gameplay reaction
tones, and a Font still at "Expressway" takes "Mode". Values the user picked
stay.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the tooltips, defaults, ranges, migration, validation |
| `Skin.lua` | the Mode window, size, fonts, health bar hidden |
| `Colors.lua` | rim color by content; name, class, level and quest colors |
| `Driver.lua` | lifecycle, hooks, placement and the Edit Mode anchor, combat, settings |
| `Settings.lua` | the page |

Tests: `tests/tooltip.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Tooltip** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Hover
  another player, a hostile NPC, a friendly NPC, an item in your bags and a
  quest mob. Open the **Position** tab, click **Edit Mode**, drag the
  **Tooltip** box into the screen's bottom-right corner (and try attaching
  it to an action bar), leave Edit Mode, then hover an NPC again. Turn on
  **Hide in Combat**, attack a training dummy and hover it, then hold Shift.
- **Required state:** out of combat to start; a training dummy or any enemy
  for the combat part.
- **Confirmation:** tooltips are see-through Graphite windows with the thin
  Mode edge just inside (an item's rim in its quality color; a player's
  steel, unless Class Border is on) and no drop shadow; the first line is
  bolder than the rest; a player's name and class line are in their class
  color, a hostile NPC's name red and a friendly one's green; only the
  level number is colored; quest objectives are orange-yellow; there is no
  health bar. In the corner the whole tooltip, edge included, stays on the
  screen. In combat the tooltip stays hidden until you hold Shift. No Lua
  errors.
