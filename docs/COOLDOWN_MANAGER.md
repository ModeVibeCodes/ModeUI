# Cooldown Manager

November 13, 2026. A **standalone** module: it has its own window, opened
with **`/mcdm`**, and no page in ModeUI's settings window. Off by default (the
switch in its window's page header). Only checked against the mock client
(`tests/cooldown_manager.lua`); **native acceptance is pending**. Its APIs and
their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#cooldown-manager--november-13-2026).

## What it does

Blizzard's own Cooldown Manager in the Mode look, plus bars of your own.
Forever ships it (`Blizzard_CooldownViewer`, loaded for the `camelot` game
type) with four viewers: **Essential Cooldowns**, **Utility Cooldowns**,
**Tracked Buffs** and **Tracked Bars**. Blizzard keeps deciding which spells
are tracked and keeps every icon's cooldown, charges, auras, range and procs
up to date. ModeUI places, lays out, skins and lights them, and lets you
move tracked spells onto **custom bars**.

### The window

`/mcdm` opens and closes it; it's built the first time. ModeUI's Mode look,
on the shared settings widgets:

- **Header:** the title, **Open CDM** (Blizzard's Cooldown Manager window,
  where you choose the tracked spells; outside combat), **Edit Mode** and
  the close button. Edit Mode hides the window and brings it back when it
  ends.
- **List** on the left: **Spells and Abilities** (the four viewers), then
  **Cooldown Bars** and **Buff Bars** (your custom bars, up to ten), each
  heading with a **+** on its right that makes a new bar of that kind, and
  each custom bar with a **-** that deletes it after asking (**Delete Bar**
  in the confirmation). **Resource Bars** come last. A bar that's off says so.
- **Page** on the right: the module's title and on/off switch, **Editing**
  (the bar being edited, with a dropdown of every bar, at the top right), a
  live preview of that bar, and its tabs: Bar, Look, Text, Glows, Spells,
  Visibility, Copy & Apply.

### Every bar's settings

