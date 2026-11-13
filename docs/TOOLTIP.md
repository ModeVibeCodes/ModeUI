# Interface: Tooltip

November 13, 2026. Seventh module of the **Interface** category. Off by
default (turn it on with the switch in the page header). Static/mock
validated only; **native acceptance is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#tooltip--november-13-2026).

## What it does

ModeUI restyles Blizzard's own tooltips and places the main one. It never
makes its own tooltip, reads tooltip text, or measures a tooltip (its sizes
and text can be secret).

| Part | Look |
|---|---|
| Tooltips | `GameTooltip`, `ItemRefTooltip` (clicked item links), `ShoppingTooltip1/2` and `ItemRefShoppingTooltip1/2` (comparisons), `GameNoHeaderTooltip`, `GameSmallHeaderTooltip`, `FriendsTooltip`. |
| Frame | Blizzard's NineSlice (border and background) is faded: `SharedTooltip_SetBackdropStyle` re-applies its atlases and colors, never its alpha, so it stays gone. Azerite and corrupted overlays are faded. A fill (#0B0B0D at Background Opacity, 92%) and a crisp square border, Border Size thick (2 px, the unit frames' rim color #40454C), on its own frame above the lines. |
| Border color | **Quality Border**: an item's quality color. **Class Border**: a player's class color. Otherwise Border Color. A unit the game keeps secret keeps Border Color. |
| Text | Every line in the Mode face (Expressway): the first at Header Size (14), the rest at Text Size (12). Set before a data tooltip shows (TooltipDataProcessor post-call), so Blizzard sizes it in the Mode face, and again as any tooltip shows. |
| Health bar | Blizzard's bar under unit tooltips (its value is secret and stays Blizzard's): flat, Health Color, a soft sheen, a dark track, Health Height (6 px) tall, hanging under the tooltip on its bottom border. Health Bar off hides it. |

## Placement

Blizzard places the main tooltip with `GameTooltip_SetDefaultAnchor`; ModeUI
post-hooks it:

- **Anchor** (default): the tooltip grows out of **Anchor Point** (bottom
  right) of ModeUI's **Tooltip** anchor, which you move in ModeUI's Edit Mode
  (it shows there as a cyan box). It starts where Blizzard's does, the
  screen's bottom right.
- **Cursor**: the tooltip follows the cursor.

Blizzard's own tooltip spot (its Edit Mode HUD Tooltip) no longer applies
while the module is on; ModeUI never moves Blizzard's container. Tooltips
that owners place themselves (action buttons with the classic tooltip style,
bag items, settings) stay where they put them. **Scale** sizes the main
tooltip.

## Combat

**Hide in Combat** hides the main tooltip as it shows while you're in combat,
and when combat starts. With **Shift Shows It**, holding Shift shows it
anyway. Item links you click (`ItemRefTooltip`) still open.

## Settings

Tabs pinned above the cards: **Look** (Status, Frame, Text, Health Bar,
Defaults) and **Position** (Show At, Anchor Point, Move It, Scale, Combat).
Turning the module off places the tooltip Blizzard's way again at once and
asks for a reload to bring back Blizzard's look.

Saved under `modules.tooltip` (version 1): `backgroundColor`,
`backgroundOpacity`, `border`, `borderColor`, `borderSize`, `qualityBorder`,
`classBorder`, `font`, `fontMedia`, `headerSize`, `textSize`, `outline`,
`shadow`, `healthBar`, `healthHeight`, `healthColor`, `position` (`anchor` or
`cursor`), `anchorPoint`, `scale`, `hideInCombat`, `shiftShows`. The anchor's
position is saved with the other Edit Mode positions (`modeTooltip`).

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the tooltips, defaults, ranges, validation |
| `Skin.lua` | frame, border colors, fonts, health bar |
| `Driver.lua` | lifecycle, hooks, placement and the Edit Mode anchor, combat, settings |
| `Settings.lua` | the page |

Tests: `tests/tooltip.lua`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Tooltip** in the sidebar.
- **Action:** turn the module on with the switch in the page header. Hover
  another player, an NPC and an item in your bags. Open the **Position** tab,
  click **Edit Mode**, drag the cyan **Tooltip** box somewhere else and leave
  Edit Mode, then hover an NPC again. Turn on **Hide in Combat**, attack a
  training dummy and hover it, then hold Shift.
- **Required state:** out of combat to start; a training dummy or any enemy
  for the combat part.
- **Confirmation:** tooltips are dark with a crisp 2px border (an item's in
  its quality color, a player's in their class color), Expressway text, and a
  slim green health bar under units. World tooltips appear at the box you
  placed. In combat the tooltip stays hidden until you hold Shift. No Lua
  errors.
