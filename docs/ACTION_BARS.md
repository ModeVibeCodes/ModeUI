# Interface: Action Bars

November 13, 2026. Third module of the **Interface** category. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-action-bars--november-13-2026).

## How it works

ModeUI doesn't make its own action buttons. It moves **Blizzard's own buttons**
onto ModeUI bars and restyles them. Blizzard's code keeps running every button,
so these all work as before:

- actions, keybinds and Quick Keybind mode
- paging: stances, forms, stealth, vehicles, override and possess bars
- cooldowns, charges, usability, range and spell alerts, including values the
  game keeps secret
- dragging spells on and off

ModeUI decides:

- where each bar sits
- how its buttons are laid out
- the button skin and the text on it
- when the bar shows

| ModeUI bar | Blizzard's buttons | Blizzard keybinds |
|---|---|---|
| Action Bar 1 | `ActionButton1-12` | Action Button 1-12 |
| Action Bar 2 | `MultiBarBottomLeftButton1-12` | Action Bar 2 |
| Action Bar 3 | `MultiBarBottomRightButton1-12` | Action Bar 3 |
| Action Bar 4 | `MultiBarRightButton1-12` | Action Bar 4 |
| Action Bar 5 | `MultiBarLeftButton1-12` | Action Bar 5 |
| Action Bar 6-8 | `MultiBar5Button` to `MultiBar7Button` 1-12 | Action Bar 6-8 |
| Pet Bar | `PetActionButton1-10` | Pet Action Button 1-10 |
| Stance Bar | `StanceButton1-10` | Special Action Button 1-10 |

Each ModeUI bar is a secure frame (`SecureHandlerStateTemplate`). A button
keeps Blizzard's bar as its `bar`, so the action page still comes from
Blizzard. The main bar, pet bar and stance bar have art and catch the mouse, so
they move under a hidden frame. The other Blizzard bars have no art and are left
alone. Blizzard's own **Number of Icons** setting still hides buttons past its
count, so leave it at 12 in the game's Edit Mode.

ModeUI never stores values on Blizzard's buttons. Its textures and state live in
weak tables keyed by the button. Its only hooks are `hooksecurefunc` on:

- the button: `UpdateButtonArt`, `UpdateHotkeys` or `SetHotkeys`
- the keybind text: `SetVertexColor`
- texts that need a lifted shadow: `SetText`, `Show`, `Hide`, `SetShown`

## The look

- **Buttons are 42 by 38** by default (Width and Height on the **Bar** tab).
  Sizes are whole physical pixels, and each bar is an even number of pixels each
  way, so a centered bar stays on the pixel grid.