| Part | Look and behavior |
|---|---|
| Placement | Each bar has a stand-in in ModeUI's Edit Mode (`ModeUICooldownEssential`, ..., `ModeUICooldownCustom1`), one full line long, anchored to the screen or to any ModeUI element (another Cooldown Manager bar, a resource bar, your unit frames, ...). Anchored, it sits 1 px off its target's edge, pixel-perfect at any UI scale; the nudge buttons move it from there. **Match Width** and **Match Height** in the Edit Mode window size its line to what it's anchored on, separately, and follow that element when its size changes (the size is pushed on change, never polled). The first line never moves; more lines grow outside it. Essential starts at the bottom middle, 300 px up, Utility under it, Tracked Buffs on top, Tracked Bars to the right; custom bars in the middle of the screen. Icons are 8 px wider than tall by default (Essential 42 by 34; Utility, buffs and custom bars 36 by 28). |
| Growth | **Centered Horizontal** (default), **Centered Vertical**, **Horizontal Right**, **Horizontal Left**, **Vertical Down** or **Vertical Up**, with **New Lines** going Down or Up for rows, Right or Left for columns (Tracked Buffs and Bars: Up). **Icons per Line** (12; bars 1; custom bars 8), Spacing (2 px), Width and Height. Spells Blizzard hides (an inactive buff) leave no gap. |
| Icons | **Border**: **ModeUI** (default; ModeUI's standard border, `Kit.ModeBoxBorder`: one crisp 2px rim in Border Color, #40454C, with corners rounded 4px, on its own frame above the icon), or the action bars' slot rim (**Rounded**, **Square**, with Border Size) or **None**. Inside it the 75% background with the slot grain and the icon, cropped square, starting at the rim's inner edge, so the rim's corners cover the icon's square corners (no mask on Blizzard's textures). Tracked Bars' icons and bar boxes take the same border. Blizzard's round mask and frame art come off. |
| Cooldown | **Desaturate on Cooldown** (on): an icon goes gray while its spell is on a real cooldown (not the global cooldown) and takes its color back within a fifth of a second of the cooldown ending: the game sends no event then, so icons on a real cooldown are asked about again by one small ticker that runs only while one is cooling; off, icons keep full color. A flat swipe in Swipe Color at Swipe Opacity (70%). While a spell's effect is up Blizzard shows the effect's time in a full-color gold swipe; ModeUI shows the spell's own cooldown instead, gray, straight away. **Show Aura Time** brings Blizzard's gold swipe back. **Edge**, **Bling**, **Ready Flash**, **Out of Range Tint** (Blizzard's red tint on an out-of-range spell; off keeps full color) and, on buffs, **Debuff Border**. Blizzard's out-of-range shade, cut to its round mask, stays faded: repainted it showed as a solid red block, and Blizzard leaves it shown on an icon with no spell yet. |
| Bars | Tracked Bars: the icon in the Mode slot beside the bar's own box, filled in Bar Texture (Mode Gradient) and Bar Color over Bar Background; Icon Side, Spark. |
| Text | Icons: **Cooldown** and **Count**; bars: **Name**, **Duration**, **Count**. The Text tab sets the bar's look: each text's Show This Text, Anchor, Size, Offsets and Color; Font, Outline, Text Shadow, Slug Text. A spell can have its own look per text from its menu (below). |
| Glows | Every glow starts off on every spell; a spell's menu switches one on. Cooldown icons: **Proc Glow** (the game lights the spell up; Blizzard's own animation stays hidden while the module is on), **Active Glow** (while the spell's effect is up), **Off Cooldown Glow** (**Flash** for Glow Time when a cooldown ends, or **While Ready**). One shows at a time: proc, active, off cooldown. Buff icons: **Buff Glow** (while the buff is up). Tracked Bars have none. Each glow has its own look per spell: a Style (**Mode Glow**, **Border**, **Pixel**: marching lines with Lines and Thickness, **Blizzard**: the game's proc loop, **GCD**: the game's rotation-assist art), a Color and, for Mode Glow and Border, Pulse. The Glows tab sets the **Glow Defaults**, the look a glow starts with when switched on (Proc: Blizzard, gold; Active: Border; Off Cooldown: Pixel; Buff: Mode Glow). |
| Spells | Clicking a spell in the preview opens its menu: **Show on This Bar**, a switch for each of the bar's glows, each with a **>** that opens its popout beside the menu (**Glow On**, Style, Color, Pulse, Lines, Thickness, and for the off-cooldown glow When and Glow Time; the preview shows that glow while it's open; changing the look switches the glow on), a **Text** row per text (Cooldown Text and Count Text on icons; Name, Duration and Count Text on bars), each with a **>** that opens its text popout (**Show This Text**, **Text Shadow**, **Font**, **Size**, **Color**, **Outline**: None, Outline or Thick, **Anchor**, **Offset X** and **Offset Y**; the first change copies the bar's look and changes it, the row then says "own look", and **Use Bar's Look** goes back; the preview shows that text on the spell while it's open), **Copy**, **Paste**, **Apply to Bar**, **Glow Defaults**, **Earlier** and **Later**; on a custom bar, Essential and Utility also **Remove from Bar** (a viewer's own spell hides there). One popout shows at a time. **Dragging** a spell in the preview moves it: a copy of its icon follows the cursor, the slot under it lights up, and letting go there puts the spell in that place (a plain click still opens the menu). On a custom bar this is its list's order; on a viewer it's ModeUI's own order for that bar (`order`), which only changes where ModeUI lays the icons out: Blizzard's window keeps its order, and spells it starts tracking later go at the end. Only the preview's icons can be dragged; Blizzard's icons on screen are never made draggable. Hidden spells leave no gap and show faded in the preview. Switches are kept by the game's cooldown ID. **Reset All Spells** on the Spells tab clears them. |
| Visibility | Show: Always, In Combat, Out of Combat, In Combat or With a Target, Mouseover (Faded Opacity) or Hidden; Opacity; **Show Bar**. |
| Copy & Apply | The bar being edited is the source; its look goes to the bars you tick, each keeping its size, lines, spells and show settings. **Reset to Defaults**. |

### Custom bars

The **+** on the **Cooldown Bars** heading makes a bar for spells from
Essential and Utility Cooldowns; the one on **Buff Bars** a bar for Tracked
Buffs. Its preview ends with a **+** slot. Clicking it opens a list of icons
in up to three sections (pointing at one names it and says what a click does):

