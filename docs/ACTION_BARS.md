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

- **Buttons are 42 by 36** by default (Width and Height on the **Bar** tab).
  Sizes are whole physical pixels, and each bar is an even number of pixels each
  way, so a centered bar stays on the pixel grid.
- **Border:** Rounded (by default), Square or None, **Border Size** 1-4px (2px
  by default), in the **Border Color** (#101010 by default). The border is a
  hollow frame of four edges, so it never shows through a see-through
  background. Rounded leaves out each corner's outermost pixel.
- **Background:** inside the border, the **Background Color** (#040404 by
  default) with a ModeUI texture laid over it to lighten it
  (`Media/Textures/ActionBars/Slot.tga`, made by `tools/build_shape_textures.lua`):
  a dark slot, lighter in the middle, with a soft highlight along the top,
  darker edges and fine grain, after Blizzard's own recessed slots. It shows at
  **Background Opacity** (75% by default) everywhere: in ModeUI's empty slots,
  in Blizzard's own empty buttons (which the game shows with its Always Show
  Buttons option, or while a spell is dragged), and as the 1px line between
  border and icon. So every bar looks alike.
- **Icon:** placed 1px inside the border. It's cropped, never stretched: 8% comes off
  the edges, then the long side is cut to the button's shape. Blizzard's rounded
  icon mask is removed.
- **States:** highlight, pushed, checked, attack flash, new-spell and
  spell-highlight are flat overlays on the icon. Blizzard's slot art, frame and
  equipped-item border are faded.
- **Empty slots:** with **Show Empty Slots** on, the background marks each place
  without an action. Dragging a spell shows every button so it can be dropped.

## Text

Four texts, each with **Show This Text**, **Anchor** (a compass with Center),
**Size**, **Offset X**, **Offset Y** and **Color**:

| Text | Default |
|---|---|
| Keybind | shown, Top Right, 9, short |
| Count (stacks and charges) | shown, Bottom Right, 12 |
| Macro Name | hidden, Bottom, 10, #69A5B9 |
| Cooldown (the countdown numbers) | shown, Center, 14, amber #FFB12F |

Each text's box hugs its letters, 1 pixel inside the icon, and is justified to
its anchor's side, top or bottom. So the keybind sits right in the top-right
corner. Every bar shares one font setup: **Font** (Expressway by default),
**Outline** (on), **Slug Text** (on) and **Text Shadow** (None, Crisp by
default, or Lifted).

- Blizzard shows and hides these texts itself, so a hidden text is faded rather
  than hidden.
- **Short Keybinds** (on by default; shown on the Text tab with Keybind
  picked) writes modifiers as one letter with no hyphen: Shift-E is `sE`,
  Ctrl-1 `c1`, Alt-Mouse Button 4 `aM4`; long key names get short forms (Mouse
  Wheel Up `WU`, Num Pad 5 `N5`, Spacebar `Spc`). ModeUI rewrites Blizzard's
  keybind text after Blizzard writes it; turned off, Blizzard writes it again.
  Keybind Mode labels use the same short form.
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
- **Spacing** sets the gap between buttons (1px by default).
- Buttons past the count wait on the hidden frame.
- The stance bar shows no more buttons than you have stances, and hides when you
  have none.
- Default places:
  - Action Bar 1 is pinned to the bottom center of the screen.
  - Bars 2 and 3, the pet bar and the stance bar each stack 4 pixels above the
    one before.
  - Bar 4 sits on the right edge, with bar 5 beside it.
  - Bars 6-8 start hidden near the middle of the screen.

  Version 1 placed each bar on its own. Bars still at version 1's places move to
  the stacked ones; a bar you moved stays where it is.

## Edit Mode