- **Border:** Rounded (by default), Square or None. The rim is 1px in the
  Border Color (the near-black Onyx rim, #25282C, by default), then a 1px black
  gap. These are the nameplate and aura-icon rim textures.
- **Icon:** placed inside the rim. It's cropped, never stretched: 8% comes off
  the edges, then the long side is cut to the button's shape. Blizzard's rounded
  icon mask is removed.
- **States:** highlight, pushed, checked, attack flash, new-spell and
  spell-highlight are flat overlays on the icon. Blizzard's slot art, frame and
  equipped-item border are faded.
- **Empty slots:** with **Show Empty Slots** on, a dark slot inside the same rim
  marks each place without an action. Dragging a spell shows every button so it
  can be dropped.

## Text

Four texts, each with **Show This Text**, **Anchor** (a compass with Center),
**Size**, **Offset X**, **Offset Y** and **Color**:

| Text | Default |
|---|---|
| Keybind | shown, Top Right, 11 |
| Count (stacks and charges) | shown, Bottom Right, 12 |
| Macro Name | hidden, Bottom, 10 |
| Cooldown (the countdown numbers) | shown, Center, 14 |

Anchors sit 2 pixels inside the icon. Every bar shares one font setup: **Font**
(Expressway by default), **Outline** (on), **Slug Text** (on) and **Text
Shadow** (None, Crisp by default, or Lifted).

- Blizzard shows and hides these texts itself, so a hidden text is faded rather
  than hidden.
- The keybind keeps its color, except that Blizzard's out-of-range red still
  shows.
- A lifted shadow copies its text as Blizzard writes it. The copy accepts secret
  values.
- The game draws the cooldown numbers itself, so they get the crisp shadow only.
  They show when the game's own option for cooldown numbers is on.

## Layout and placement

- **Buttons**: how many show (1-12; the pet and stance bars hold 10).
- **Buttons per Line**, **Lines** (**Rows** or **Columns**) and **First Button**
  (the corner the first button sits in) set the bar's shape.
- **Spacing** sets the gap between buttons.
- Buttons past the count wait on the hidden frame.
- The stance bar shows no more buttons than you have stances, and hides when you
  have none.
- **Edit Mode** shows a stand-in for each shown bar: its empty slots, a faint
  cyan fill and its name. Drag it, or select it and use the Edit Mode window's X
  and Y. The real bar copies the stand-in's place outside combat, on whole
  pixels. **Open Module Settings** opens the page on the bar you selected.
- Default places are pinned to a screen edge so they hold at any resolution:
  - bars 1-3 stacked at the bottom center
  - bars 4 and 5 upright at the right edge
  - the pet and stance bars above bar 3
  - bars 6-8 hidden, near the middle of the screen

## Visibility

**Show** picks when a bar is on screen:

- **Always**
- **In Combat**
- **Out of Combat**
- **In Combat or With a Target**
- **Custom**: macro conditions such as `[combat][mod:shift] show; hide`. The
  game evaluates them, so they keep working in combat. Conditions the game can't
  read show the bar always.

Every bar hides during pet battles. The pet bar also needs a pet. The pet and
stance bars hide in vehicles and while possessing, as Blizzard's do. Action Bar
1 hides while the game shows its own vehicle bar (`OverrideActionBar`), which
then owns keys 1-12. **Show Bar** off hides a bar completely. Its keybinds still
work, as they do for Blizzard's hidden bars.

**Opacity** fades the whole bar. **Fade Until Mouseover** keeps the bar at
**Faded Opacity** until one of these happens:

- the mouse is over the bar or a spell flyout opened from it
- you drag a spell
- Edit Mode is on

Opacity changes may happen in combat. Showing, hiding, moving and sizing don't:
anything that needs them waits for the end of combat.

## Settings page

A preview of the bar being edited sits above four tabs:

- **Bar**: Show Bar, status, layout, size, copy and reset
- **Buttons**: border, empty slots
- **Text**: which text, then its place, size and color, and the font
- **Visibility**: when to show, opacity, fading

The preview has sample spells, keybinds, counts, a macro name and a cooldown.
**Animated** runs the cooldown. Clicking a button opens the **Bar** tab; clicking
a text opens the **Text** tab on that text. Every tab starts with **Editing**,
the bar being changed, shared by every tab. **Copy Style to All Bars** copies
size, borders, text and opacity. Each bar keeps its own buttons, lines and show
settings. **Reset to Defaults** resets one bar's look.

## Switching it off

Each button goes back to its Blizzard bar with its old place and size, and
Blizzard's bars come back. The Mode skin stays on the buttons until you reload,
so ModeUI offers a reload. Turning the module back on needs no reload.

## Settings versions

Version 1 (`ModeUIDB.modules.actionBars`, one table per bar: `bar1`-`bar8`,
`pet`, `stance`). Positions are saved under `positions.actionBarsBar1` to
`actionBarsBar8`, `actionBarsPet` and `actionBarsStance`.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the bars and their Blizzard buttons, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: defaults and validation |
| `Driver.lua` | lifecycle, events, settings changes, copy and reset, the font and color owner |
| `Bars.lua` | secure bars, moving Blizzard's buttons, hiding Blizzard's art, the vehicle-bar watch, Edit Mode stand-ins, switching off |
| `Layout.lua` | pixel-perfect geometry and button counts |
| `Skin.lua` | rim, gap, icon crop, state overlays, empty slots |
| `Text.lua` | the four texts, their hooks and lifted shadows |
| `Visibility.lua` | show conditions and fading |
| `Preview.lua` | Edit Mode stand-ins and the settings preview |
| `Settings.lua` | the settings page |

Shared additions:

- `PositionManager:SetEditable(id, editable)`: an element takes part in Edit
  Mode or not.
- An optional module hook, `OpenElementSettings(elementId)`, used by Edit Mode's
  **Open Module Settings**.
- `Kit.LayoutLift` takes the lift as an optional argument, for text ModeUI
  doesn't own.

## Not in this version

- Bars 9 and up, the extra action button, the zone ability, the vehicle leave
  button and the micro menu. These stay Blizzard's.
- Flyout direction: a flyout opens the way the hidden Blizzard bar would open it.
  Setting it would mean writing to Blizzard's buttons.
- Range coloring on the pet bar: Blizzard updates it from the pet bar's own
  OnUpdate, which doesn't run while that bar is hidden.
- Showing a bar hidden by its conditions while you drag a spell.

## Manual check

- **Navigation:** `/modeui`, then **Interface** › **Action Bars**.
- **Action:**
  - Turn the module on with the switch in the page header.
  - Pick bars with **Editing** and watch the preview change.
  - On the **Bar** tab, change **Buttons**, **Buttons per Line**, **Lines**,
    **First Button**, **Width**, **Height** and **Spacing**.
  - On **Buttons**, try each **Border** and turn **Show Empty Slots** off and on.
  - On **Text**, pick each text and move it with **Anchor**.
  - On **Visibility**, set Action Bar 2 to **In Combat**, then turn on **Fade
    Until Mouseover** for Action Bar 3.
  - Click **Edit Mode** in the window header and drag Action Bar 1.
  - Out of combat, use spells by key and by click. Swap forms or stances, drag a
    spell onto an empty slot, and enter and leave a vehicle if one is nearby.
- **Required state:** out of combat to change settings; spells on your bars;
  for the pet bar, a class with a pet.
- **Confirmation:**
  - Buttons are 42 by 38 with a thin rounded rim, and icons aren't stretched.
  - Keybinds, counts and cooldowns show where set, and keybinds turn red out of
    range.
  - Action Bar 2 appears only in combat. Action Bar 3 fades until you hover it.
  - Bars stay where you dragged them after `/reload`.
  - Stance and vehicle paging work.
  - No Lua errors, and no "action blocked" message in combat.