- **Tracked in Blizzard CDM**: the spells Blizzard's Cooldown Manager tracks
  that the bar can take. Clicking one adds it: Blizzard's own icon for that
  spell moves onto the custom bar, so it keeps updating exactly as before,
  and its viewer closes up. A spell sits on one custom bar at a time; adding
  it to another moves it.
- **Not in Blizzard CDM**: every other spell the game has for your class and
  spec in those categories (`C_CooldownViewer.GetCooldownViewerCategorySet`
  with unlearned spells), grayed; ones you haven't learned say so. On a
  Cooldown Bar clicking one adds it as a custom spell (below). A buff can only
  show once Blizzard's Cooldown Manager tracks it, so on a Buff Bar these only
  point you there.
- **Items in Your Bags** (Cooldown Bars): what you carry with a Use: effect,
  such as potions, healthstones and food.

The bar's Bar tab has its **Name**, how many spells it holds and **Delete
Bar** (its spells go back to their viewers). A tracked spell you stop
tracking in Blizzard's window stays in the bar, faded and gray in the
preview, and comes back when you track it again.

### Adding to Essential and Utility

Essential and Utility Cooldowns' previews end with the same **+** slot and
list. **Tracked in Blizzard CDM** shows the other viewer's spells and those
on custom bars; clicking one moves it here, after Essential's own spells.
**Not in Blizzard CDM**, **Items in Your Bags**, **Spell ID** and **Item ID**
work as on a Cooldown Bar. What a viewer took is saved in `extras` and shows
after Blizzard's own spells, in the order you give it (**Earlier**,
**Later**). Blizzard's Cooldown Manager still decides which spells a viewer
tracks, so **Remove from Bar** on one of the viewer's own spells hides it
there; it shows faded in the preview and at the top of the **+** list, where
a click brings it back. A spell moved from Utility keeps Utility's own
Visibility, like a custom bar's. On Tracked Buffs and Tracked Bars the **+**
slot opens Blizzard's Cooldown Manager.

Custom bars follow the viewer their spells come from for Blizzard's own
Visibility and the game option: the icons are still that viewer's children.

### Racial abilities

Your race's abilities (Berserking, Stoneform, Arcane Torrent, Fireblood,
...) are added on their own. Blizzard's Cooldown Manager doesn't track them,
so they show on ModeUI's own icons at the end of one bar: **Utility** by
default. **Racial Abilities** on the Bar tab of Essential, Utility or a
Cooldown Bar picks the bar, or **Off**. Only racials your character knows
show (`C_SpellBook.IsSpellKnown`), worked out again whenever your spells
change, so nothing is saved per racial. They work like spells added by ID:
cooldown, charges, gray on cooldown, the Proc and Off Cooldown glows, text
looks, dragging. **Remove from Bar** hides one there. Another bar's **+**
list offers them under **Not in Blizzard CDM**. Deleting the custom bar that
held them moves them back to Utility.

### Custom spells and items

The **+** list of a Cooldown Bar, Essential or Utility ends with **Spell ID** and **Item ID**: type an
ID and press Enter or **Add**.

- **Spell ID** takes a spell you know, tracked in Blizzard's Cooldown Manager
  or not; a spell your character doesn't have is refused (it would never
  show), pointing you at Item ID for an item of the same name (Thistle Tea).
  It gets an icon of ModeUI's own on the bar (saved as `s<ID>` among the
  bar's spells, or a viewer's `extras`), with the bar's border, text, gray on cooldown, Proc and Off
  Cooldown glows, per-spell switches and order, plus a blue tint while short
  of power and a gray one while unusable, and the spell's tooltip. It shows
  only while you know the spell, or what replaces it now (an override follows
  its picture, cooldown and procs); a class spell added unlearned from the
  list shows once you learn it. The cooldown and recharge come as duration
  objects straight to the icon's cooldown, which draws the numbers; charge
  counts go straight to the text.
- **Item ID** takes an item with a Use: effect (saved as `i<ID>`): its
  picture, cooldown (`C_Container.GetItemCooldown`), how many you carry
  (charges counted), the item's tooltip, gray on cooldown and the Off
  Cooldown glow. With none left it stays, gray, showing 0.