**Edit Mode** shows every bar that's switched on, even ones set to Hidden or In
Combat, with all its slots. A cyan highlight sits over each one; that's the
stand-in you drag. The bar's name ("Action Bar 1") is on the handle centered
above it, in volt green (#CCFF00); the highlight itself carries no text.

- **The bar follows live** while you drag, frame by frame.
- **Anchoring:** **Snap To UI Element** in the Edit Mode window anchors a bar to
  the screen, the game's Player, Target, Focus or Party frames, the minimap, or
  any other bar. A bar can't anchor to one that already hangs from it (bar 1
  can't go on bar 2 while bar 2 sits on bar 1), so anchors never loop; Anchor To
  says so when you point at such a bar. A bar anchored to another moves
  with it. The secure bar itself is always pinned to the screen where its
  stand-in is, so it never hangs from another frame in combat.
- **Anchor To** clicks: while **Anchor To...** waits for a click, every
  stand-in (and its name handle) still takes the mouse without dragging, so the
  click picks the bar and never reaches a button on it.
- **Stacks stay on screen:** whenever an element moves (a preset side, a drag,
  a nudge, a new anchor), each element anchored **Above**, **Below**, **Left** or
  **Right** of another is checked. If its side would put it off the screen, or
  back over the frame its parent hangs from, and the opposite side is clear, it
  switches sides (its offset on that axis mirrored). This overrides the side it
  had, and runs down the chain. Moving Action Bar 1 to the top edge turns bars 2,
  3, pet and stance to stack downward under it; a side that still fits is kept.
- **X and Y:** the selected element shows its center's X and Y from the
  screen's center (whole UI units) left of its name, kept current while it's
  dragged or nudged.
- **Center Lines and Grid** (Edit Mode window): Center Lines (on by default)
  draw a vertical and a horizontal line through the screen's center, where X
  and Y are 0. **Grid** (off by default) adds faint lines every 32 units out
  from the center. Both are click-through, sit behind the elements, and last
  for the session, like Show Highlights.
- **Alignment guides:** while you drag any ModeUI element, a cyan line shows
  when its center comes within 8 units of a guide. Guides are:
  - its X or Y offset being 0
  - the screen's center
  - another movable element's center

  Let go there and it snaps onto the line. An offset of 0 snaps to exactly 0.
- **Nudging:** the selected element has four arrow buttons beside its name; each
  click moves it one physical pixel. The arrow keys do the same while the Edit
  Mode window is open, and Shift moves 10.
- **Open Module Settings** opens the page on the bar you selected.

## Keybind Mode

Type **/kb**, or click **Keybind Mode** on the **Bar** tab.

- Every bar that's switched on shows, with every slot, so empty places can be
  bound too. Each place shows its current key.
- Hover a place, then press a key (with Shift, Ctrl or Alt), a mouse button other
  than left or right, or the mouse wheel. That key becomes the button's only
  binding.
- **Escape** while hovering clears the button's keys.
- **Save** keeps the changes in your current binding set (character or account,
  as the game has it). **Discard** puts back the bindings from before.
- Escape away from a button, or entering combat, leaves Keybind Mode and saves.
- It binds the game's own commands (`ACTIONBUTTON1`, `MULTIACTIONBAR1BUTTON1`,
  `BONUSACTIONBUTTON1`, `SHAPESHIFTBUTTON1`, …), so the bindings also show in the
  game's Key Bindings.
- It needs the module on and works outside combat only.

## Visibility

**Show** picks when a bar is on screen:

- **Always**
- **Mouseover**: shown, but kept at **Faded Opacity** (0% by default) until the
  mouse is over the bar or a spell flyout from it, or you drag a spell
- **Hidden**: off screen, but still in Edit Mode and Keybind Mode
- **In Combat**
- **Out of Combat**
- **In Combat or With a Target**
- **Custom**: macro conditions such as `[combat][mod:shift] show; hide`. The
  game evaluates them, so they keep working in combat. Conditions the game can't
  read show the bar always.

