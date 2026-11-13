# Interface: Tooltip

November 13, 2026. Seventh module of the **Interface** category. Off by
default (turn it on with the switch in the page header). Static/mock
validated only; **native acceptance is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#tooltip--november-13-2026).

## What it does

ModeUI restyles Blizzard's own tooltips and places the main one. It never
makes its own tooltip or measures one (a tooltip's sizes and text can be
secret); it only reads a line's text when the game lets addons see it, to
find the class and level lines.

| Part | Look |
|---|---|
| Tooltips | `GameTooltip`, `ItemRefTooltip` (clicked item links), `ShoppingTooltip1/2` and `ItemRefShoppingTooltip1/2` (comparisons), `GameNoHeaderTooltip`, `GameSmallHeaderTooltip`, `FriendsTooltip`. |
| Frame | Blizzard's NineSlice (border and background) is faded: `SharedTooltip_SetBackdropStyle` re-applies its atlases and colors, never its alpha, so it stays gone. Azerite and corrupted overlays are faded. **Rounded** (default): a rounded box (ModeRound, radius 5) in Background Color at Background Opacity (92%), with a hollow rounded rim Border Size thick (ModeRing1-4) above it, so the see-through fill never takes the rim's color. Rounded off: a flat fill and a crisp square border. **Mode Gradient**: a soft white wash over the top, as on every Mode bar. |
| Fill color | The Unit Frames' default health color (Onyx #1C1E21), as the chat and the meters. |
| Border color | **Quality Border**: an item's quality color. **Class Border**: a player's class color. Otherwise Border Color (2 px, the unit frames' rim color #40454C). A unit the game keeps secret keeps Border Color. |
| Screen | The tooltip is kept on the screen, border and all, wherever its anchor sits. |
| Size | **Minimum Width** (0–400 px), **Padding** (extra room around the text, 0–20 px), **Scale**. Blizzard resets width and padding as it restyles a tooltip, so ModeUI sets them each time it fills. |
| Text | Every line in the Mode face (Expressway): the first at Header Size (14), the rest at Text Size (12). |
| Health bar | Blizzard's bar under unit tooltips is hidden. |

## Text colors

Set each time a tooltip fills (unit tooltips fill again every few frames):

| Text | Default | Choices |
|---|---|---|
| Player names | Class color | Class, Custom, Blizzard |
| NPC names | Reaction: Hostile, Neutral, Friendly (each a color setting); gray once someone else has tagged it | Reaction, Custom, Blizzard |
| Class line ("Rogue") | Class color | Class, Custom, Blizzard |
| Level | Difficulty: only the number ("Level **33** Orc"), red well above you, then orange, yellow, green and gray well below (Blizzard's difficulty colors) | Difficulty, Custom (the whole line), Blizzard |
| Quest lines | Quest titles and objectives in a vivid yellow-orange (#FFB12F) | Quest Text on/off, Quest Color |

Quest lines are found by the line types in the tooltip's data
(`QuestTitle`, `QuestObjective`, `QuestPlayer`); the class line is the line
reading the unit's class, and the level line the one starting "Level".

## Placement

Blizzard places the main tooltip with `GameTooltip_SetDefaultAnchor`; ModeUI
post-hooks it:

- **Anchor** (default): the tooltip grows out of **Anchor Point** (bottom
  right) of ModeUI's **Tooltip** anchor. In ModeUI's Edit Mode it shows as a
  cyan box: drag it, or attach it to another element (action bars, meter
  windows, unit frames, the minimap, or a frame you pick). It starts where
  Blizzard's does, the screen's bottom right.
- **Cursor**: the tooltip follows the cursor.

Blizzard's own tooltip spot (its Edit Mode HUD Tooltip) no longer applies
while the module is on; ModeUI never moves Blizzard's container. Tooltips
that owners place themselves (action buttons with the classic tooltip style,
bag items, settings) stay where they put them.

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

Saved under `modules.tooltip` (version 2): `backgroundColor`,
`backgroundOpacity`, `gradient`, `rounded`, `border`, `borderColor`,
`borderSize`, `qualityBorder`, `classBorder`, `minWidth`, `padding`, `scale`,
`font`, `fontMedia`, `headerSize`, `textSize`, `outline`, `shadow`,
`playerNameColor`, `playerNameCustom`, `npcNameColor`, `npcNameCustom`,
`hostileColor`, `neutralColor`, `friendlyColor`, `classTextColor`,
`classTextCustom`, `levelColor`, `levelCustom`, `questText`, `questColor`,
`position` (`anchor` or `cursor`), `anchorPoint`, `hideInCombat`,
`shiftShows`. The anchor's position is saved with the other Edit Mode
positions (`modeTooltip`). Version 2 (November 13, 2026, per the owner): a
fill still at version 1's #0B0B0D takes the health color, and the health bar
settings (`healthBar`, `healthHeight`, `healthColor`) are removed.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the tooltips, defaults, ranges, migration, validation |
| `Skin.lua` | frame (rounded or square), gradient, size, fonts, health bar hidden |
| `Colors.lua` | border color by content; name, class, level and quest colors |
| `Driver.lua` | lifecycle, hooks, placement and the Edit Mode anchor, combat, settings |
| `Settings.lua` | the page |

Tests: `tests/tooltip.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Tooltip** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Hover
  another player, a hostile NPC, a friendly NPC, an item in your bags and a
  quest mob. Open the **Position** tab, click **Edit Mode**, drag the cyan
  **Tooltip** box into the screen's bottom-right corner (and try attaching
  it to an action bar), leave Edit Mode, then hover an NPC again. Turn on
  **Hide in Combat**, attack a training dummy and hover it, then hold Shift.
- **Required state:** out of combat to start; a training dummy or any enemy
  for the combat part.
- **Confirmation:** tooltips are dark Onyx with rounded corners and a 2px
  rounded border (an item's in its quality color, a player's in their class
  color) and a soft top sheen; a player's name and class line are in their
  class color, a hostile NPC's name red and a friendly one's green; only the
  level number is colored; quest objectives are orange-yellow; there is no
  health bar. In the corner the whole tooltip, border included, stays on the
  screen. In combat the tooltip stays hidden until you hold Shift. No Lua
  errors.