The Active and Buff glows need Blizzard's own tracking, so they don't light
on custom spells or items, and neither goes on a Buff Bar. Their icons hide
while the module is off.

## What stays Blizzard's

- **Which spells are tracked, and their order** in each viewer: Blizzard's
  Cooldown Manager window (**Open CDM**).
- **Blizzard's Edit Mode options** for each viewer: Visibility, Opacity, Hide
  When Inactive, Show Timer, Show Tooltips and Bar Content. Its Icon Size,
  Padding, Icon Limit, Orientation and Icon Direction are replaced by
  ModeUI's, and its Edit Mode box no longer moves a viewer.
- **The game option** `cooldownViewerEnabled`, which ModeUI never changes;
  the Status line says when it's off.

## How it follows Blizzard

The viewers and their item frames are plain frames (no secure template), so
everything here works in combat. But Blizzard's code in them does math on
secret cooldown and aura values, which it may only do while it runs
untainted. So ModeUI:

- **never writes a field** on a viewer or item frame (its textures, glows and
  state live in weak tables keyed by the frame). `tests/cooldown_manager_stubs.lua`
  fails any write from ModeUI's files onto Blizzard's frames.
- **only post-hooks** (`hooksecurefunc`), each body through `pcall`:
  - viewer `OnAcquireItemFrame`, `Layout` (re-place the icons at once, on the
    viewer's holder or a custom bar's) and `RefreshData`;
  - item `UpdateShownState` (close gaps), `RefreshSpellCooldownInfo`,
    `RefreshCooldownInfo` and `RefreshIconDesaturation` (swipe, edge, gray and
    the active glow back after Blizzard's), `SetIsActive` (the buff glow),
    and on bars `SetBarContent`;
  - `ActionButtonSpellAlertManager:ShowAlert`/`HideAlert` for procs.
- **never calls a Blizzard method that refreshes or lays out**, and never
  shows, hides, moves, scales or fades Blizzard's viewer frames. Icons stay
  Blizzard's children and are re-anchored to ModeUI's holders; visibility
  and hidden spells fade the icons (`SetAlpha`).
- reads only public values: cooldown IDs, each entry's spell
  (`GetCooldownViewerCooldownInfo`), names and icons, and
  `C_Spell.GetSpellCooldown`'s never-secret `isActive` and `isOnGCD` (gray,
  off-cooldown glow). The active glow compares Blizzard's swipe color table
  by reference (`rawequal`). While an effect is up, the icon's Cooldown is
  set to the spell's own cooldown duration object
  (`SetUseAuraDisplayTime(false)`, `SetCooldownFromDurationObject`) after
  Blizzard's refresh, so the swipe stays secret-safe. A buff's active state can be secret in combat;
  it goes straight to `SetAlphaFromBoolean` on the glow's textures, which
  accepts secrets from addon code. A secret shown state counts as shown.

Switching the module off stops the placement, glows and fading at once (every
icon back at full); the next time Blizzard lays a viewer out, its own grid
returns. Blizzard's look comes back with a reload, which ModeUI offers when
the window closes.

## Saved settings