Every bar hides during pet battles. The pet bar also needs a pet. The pet and
stance bars hide in vehicles and while possessing, as Blizzard's do. Action Bar
1 hides while the game shows its own vehicle bar (`OverrideActionBar`), which
then owns keys 1-12. **Show Bar** (on the **Bar** tab) off turns a bar off
completely, in Edit Mode too. Keybinds still work for hidden bars, as they do
for Blizzard's.

**Opacity** fades the whole bar. Moving the Opacity and Faded Opacity sliders
only sets the alpha on the bar and the preview, with no rebuild, so dragging
stays smooth. Opacity changes may happen in combat. Showing,
hiding, moving and sizing don't: anything that needs them waits for the end of
combat.

## Micro menu and bag bar

Blizzard's **micro menu** and **bag bar** are two more bars on the page:
**Micro Menu** and **Bag Bar** in **Editing**. ModeUI moves Blizzard's own
buttons onto them, so clicks, tooltips, alerts and bags work as before, and
gives them the same border, background, texture, text, font, size, spacing,
lines, Edit Mode and opacity settings as the action bars.

- **Which buttons:** the micro buttons Blizzard added to its micro menu (they
  carry a `layoutIndex`), in its order. On the bag bar, left to right as
  Blizzard shows them: key ring, reagent bag, bags 4 to 1, backpack. Only the
  buttons Blizzard shows are laid out (it hides Help outside China, the key ring
  without one, Housing while Timerunning), so a hidden one leaves no gap; when
  Blizzard shows or hides one, the bar lays out again (after combat).
- **The look:** micro buttons keep Blizzard's glyph (its Normal, Pushed,
  Disabled and Highlight art) inside the Mode border, on the Background Color;
  Blizzard's own button background, the Character button's portrait frame and
  shadow, and the latency bar on the menu button fade out. Alerts flash as a
  cyan overlay. Bag buttons are item buttons, so they take the action button
  skin: the icon cropped (the square mask comes off), the frame art faded, the
  pressed and highlight states flat, and a cyan overlay while that bag is open.
- **Text:** the micro menu has none. On the bag bar, **Count** is the
  backpack's free slots (Blizzard's `FreeSlots` text, shown while the game's
  Display Free Bag Slots option is on).
- **Sizes:** micro buttons 32 by 40 (Blizzard's shape), bag buttons 36 square.
- **Show:** **Always**, **Mouseover** or **Hidden**. They stay through pet
  battles and vehicles, when Blizzard moves its (now empty) micro menu away.
- **Places:** the micro menu in the bottom-right corner, the bag bar on top of it
  with the right edges lined up. Either can anchor to any bar, and any bar to
  them.
- **Not for these bars:** Keybind Mode, paging, glows and the On Cooldown look.
- **Keeping the look:** Blizzard re-applies its micro button art in `SetPushed`
  and `SetNormal` (every `UpdateMicroButtons`), its bag button art in
  `UpdateTextures`, and re-anchors the bag buttons in `BagsBar:Layout` (when an
  item is picked up, among others). Hooks restyle and re-place them, in combat
  too (none of them is protected in Blizzard's source; if the client says one
  is, combat leaves it for the refresh after). Blizzard's empty `MicroMenu` and
  `BagsBar` fade to 0 alpha, which hides their frame art and the bag dividers.
  ModeUI only hooks them; it never writes to them or calls their layout code.
- **Switching off** gives the buttons back where they were and the two Blizzard
  bars their alpha; Blizzard's look returns on reload.

## Settings page

The preview above the five tabs is **your own bar**: the bar being edited, with
the spells, keybinds, counts, macro names and running cooldowns on its buttons
right now. Empty places show as empty slots, and the preview redraws when your
bars, bindings or cooldowns change. While you edit the **Cooldown** text, the
first spell shows a sample cooldown if none is running; **Animated** runs it.
**Keybind Mode** sits in the preview's header after Static, Animated and Collapse, and **Editing** at its top right, so both are one click from every tab. (Shared: a page can add its own header buttons with `previewHeaderButtons` and keep the top right clear with `previewReserveRight`.)

While the page is open, each bar on screen wears a small name tag in its middle
("Action Bar 1", "Pet Bar", …), so you can tell the bars apart without Edit
Mode. The bar being edited has a cyan tag; clicking any tag edits that bar.

Clicking a button opens the **Bar** tab and its glow menu (see Glows); clicking a text opens the **Text** tab
on that text. The tabs:

- **Bar**: Show Bar, status, layout, size, Keybind Mode, paging
- **Buttons**: border style, size and color; background color and opacity;
  empty slots; On Cooldown (Icon Color, Icon Opacity)
- **Text**: which text, then its place, size and color, and the font
- **Glows**: proc glow, glow when ready
- **Visibility**: Show, custom conditions, opacity, Faded Opacity
- **Copy & Apply**: Copy From (the bar in Editing), Apply To, Reset

**Editing** (the bar being changed) sits at the top right of the preview, so it's
always in view and shared by every tab. Its list marks bars that are **Off** (Show
Bar off) or **Hidden** (Show set to Hidden). When the chosen bar is either, a
**Turn On** button appears beside it: it switches Show Bar on, and sets Show back
to Always if it was Hidden. A tab also says so when that bar is off.

**Copy & Apply** tab: **Copy From** is a dropdown showing the source, the bar in
Editing; choosing a bar there changes Editing too. **Apply To** is a pick list:
each bar has a check box, clicking a bar ticks or unticks it and the list stays
open, and the field reads "Choose bars", the bar's name, or "3 bars selected".
The source shows as **Source** and can't be picked. The list closes on a click
outside it. Then **Apply to Selected**, or **Apply to All Bars**. The picked
bars get the source's size, borders, background, text, glows and opacity; each
keeps its own buttons, lines, paging, show settings and per-button glow
switches. The result ("Applied to 2 bars.") shows beside the buttons. **Reset**
holds **Reset to Defaults** for the bar in Editing.

## Paging

Action bars 1-8 can switch pages: the same twelve buttons show another page of
actions. The bar's state driver picks a page from macro conditions, and a
snippet in the game's secure environment sets it on each button
(`actionpage`), so pages change in combat too.

- **Page Switching** (on the **Bar** tab) turns it on or off for a bar.
- **Page Conditions**: macro conditions that name a page, like
  `[mod:shift] 2; [bonusbar:1] 7`. Pages 1-6 are the game's bars; 7-10 are
  stance and form pages (`bonusbar:1` to `4`). When none match, the bar shows
  its own page. Conditions the game can't read leave the bar on its own page.
- **Action Bar 1**: on by default with no conditions, which means the game's own
  paging (stances, forms, stealth, vehicles, override bars and the page keys).
  Give it conditions to page it your own way. With Page Switching off it always
  shows page 1.
- **Bars 2-8**: off by default, each on its own page. Switched on, they start
  with `[mod:shift] 2; [mod:ctrl] 3; [mod:alt] 4`.
- The pet and stance bars don't page.

## Glows

How buttons react, on the **Glows** tab (per bar):

- **Proc Glow**: how a proc (the game lighting up a spell to use now) shows.
  **Mode Glow** (by default) is a soft glow around the button; **Border** is a
  2px frame on it; **Blizzard** keeps the game's own animation; **None** shows
  nothing. **Proc Color** (gold, #FFD25A, by default) and **Pulse** apply to Mode
  Glow and Border. ModeUI hooks `ActionButtonSpellAlertManager:ShowAlert` and
  `HideAlert` and fades Blizzard's alert frame unless Blizzard is chosen.
- **Glow When Ready** (on by default): when a cooldown longer than the global
  cooldown ends, the button lights for **Glow Time** (2 seconds by default), as a
  **Glow** or **Border** in **Glow Color** (Mode cyan by default). ModeUI checks
  `C_ActionBar.GetActionCooldown` on `SPELL_UPDATE_COOLDOWN`; its `isActive` and
  `isOnGCD` fields are never secret, so this works in combat and ignores the
  global cooldown.
- **On Cooldown** (Buttons tab) starts by saying what it covers: an ability on
  a cooldown longer than the global cooldown.
- **Icon Color**: **Desaturate** (the default) turns the icon gray while that
  cooldown runs and gives its color back when it's ready; **Full Color** keeps
  it as it is. It's the saved `cooldownDesaturate` switch.
- **Icon Opacity** (on cooldown): fades an icon while its spell is on such a
  cooldown. 100% (the default) leaves icons alone.
- Desaturation details: Blizzard
  clears desaturation when a button's action changes; a hook puts it back while
  the cooldown still runs, and ModeUI only undoes its own (a level-locked
  action stays gray).
- **One glow at a time**: when a button wants its proc glow and its ready glow
  together, a soft glow wins over a border (Blizzard's own proc animation counts
  as a glow); two of the same kind, the proc glow wins. The other comes back when
  the winner ends.
- **The glow menu**: click a button in the preview. It opens the Bar tab and a
  menu to the left of the button, which stays open while the page scrolls and
  closes on a click anywhere else, its **X**, switching bars, leaving the page
  or combat. It has:
  - **This Button**: **Proc Glow**, **Glow When Ready** and **Desaturate on
    Cooldown**, switches for just this button (the last two gray out while the
    bar's own switch is off).
  - **Copy**, **Paste** and **Apply to Bar**: copy this button's switches, paste
    them onto another button (any bar), or give every button on this bar the
    same switches.
  - **This Bar**: the bar's Proc Glow and Ready Glow styles.
  - **All Glow Settings** opens the Glows tab.

  While the menu is open its button previews its glow (Blizzard's own animation
  for the Blizzard style). A proc lit on the real bar also shows on its preview
  button. Switches are kept by place (`"1"` to `"12"`), only while off.
- Glow When Ready and Icon Opacity apply to action bars 1-8.

## Switching it off

Each button goes back to its Blizzard bar with its old place and size, and
Blizzard's bars come back. The Mode skin stays on the buttons until you reload,
so ModeUI offers a reload. Turning the module back on needs no reload.

## Settings versions

`ModeUIDB.modules.actionBars` holds one table per bar: `bar1`-`bar8`, `pet`,
`stance`. Positions are saved under `positions.actionBarsBar1` to
`actionBarsBar8`, `actionBarsPet` and `actionBarsStance`.

Version 5 changed these from version 4:

- Every bar's keybind text is 2px smaller (11 becomes 9).
- **Desaturate Icon**, **Short Keybinds** and the per-button glow switches take
  their defaults (on, on, none switched off).

Version 4 changed these from version 3 (the owner asked for them on every bar):

- Every bar's **Border Color** becomes #101010 and its **Background Opacity**
  75%, whatever they were.
- Paging and glows take their defaults.

Version 3 changed these from version 2:

- A border color still #25282C becomes #404542, muted macro names become
  #69A5B9, and 2px spacing becomes 1px.
- **Border Size** (2px) and **Background Color** (#040404) take their defaults.

Version 2 changed these from version 1:

- Buttons still 38 tall become 36.
- White cooldown numbers become amber.
- Fade Until Mouseover with Show set to Always becomes **Mouseover**; the switch
  is gone.
- **Background Opacity** starts at 20%.
- Places still at version 1's defaults move to the stacked defaults.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the bars and their Blizzard buttons, anchor targets, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: defaults, validation and the migrations to version 4 |
| `Driver.lua` | lifecycle, events, `/kb`, settings changes, copy and reset, the font and color owner, moving version 1 places |
| `Bars.lua` | secure bars, moving Blizzard's buttons, hiding Blizzard's art, the vehicle-bar watch, the paging snippet, Edit Mode stand-ins and live follow, switching off |
| `Layout.lua` | pixel-perfect geometry and button counts |
| `Skin.lua` | rim, gap, background, icon crop, state overlays, empty slots |
| `Text.lua` | the four texts, their hooks and lifted shadows |
| `Utility.lua` | the micro menu and bag bar: their buttons, skin, hooks and Show |
| `Visibility.lua` | show and page conditions, fading |
| `Glow.lua` | proc glows, the ready glow, icon opacity and desaturation on cooldown |
| `GlowMenu.lua` | the preview's glow menu, per-button switches with copy, paste and apply to bar, glow previews |
| `Keybind.lua` | Keybind Mode |
| `Preview.lua` | the Edit Mode highlight and the live settings preview |
| `Settings.lua` | the settings page |

Shared additions:

- `PositionManager:SetEditable(id, editable)`: an element takes part in Edit
  Mode or not.
- `Positioning:AddTarget(id, label, name)`: a ModeUI frame other elements can
  anchor to.
- `Shared/Placement/PositionGuides.lua`: alignment guides, snapping on drop,
  and `PositionManager:Nudge(id, dx, dy)`.
- Nudge arrows on the selected element, and arrow keys in the Edit Mode window.
- An optional module hook, `OpenElementSettings(elementId)`, used by Edit Mode's
  **Open Module Settings**.
- `Kit.LayoutLift` takes the lift as an optional argument, for text ModeUI
  doesn't own.

## Not in this version

- Bars 9 and up, the extra action button, the zone ability and the vehicle
  leave button. These stay Blizzard's.
- Keybinds on micro and bag buttons in Keybind Mode (the game's Key Bindings
  sets them).
- Flyout direction: a flyout opens the way the hidden Blizzard bar would open it.
  Setting it would mean writing to Blizzard's buttons.
- Range coloring on the pet bar: Blizzard updates it from the pet bar's own
  OnUpdate, which doesn't run while that bar is hidden.
- Showing a bar hidden by its conditions while you drag a spell.
- A second key per button in Keybind Mode. The game's Key Bindings still sets
  two.

## Manual check

- **Navigation:** `/modeui`, then **Interface** › **Action Bars**.
- **Action:**
  - Turn the module on with the switch in the page header.
  - Pick bars with **Editing** and check that the preview shows that bar's
    spells and keybinds.
  - On the **Text** tab, pick **Cooldown** and watch the sample cooldown.
  - On **Buttons**, move **Background Opacity**.
  - On **Visibility**, set Action Bar 3's **Show** to **Mouseover**, then
    Action Bar 2's to **Hidden**.
  - Click **Edit Mode** in the window header, drag Action Bar 1 slowly across
    the screen's center and let go near it.
  - Click the arrow buttons beside a bar's name, and press the arrow keys.
  - In the Edit Mode window, set Action Bar 3's **Snap To UI Element** to
    **Action Bar 1**.
  - Exit Edit Mode, type `/kb`, hover a button, press a key, then click **Save**.
  - Pick **Micro Menu** in **Editing**, set **Show** to **Mouseover**, then pick
    **Bag Bar** and pick up an item from a bag.
- **Required state:** out of combat; spells on your bars.
- **Confirmation:**
  - Buttons are 42 by 36, with a faint textured background in empty slots.
  - Keybinds sit tight in the top-right corner. Cooldown numbers are amber.
  - In Edit Mode, each bar is highlighted, its name in volt green on the handle
    centered above it, and moves with the mouse without lag.
  - A cyan line appears near the center, and the bar snaps onto it.
  - Each arrow click moves the bar one pixel.
  - Action Bar 3 shows only under the mouse. Action Bar 2 shows only in Edit
    Mode and `/kb`.
  - The new key works and is listed in the game's Key Bindings.
  - The micro and bag buttons sit in Mode borders in the bottom-right corner;
    the micro menu fades until the mouse is over it, and the bag buttons stay
    in place when an item is picked up.
  - No Lua errors, and no "action blocked" message in combat.