`ModeUIDB` profile `modules.cooldownManager`: one table per viewer, one per
custom bar (`custom1`, ...), `customBars` (each bar's ID, name, kind and
spells in order) and `nextCustom`. Version 2 replaced Lines, First Icon and
Center Lines with Growth and New Lines, and the ready glow's switch and style
with the Off Cooldown glow's style (a flash, as before); the migration keeps
your choices. Version 3 gave every bar the ModeUI border (a Rounded border, the old default, becomes it, and the old #101010 color its color; Square and None stay). Version 4 moved the default sizes to 8 px wider than tall (a size you chose stays), set Utility's default place against Essential (the 1px gap is built in), and made glows per spell: each bar's glow styles become its Glow Defaults (None becomes Mode Glow), and a spell's glow switch keeps the look as its own. Custom bars' spells also take items (`i<ID>`, Cooldown Bars only). Added later without a version step (a profile saved before starts empty): `extras = { essential = {...}, utility = {...} }`, the spells those viewers took (cooldown IDs, `s<ID>`, `i<ID>`), `order = { essential = { "102", "101", ... } }`, a viewer's spell order once you move one, `racials` (the bar racials show on: `"utility"` by default, `"essential"`, a custom Cooldown Bar's ID or `"none"`), and a spell's own text looks, `spells[key].text = { count = { show, size, anchor, x, y, color, font, fontMedia, outline = "none" | "outline" | "thick", shadow } }`. Bad data stops startup; nothing is reset.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration (standalone), the viewers and custom bar kinds, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: version 1 to 2, validation |
| `Driver.lua` | lifecycle, `/mcdm`, events, settings changes, per-spell switches, copy and reset, status |
| `Custom.lua` | the bar list, custom bars, what Essential and Utility took, and which spell shows where |
| `Spells.lua`, `Items.lua`, `Racials.lua` | custom spells, items and racials on ModeUI's own icons |
| `Blizzard.lua` | finding and hooking Blizzard's viewers and items |
| `Layout.lua` | Growth geometry, stand-ins and holders, placing the icons |
| `Skin.lua`, `Bars.lua`, `Text.lua` | icon skin, swipe and gray; Tracked Bars; texts and a spell's own text looks |
| `Glow.lua` | the four glows; a spell's alpha |
| `GlowPopout.lua`, `TextPopout.lua` | a glow's and a text's popout beside the spell menu |
| `Visibility.lua` | Show, Opacity, Mouseover |
| `SpellMenu.lua`, `Picker.lua`, `Preview.lua`, `PreviewDrag.lua` | the preview, its spell menu, the + slot's list, and dragging spells to move them |
| `Settings.lua`, `SettingsTabs.lua` | the settings page |
| `Window.lua` | the module's own window |

Shared pieces it uses or added: `Shared/Domain/Cooldowns.lua`,
`Shared/Domain/Items.lua`, `Shared/Kit/Slot.lua`, `Kit.OutlineFlags` (a thick outline), `Shared/Kit/Glows.lua`
(Pixel, Blizzard and GCD glows on one shared ticker), `W.Confirm`
(`Shared/Settings/Confirm.lua`), size matching and pixel gaps in the
PositionManager (`gapPixels`, `SetSizeMatch`, `AllowTarget`, `RemoveTarget`), `addon:RegisterSettingsWindow` (Edit Mode returns to
a standalone module's window), `PositionManager:SetLabel`, and the
`standalone` module field (no sidebar entry or search results in ModeUI's
window; Edit Mode's Open Module Settings calls `module:OpenSettings`).

## In-game check

1. Custom bar, glows and the active swipe
   - **Navigation:** type `/mcdm`.
   - **Action:** turn the module on with the switch at the top right of the
     window's page. Click the **+** on the **Cooldown Bars** heading, then the
     **+** slot in the preview, and click a spell under **Tracked in Blizzard
     CDM**. Click that spell's icon in the preview, then the **>** beside
     **Proc Glow**, and choose **Pixel** under Style. Cast a spell with a
     lasting effect from Essential Cooldowns.
   - **Required state:** out of combat for the clicks, with the game's
     Cooldown Manager option on and spells tracked in Blizzard's Cooldown
     Manager (**Open CDM**).
   - **Confirmation:** the spell leaves its viewer (the rest close up) and
     shows on the new bar; the popout shows the Pixel glow on it in the
     preview; the cast spell goes gray with its own cooldown at once, with
     no gold full-color swipe while its effect is up.
2. Class spells and items
   - **Navigation:** type `/mcdm`, click your Cooldown Bar in the list.
   - **Action:** click the **+** slot in the preview; click a grayed icon
     under **Not in Blizzard CDM**; click a potion or healthstone under
     **Items in Your Bags**; type a spell ID you don't know in **Spell ID**
     and click **Add**.
   - **Required state:** out of combat, carrying a usable item.
   - **Confirmation:** the grayed spell and the item show on the bar (the
     item with its count, gray while it cools down); the unknown spell is
     refused with "You don't know that spell. An item? Add it by Item ID."
3. Anchoring and matching
   - **Navigation:** click **Edit Mode** in the window's header.
   - **Action:** select your custom bar's stand-in, anchor it below
     Essential Cooldowns, tick **Match Width**, click a nudge button; then
     change Essential's **Icons per Line** in `/mcdm` (Bar tab).
   - **Required state:** out of combat.
   - **Confirmation:** the bar sits 1 px under Essential, the nudge moves it,
     and its width follows Essential's with no stutter. Clicking **-** on the
     bar in the list asks before deleting it. ModeUI's own window
     (`/modeui`) has no Cooldown Manager page. In combat, cooldowns, charges
     and procs keep updating, with no Lua errors.
4. Adding to Essential, and a spell's own text
   - **Navigation:** type `/mcdm`, click **Essential Cooldowns** in the list.
   - **Action:** click the **+** slot in the preview and click a Utility
     spell under **Tracked in Blizzard CDM**, then a potion under **Items in
     Your Bags**. Click one of Essential's own spells in the preview, click
     **Remove from Bar**, then open the **+** list again and click it at the
     top. Click a spell in the preview, then the **>** beside **Cooldown
     Text**; choose **Thick** under Outline, the **Top Left** anchor, and a
     Size of 18; then click **Use Bar's Look**.
   - **Required state:** out of combat, with spells tracked in both Essential
     and Utility in Blizzard's Cooldown Manager, carrying a usable item.
   - **Confirmation:** the Utility spell and the potion show at the end of
     Essential (Utility closes up); the removed spell disappears from
     Essential and comes back from the list; while the popout is open the
     spell shows a sample cooldown in the preview, and on screen its cooldown
     numbers turn thick-outlined, top left, larger, while the other spells
     keep the bar's look; **Use Bar's Look** puts them back.
5. Dragging to reorder
   - **Navigation:** type `/mcdm`, click **Essential Cooldowns** in the list.
   - **Action:** press on the first spell in the preview, drag it onto the
     third, and let go; then do the same on your Cooldown Bar; then click a
     spell without dragging.
   - **Required state:** out of combat, with at least three spells on each
     bar.
   - **Confirmation:** while dragging, a copy of the icon follows the cursor
     and the third slot lights up; after letting go the spell is third in the
     preview and on screen, and stays third after `/reload`; Blizzard's own
     Cooldown Manager window keeps its order; the plain click opens the
     spell's menu.
6. Racial abilities
   - **Navigation:** type `/mcdm`, click **Utility Cooldowns** in the list.
   - **Action:** look at the end of the preview; then on the Bar tab under
     **Racial Abilities** pick **Essential Cooldowns** in **Show On**, then
     **Off**, then **Utility Cooldowns** again. Use the racial in combat.
   - **Required state:** a character with an active racial (Berserking,
     Stoneform, Arcane Torrent...), out of combat for the clicks.
   - **Confirmation:** your racial shows at the end of Utility (on screen
     and in the preview) and only your race's; it moves to Essential, goes
     away with Off and comes back on Utility; in combat it shows its
     cooldown and goes gray while cooling, with no Lua errors.

## Resource Bars

November 13, 2026. Your own health and power next to the cooldowns, in the
same `/mcdm` window: the list has a **Resource Bars** group between
Blizzard and Custom Bars. Checked against the mock client only
(`tests/resource_bars.lua`); **native acceptance is pending**. Their APIs
are in [API_COMPATIBILITY.md](API_COMPATIBILITY.md#cooldown-manager-resource-bars--november-13-2026).
They run while the Cooldown Manager is on, whatever Blizzard's Cooldown
Manager option says.

| Bar | Shows | Default |
|---|---|---|
| **Power** | the power your character shows now: mana, rage or energy, in its own color | on, 14px, Current text |
| **Combo Points** | one box per point you can hold, lit for each point on your target (Rogues; Druids in Cat Form) | on, 10px, no text |
| **Alternate Mana** | a Druid's mana while Bear Form (rage) or Cat Form (energy) shows another power; Forever's own frames show none then | on, 8px, no text |
| **Health** | your health, in your class color | off, 14px, Percent text |

Each bar has its own settings, on four tabs under a preview with sample
values (every class sees every bar; Animated runs the fill):

| Tab | Settings |
|---|---|
| Bar | **Show Bar**, Status (whether it shows for this character now), **Width**, **Height**, **Match Width** (the width of what it's attached to in Edit Mode, followed when that changes; also in Edit Mode's window), Combo Points' **Spacing**, **Open Edit Mode**, **Reset to Defaults** (Show Bar and the size stay) |
| Look | **Border** (ModeUI or None) and **Border Color**; **Bar Texture** (Mode Gradient, Flat or SharedMedia), **Bar Color** (Power Type, Class Color or Custom; Combo Points: Custom or Class Color), **Bar Opacity**, **Bar Background** (Mode Slate by default) and **Background Opacity**; **Fill Direction**, **Smooth** and **Fill End Line** |
| Text | **Text** (None, Current, Percent, Current and Percent, Current / Max; Combo Points: None or Count), **Anchor** (Left, Center, Right), **Size**, **Offset X/Y**, **Text Color**; **Font**, **Outline**, **Text Shadow**, **Slug Text** |
| Visibility | **Show** (Always, In Combat, Out of Combat, In Combat or With a Target, Mouseover, Hidden), **Opacity**, **Faded Opacity** |

**Placement.** Each bar is an element of ModeUI's Edit Mode
(`ModeUIResourcePower`, `ModeUIResourceCombo`, `ModeUIResourceMana`,
`ModeUIResourceHealth`; positions `cooldownManagerResourcePower` and so
on). They start as a stack under Utility Cooldowns, each 4px under the last
and matching its width. A bar can attach to the screen, your frames, any
viewer or another resource bar, and the viewers and custom bars can attach
to a resource bar. A bar with nothing to show (Combo Points on a Warrior)
still holds its place, so the bars under it don't move.

**Look.** Every box is ModeUI's standard border (`Kit.ModeBorder`: a crisp
2px rim in `Kit.BORDER_COLOR` with rounded ends, on its own frame above the
fill), the fill and background rounded by its end masks, as on the unit
frames' cast bar.

**How values are handled.** Health and power can be secret: they go only
to the status bars, `AbbreviateNumbers` and the text setters, and percent
text comes from the game's 0-100 curve. Combo points light one box each
from `SetValue(count)` on boxes spanning `i - 1` to `i`. No value is
compared, so there is no Hide When Full.

**Saved settings.** `modules.cooldownManager.resources` with one table per
bar (`power`, `combo`, `mana`, `health`). Added without a version step: a
profile saved before them takes their defaults; bad data stops startup.

| File | Job |
|---|---|
| `ResourceInit.lua` | the bars, their Edit Mode targets, defaults, ranges, choices and validation |
| `Resources.lua` | frames, stand-ins, Match Width, the border and bar layout, combo boxes, the text's place, status |
| `ResourceUpdate.lua` | filling from the game, colors, texts, events, alpha, settings changes and reset |
| `ResourcePreview.lua`, `ResourceSettings.lua` | the preview and the page |

Shared: `Domain.Power.ManaType`, `ReadType`, `HasAlternateMana` and
`AlternateManaActive`; the Edit Mode size match and anchor size listener
(`PositionManager:SetSizeMatch`, `SetAnchorSizeListener`).

### In-game check

- **Navigation:** type `/mcdm`, then click **Power** under **Resource Bars**
  in the window's list.
- **Action:** if the switch at the top right of the page is off, turn it
  on. On the **Look** tab set **Bar Color** to **Class Color**, on the
  **Text** tab set **Text** to **Current / Max**. Click **Combo Points** in
  the list (on a Rogue or a Druid). Click **Edit Mode** in the window's
  header, drag the **Power** stand-in, then click **Exit** in the Edit Mode
  window.
- **Required state:** out of combat for the settings and Edit Mode; then
  spend and regain power, in and out of combat, with a target for combo
  points. On a Druid, shift into Bear Form and Cat Form.
- **Confirmation:** a Power bar in the ModeUI border sits under Utility
  Cooldowns at its width, fills smoothly in your class color and shows
  "current / max"; combo point boxes light one by one on your target; a
  Druid sees a thin mana bar in Bear and Cat Form only; the Power bar stays
  where you dropped it; no Lua errors in combat.
