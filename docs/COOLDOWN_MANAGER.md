# Cooldown Manager

November 13, 2026. A **standalone** module: it has its own window, opened
with **`/mcdm`**, and no page in ModeUI's settings window. Since November 15,
2026 it ships as its own addon, **ModeCDM** (`ModeCDM/Modules/CooldownManager/`;
see "Companion addons" in [ARCHITECTURE.md](ARCHITECTURE.md#companion-addons)):
it needs ModeUI, sits under it in the AddOn list, and keeps its settings in
ModeUI's profiles. Rebuilt in the Mode design language the same day (settings
version 5; [DESIGN_LANGUAGE.md](DESIGN_LANGUAGE.md#cooldown-icons)). Off by default (the
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

### The window (rework, November 24, 2026)

`/mcdm` opens and closes it; it's built the first time and opens on
**Home**. The owner chose this layout in the ModeCDM Workbench
(`design/cdm-workbench/`). Forever comes first: everything below was checked
against Blizzard's Forever source, and the Forever-only parts check that
their API exists (`Caps.lua`), so a client without one simply doesn't show
them. The rest of this document lists every setting; where a label changed,
the new one is used on the pages (Border Style, Border Color, Gray on
Cooldown, Show Effect Time, Swipe Edge, Finish Sparkle, Sharp Text, Ready
Glow, Starting Glow Look, Copy Look To…, Show, Text Color, Custom Color,
Stack Resources: Together / Apart, Point Style: Joined / Separate, Color
When Full, Tracked Spells, Tracked / Not Tracked Yet).

- **Header:** the title, **Tracked Spells** (Blizzard's Cooldown Settings,
  where you choose the tracked spells and their alerts; outside combat),
  **Test on Screen**, **Edit Mode** and the close button. Edit Mode hides
  the window and brings it back when it ends.
- **List** on the left, by kind: **Home** and **Bar Style**; **Cooldowns**
  (Essential, Utility and your Cooldown Bars) and **Buffs** (Tracked Buffs,
  Tracked Bars and your Buff Bars), each heading with a **+** that makes a
  bar of its kind and each of your bars with a **-** that deletes it after
  asking; **Player Bars** (Power, Combo Points, Alternate Mana, Health, Cast
  Bar and, on Forever, Swing Timer). Each row says **Off**, **Custom** (a look
  of its own) or how many spells show.
- **Home:** whether the Cooldown Manager shows and why not; the Bar Style
  with its presets (**Mode Default**, **Compact**, **Large & Clear**), **Edit
  Bar Style** and **Use Bar Style on Every Bar**; how many bars show, are off
  or have a look of their own; **Racial Abilities** (the bar they show on;
  it was on each bar's Bar tab); **Tracked Spells**.
- **Bar Style** (`BarStyle.lua`, `BarStyleOptions.lua`, `StylePage.lua`): the
  default look for bars. New bars and new profiles start with it; existing
  bars use it if you choose. Groups: **Size** (Large icons 38 x 30 for
  Essential, Utility and Cooldown Bars; Small 32 x 26 for Tracked Buffs and
  Buff Bars; Spacing -1, one shared shadow pixel), **Border** (Mode-Border in
  Gunmetal, 1px), **Background**, **Cooldown**, **Text** (amber cooldown
  numbers 14 on Large icons and 12 on Small, count 10, outlined; a taller or
  shorter icon scales them, so Ultra Emphasized Buffs keep 22 and 18),
  **Starting Glow Look** (gold Mode Glow procs) and **Bar Fill** (Tracked
  Bars). The resource bars, the Cast Bar and the Swing Timer take its border
  and font. Its preview is the Layout view of every bar.
- **A bar's page:** one scrolling page with a section index on its left:
  **Layout**, **Look**, **Text**, **Spells & Glows** and **Show** (the player
  bars: Layout, Look, Text, Show). Each group that can follow the Bar Style
  has a chip: **● Bar Style** (it follows; one line says what it gives) or
  **◆ Custom · Use Bar Style**. The controls the Bar Style sets show while
  the group is Custom; changing a value of a group that follows makes it
  Custom. Rarely changed controls sit under **More options (n)**. **Use Bar
  Style (n)** in the preview's corner puts every group back. **Copy Look To…**
  is under Look's More options; **Reset to Defaults** under Show's (back to
  the Bar Style, the size kept); **Delete Bar** under Layout's (it asks
  first). Blizzard's Edit Mode and Tracked Spells moved to the header.
- **The preview:** **Layout** (`Stage.lua`: every bar that shows, where it
  sits and to scale, read from the Edit Mode stand-ins, the bar being edited
  outlined; a click edits another bar) or **Bar** (this bar alone, to click
  and drag its spells and use its **+** slot). The Layout view needs the
  module on; otherwise the Bar view shows.
- **Spell list** (`SpellList.lua`, Spells & Glows): every spell on the bar as
  a row with its icon, name (a click opens its menu), **Show** and a switch
  per glow the bar has.
- **A spell's menu** also has **Own Bar** (a one-icon bar of its own, named
  after it, ready to place; not for racials) and its alerts: **Alerts in
  Tracked Spells** opens Blizzard's alert editor for a spell Blizzard tracks
  (Forever has it); a spell ModeUI tracks itself (by ID, items, trinkets,
  racials) picks a **Ready Sound** (No Sound, Blizzard Warning or your
  SharedMedia sounds) played when its cooldown ends (`Alerts.lua`).
- **Test on Screen** (`TestDisplay.lua`): sample icons on every bar in its
  real place (some cooling, one lit) and the Cast Bar's sample, on ModeUI's
  own frames; out of combat, until combat starts, the window closes or it's
  pressed again.
- **Show rules** (`Visibility.lua`): besides Show When, **Hide While
  Mounted**, **Hide in a Vehicle**, **Only in a Group**, **Only in an
  Instance** and **Dim Instead of Hide** (Faded Opacity instead of hidden),
  on every bar, the resource bars and the Cast Bar (which also has Show When
  now). Alpha only. Copy Look To leaves them alone.
- **Trinkets** (`Items.lua`): **Trinket 1** and **Trinket 2** in the **+**
  list (`t13`, `t14`) follow whatever trinket is in the slot; an empty slot
  stays, gray.
- **Racials** step aside when Blizzard's Cooldown Manager shows the same
  spell itself (Forever's spec-independent category, where its data has it),
  so nothing shows twice.
- **Swing Timer** (Forever only; `SwingInit.lua`, `SwingTimer.lua`,
  `SwingSettings.lua`): your auto-attack swings from Forever's `C_SwingTimer`
  and `PLAYER_SWING`. A lane for the main hand (or ranged), one for the off
  hand while it swings; the fill runs over each swing's duration; Rosewood
  while the target is out of auto-attack range (`PLAYER_SWING_RANGE_UPDATE`).
  Under the resource bars by default; Edit Mode and Test on Screen show a
  sample. A duration the client doesn't give as a plain number leaves the
  lane full.
- **`/mcdm check`** prints what this client offers (Caps.lua) for the
  Forever checks still to make in game.

### Every bar's settings

| Part | Look and behavior |
|---|---|
| Placement | Each bar has a stand-in in ModeUI's Edit Mode (`ModeUICooldownEssential`, ..., `ModeUICooldownCustom1`), one full line long, anchored to the screen or to any ModeUI element (another Cooldown Manager bar, a resource bar, your unit frames, ...). Anchored, it sits 1 px off its target's edge, pixel-perfect at any UI scale; the nudge buttons move it from there. **Match Width** and **Match Height** in the Edit Mode window size its line to what it's anchored on, separately, and follow that element when its size changes (the size is pushed on change, never polled). The first line never moves; more lines grow outside it. Essential starts at the bottom middle, 300 px up, Utility under it, Tracked Buffs on top, Tracked Bars to the right; custom bars in the middle of the screen (the default bars in their own places). Icons are wider than tall (Essential and Cooldown Bars 40 by 34; Utility, Tracked Buffs and Buff Bars 32 by 28), and each line leaves room for the icons' edges, so a matched width includes them. |
| Growth | **Centered Horizontal** (default), **Centered Vertical**, **Horizontal Right**, **Horizontal Left**, **Vertical Down** or **Vertical Up**, with **New Lines** going Down or Up for rows, Right or Left for columns (Tracked Buffs and Bars: Up). **Icons per Line** (12; bars 1; custom bars 8), Spacing (2 px, between the edges' shadows; down to -2: at -1 neighbours share one shadow pixel, at -2 their bands touch), Width and Height. Spells Blizzard hides (an inactive buff) leave no gap. |
| Icons | The Mode look (`docs/DESIGN_LANGUAGE.md`, "Cooldown icons"): the icon fills the item, cropped, over a **Mode-FG** face (its base) in Background Color (Mono panel, 100%), with the `frameThin` edge outside it (Mode-Empty by default, its flat band in the neutral, darker `emptyRim`; owner, November 20, 2026). **Border**: **Mode** or **None** (no edge, and its room given back); with Mode, **Border Style**, **Border Metal**, **Border Size** (the band, 1px or 2px; a 2px band reaches 3px past the icon, so the line grows) and, with Mode-Empty, **Border Color** (its flat band; `emptyRim` #343438 by default). Every icon edge is drawn in pieces (four 1:1 corners and four sides: an icon is shorter than the ring art, whose sliced corners shrank and looked square; owner, November 18, 2026). Tracked Bars' icons and bar boxes take the same edge, and a Border glow's rim follows the bar's style and band width. Blizzard's round mask and frame art come off; no mask goes on Blizzard's textures. |
| Cooldown | **Desaturate on Cooldown** (on): an icon goes gray while its spell is on a real cooldown (not the global cooldown) and takes its color back within a fifth of a second of the cooldown ending: the game sends no event then, so icons on a real cooldown are asked about again by one small ticker that runs only while one is cooling; off, icons keep full color. A flat swipe in Swipe Color at Swipe Opacity (70%). While a spell's effect is up Blizzard shows the effect's time in a full-color gold swipe; ModeUI shows the spell's own cooldown instead, gray, straight away. **Show Aura Time** brings Blizzard's gold swipe back. **Edge**, **Bling**, **Ready Flash**, **Out of Range Tint** (the Mode Rosewood tint on an out-of-range spell instead of Blizzard's red; off keeps full color) and, on buffs, **Debuff Border**. Blizzard's out-of-range shade, cut to its round mask, stays faded: repainted it showed as a solid red block, and Blizzard leaves it shown on an icon with no spell yet. |
| Bars | Tracked Bars (220 by 16): the icon, 4px wider than the bar is tall, beside the bar's own box, both in the `frameThin` edge 2px apart; the fill in Bar Texture (Mode-FG: its base and white lift) in **Bar Color**: **Class Color** (default) or **Custom** (Ivory), over Bar Background (Mode-BG on Slate at 85%); Icon Side; **Spark** (the Comet, on by default). |
| Text | Icons: **Cooldown** and **Count**; bars: **Name**, **Duration**, **Count**. The Text tab sets the bar's look: each text's Show This Text, Anchor, Size, Offsets and Color; Font, Outline, Text Shadow, Slug Text. A spell can have its own look per text from its menu (below). |
| Glows | Every glow starts off on every spell; a spell's menu switches one on. Cooldown icons: **Proc Glow** (the game lights the spell up; Blizzard's own animation stays hidden while the module is on), **Active Glow** (while the spell's effect is up), **Off Cooldown Glow** (**Flash** for Glow Time when a cooldown ends, or **While Ready**). One shows at a time: proc, active, off cooldown. Buff icons: **Buff Glow** (while the buff is up). Tracked Bars have none. Each glow has its own look per spell: a Style (**Mode Glow**, **Border**, **Pixel**: marching lines with Lines and Thickness, **Blizzard**: the game's proc loop, **GCD**: the game's rotation-assist art), a Color and, for Mode Glow and Border, Pulse. **Border** is the Mode rim swap: a Mode Empty rim in the glow color over the icon's edge, so the icon keeps its size. The Glows tab sets the **Glow Defaults**, the look a glow starts with when switched on (Proc: Border, Celadon; Active: Border, Ivory; Off Cooldown: Mode Glow, Ivory; Buff: Mode Glow, Celadon). Text is the Mode typeface (Urbanist) Bold: cooldown numbers 13 (10 on the small bars) in the cooldown color, counts 11 (10) in Text bright, bar texts 10. |
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
  it to another moves it. A spell your Blizzard CDM setup tracks while its
  viewer has no frame for it (Blizzard's viewer hidden) shows here in full
  color for information only, and can be added once the viewer shows.
- **Not in Blizzard CDM**: every other spell the game has for your class and
  spec in those categories (`C_CooldownViewer.GetCooldownViewerCategorySet`
  with unlearned spells), grayed; ones you haven't learned say so. Their
  tooltip says **NOT TRACKED IN BLIZZARD CDM - ADD IT IN /CDM** (your racials
  don't, since ModeUI tracks them itself). On a Cooldown Bar clicking one
  adds it as a custom spell (below). A buff can only show once Blizzard's
  Cooldown Manager tracks it, so on a Buff Bar these only point you there.
- **Items in Your Bags** (Cooldown Bars): what you carry with a Use: effect,
  such as potions, healthstones and food.

The bar's Bar tab has its **Name**, how many spells it holds and **Delete
Bar** (its spells go back to their viewers). A tracked spell you stop
tracking in Blizzard's window stays in the bar, faded and gray in the
preview, and comes back when you track it again. A new bar is numbered
among your own bars (Cooldown Bar 1, Buff Bar 1, ...); the default bars
below have names of their own.

### Default bars

Five custom bars the owner designed (November 18, 2026; `Presets.lua`).
A new profile starts with them; version 9 adds them to an older profile
after its own bars, while there's room (fifteen custom bars at most). They
start empty: add spells with their **+** slot like any custom bar. Each is an
ordinary custom bar (rename it, change it or delete it); a deleted one stays
deleted. Each keeps its own defaults (**Reset to Defaults**, the look a
spell's glow starts from) and its own default place in Edit Mode, its
`point` on the target's `relativePoint` with no gap added:

| Bar | Kind | Icons | Per line | Growth, New Lines | Spacing | Default place |
|---|---|---|---|---|---|---|
| Defensive Cooldowns | Cooldown | 30 by 24 | 3 | Horizontal Left, Up | 2 | bottom right on the ModeUI Player Frame's top right, 12 down |
| Emphasized Buffs | Buff | 46 by 40 | 4 | Centered Horizontal, Up | 2 | bottom on Tracked Buffs' top, 1 up |
| Left Buffs | Buff | 30 by 24 | 6 | Centered Vertical, Left | 1 | screen center, 150 left |
| Right Buffs | Buff | 30 by 24 | 6 | Centered Vertical, Right | 1 | screen center, 150 right |
| Ultra Emphasized Buffs | Buff | 54 by 48 | 2 | Centered Horizontal, Up | 2 | screen center, 110 right and 115 up |

Everything else is its kind's default; Ultra Emphasized Buffs also has
Cooldown text 22 and Count text 18. Saved like any custom bar, with
`preset = "defensives"` (`"emphasized"`, `"leftBuffs"`, `"rightBuffs"`,
`"ultra"`) in its `customBars` entry: one of those five, of its kind, once
per profile.

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
show (`C_SpellBook.IsSpellKnown`, and in your spellbook: `FindSpellBookSlotForSpell`; one per name, so an orc sees one Blood Fury), worked out again whenever your spells
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

### What you track in Blizzard's Cooldown Manager (November 20, 2026)

Blizzard's viewers make their icon frames only while they show, so a viewer
that's hidden (its Edit Mode Visibility, In Combat out of combat, or not
shown since you logged in) has none. The settings read what you track from
Blizzard's Cooldown Settings instead (`Shared/Domain/CooldownLayout.lua`,
`Tracking.lua`; owner, November 20, 2026):

- The preview fills **Essential Cooldowns**, **Utility Cooldowns**,
  **Tracked Buffs** and **Tracked Bars** with every spell your Blizzard CDM
  setup puts in them, in your order and in full color, even while Blizzard's
  viewer has no frames: every buff tracked there is on Tracked Buffs (unless
  you moved it to a Buff Bar). The caption says how many are off screen
  while Blizzard's viewer is hidden. Sample icons show only when nothing is
  tracked there.
- A spell counts as tracked when your setup has it in one of the four
  viewers, learned or not; anything hidden by default or set to Not
  Displayed doesn't.
- A spell or buff on a bar that Blizzard's Cooldown Manager doesn't track
  (a cooldown ID; custom spells and items don't need it) says
  **NOT TRACKED IN BLIZZARD CDM - ADD IT IN /CDM** in its tooltip in the
  preview and at the top of its spell menu.

On screen the icons are still Blizzard's own frames: a viewer hidden in
Blizzard's Edit Mode shows nothing until it's on. ModeUI never changes
Blizzard's Edit Mode settings.

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
your choices. Version 3 gave every bar the ModeUI border (a Rounded border, the old default, becomes it, and the old #101010 color its color; Square and None stay). Version 4 moved the default sizes to 8 px wider than tall (a size you chose stays), set Utility's default place against Essential (the 1px gap is built in), and made glows per spell: each bar's glow styles become its Glow Defaults (None becomes Mode Glow), and a spell's glow switch keeps the look as its own. Custom bars' spells also take items (`i<ID>`, Cooldown Bars only). Added later without a version step (a profile saved before starts empty): `extras = { essential = {...}, utility = {...} }`, the spells those viewers took (cooldown IDs, `s<ID>`, `i<ID>`), `order = { essential = { "102", "101", ... } }`, a viewer's spell order once you move one, `racials` (the bar racials show on: `"utility"` by default, `"essential"`, a custom Cooldown Bar's ID or `"none"`), and a spell's own text looks, `spells[key].text = { count = { show, size, anchor, x, y, color, font, fontMedia, outline = "none" | "outline" | "thick", shadow } }`. Version 5 (the Mode design language) moves values still at a version 4 default to the new ones and keeps anything you chose: Rounded and Square borders become the Mode edge (Border Size and Border Color retire), the old sizes (42 by 34, 36 by 28, bars 220 by 22) become the new ones, the #040404 background at 75% Mono panel at 100%, Expressway Geist with no outline, gold procs Celadon (Blizzard becomes Border), green glows Celadon or Ivory, the cyan ready glow Ivory (Pixel becomes Mode Glow), text sizes and colors, Mode Gradient on Mode BG with the spark for bars, and the cyan bar color Class Color (a color you picked stays, as Custom). A spell's own glow keeps its style and takes the new color if it still had the old default. Resource bars: Mode Gradient on Mode BG at 60%, Geist, the hostile red for combo points, and Border Color retires. Versions 6 and 7 are under Resource Bars, version 8 under Cast Bar. Version 12 (owner, November 24, 2026): the Bar Style (`barStyle`, and a `follow` table on every bar, resource bar, the Cast Bar and the Swing Timer). A new profile follows it everywhere (a default bar keeps its own size). An existing profile's bars take its border (a border set to None stays off) and text; every other group follows only where the bar already matches it, so nothing else changes on screen. Layout profiles take it with their own sizes. Added without a version step: `alerts` on a bar (Ready Sounds), the show rules (`hideMounted`, `hideVehicle`, `onlyInGroup`, `onlyInInstance`, `dim`), the Cast Bar's `visibility` and `fadeOpacity`, `db.swing`, and the trinket entries `t13`/`t14`. Version 10 (owner, November 20, 2026): the Cast Bar filled in your class color by default (Bar Mode Color, Bar Color Class Color); a Bar Mode still at Dark, the old default, takes Color. Version 9 (owner, November 18, 2026) adds the five default bars a profile doesn't hold, after its own bars, with new IDs from `nextCustom`, while there's room (up to 15 custom bars); its own bars are never touched. A new profile starts at version 9 with them as `custom1` to `custom5` (`nextCustom` 6). Bad data stops startup; nothing is reset.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration (standalone), the viewers and custom bar kinds, defaults, ranges, choices |
| `Presets.lua` | the five default bars: their defaults, places, validation and the version 9 step |
| `Migrations.lua` | `Initialize(db)`: version 1 to 9, validation |
| `Driver.lua` | lifecycle, `/mcdm`, events, settings changes, per-spell switches, copy and reset, status |
| `Custom.lua` | the bar list, custom bars, what Essential and Utility took, and which spell shows where |
| `Spells.lua`, `Items.lua`, `Racials.lua` | custom spells, items and racials on ModeUI's own icons |
| `Blizzard.lua` | finding and hooking Blizzard's viewers and items |
| `Tracking.lua` | what you track in Blizzard's Cooldown Manager for the preview and the + slot's list; the NOT TRACKED warning |
| `Layout.lua` | Growth geometry, stand-ins and holders, placing the icons |
| `Skin.lua`, `Bars.lua`, `Text.lua` | icon art (Mode-FG face, `frameThin` edge), swipe, gray and range tint; Tracked Bars; texts and a spell's own text looks |
| `Glow.lua` | the four glows; a spell's alpha |
| `GlowPopout.lua`, `TextPopout.lua` | a glow's and a text's popout beside the spell menu |
| `Visibility.lua` | Show, Opacity, Mouseover |
| `SpellMenu.lua`, `Picker.lua`, `Preview.lua`, `PreviewDrag.lua` | the preview, its spell menu, the + slot's list, and dragging spells to move them |
| `Settings.lua`, `SettingsTabs.lua` | the settings page |
| `Window.lua` | the module's own window |
| `Layouts.lua` | ModeCDM's parts of the Mode-DPS/TANK and Healer layouts (sizes and places; the look is the Bar Style) |
| `Caps.lua` | what the client offers (`M.caps`), `/mcdm check` |
| `BarStyle.lua`, `BarStyleOptions.lua`, `StylePage.lua` | the Bar Style: defaults, groups, following, version 12; changing it, presets; its page |
| `Parts.lua` | what Initialize checks after the bars (player bars, Bar Style, alerts) |
| `SettingsLook.lua`, `SpellList.lua`, `SettingsHelpers.lua` | Look and Text; the spell list; the page toolkit (section index, chips, More options) |
| `Stage.lua` | the preview's Layout view and corner |
| `HomePage.lua`, `WindowList.lua` | Home; the window's list |
| `TestDisplay.lua`, `Alerts.lua` | Test on Screen; Ready Sound, Own Bar |
| `SwingInit.lua`, `SwingTimer.lua`, `SwingSettings.lua` | the Swing Timer (Forever only) |

Shared pieces it uses or added: `Shared/Domain/Cooldowns.lua`,
`Shared/Domain/CooldownLayout.lua` (your Blizzard CDM setup, read only),
`Shared/Domain/Items.lua`, `Shared/Kit/Slot.lua` (icon cropping and glows; the old slot art is gone), `Style.Edge` and `Edge:Regions()` (a glow's rim fades with a secret buff state), `Kit.OutlineFlags` (a thick outline), `Shared/Kit/Glows.lua`
(Pixel, Blizzard and GCD glows on one shared ticker), `W.Confirm`
(`Shared/Settings/Confirm.lua`), size matching and pixel gaps in the
PositionManager (`gapPixels`, `SetSizeMatch`, `AllowTarget`, `RemoveTarget`), `addon:RegisterSettingsWindow` (Edit Mode returns to
a standalone module's window), `PositionManager:SetLabel`, and the
`standalone` module field (no sidebar entry or search results in ModeUI's
window; Edit Mode's Open Module Settings calls `module:OpenSettings`).

## In-game check: the rework (November 24, 2026)

Before the first look: close WoW; a copy of your settings from before
version 12 is at `Documents\GitHub\ModeUI-backups\SavedVariables-2026-11-24-before-cdm-v12-ModeUI.lua`.
ModeCDM gains new files, so start the game fully (not only `/reload`).

1. The Bar Style on your bars
   - **Navigation:** log in on your usual profile; type `/mcdm`.
   - **Action:** look at the bars on screen; click **Bar Style** in the list.
   - **Required state:** ModeUI and ModeCDM enabled, the Cooldown Manager on.
   - **Confirmation:** every bar keeps its size and place; borders are
     Mode-Border in Gunmetal and cooldown numbers amber and outlined (Ultra
     Emphasized Buffs still large); a bar whose border you'd set to None
     still has none; the Bar Style page shows every bar in its preview; no
     Lua errors.
2. Home, the list and a bar's page
   - **Navigation:** type `/mcdm` (it opens on Home); click **Essential
     Cooldowns** under **Cooldowns**.
   - **Action:** click each button in the section index (Layout, Look, Text,
     Spells & Glows, Show); on **Look**, click the **● Bar Style** chip on
     Border, change **Border Size**, then click **Use Bar Style (1)** at the
     top right of the preview; click **More options** under Cooldown.
   - **Required state:** out of combat.
   - **Confirmation:** Home lists the presets and Racial Abilities; the page
     scrolls to each section; the chip turns to **◆ Custom** and Border's
     controls appear, then Use Bar Style puts it back and they hide; More
     options shows Show Effect Time, Swipe Edge, Finish Sparkle, Ready Flash.
3. The Layout view, the Bar view and Test on Screen
   - **Navigation:** type `/mcdm`, click **Utility Cooldowns**.
   - **Action:** in the preview, click Essential's icons in the Layout view;
     click **Bar**, click a spell, then **Own Bar**; press **Test on Screen**
     in the header, then enter combat.
   - **Required state:** out of combat for the clicks; spells tracked in
     Blizzard's Cooldown Manager.
   - **Confirmation:** the Layout view shows every bar as on screen with the
     edited one outlined, and clicking Essential edits it; the Bar view shows
     Utility alone; Own Bar makes a one-icon bar named after the spell; Test
     on Screen draws samples on the real bars and they vanish when combat
     starts.
4. Show rules
   - **Navigation:** type `/mcdm`, click **Essential Cooldowns**, then **Show**
     in the index.
   - **Action:** tick **Hide While Mounted**, mount; tick **Dim Instead of
     Hide**, set **Faded Opacity** to 30.
   - **Required state:** a mount, outdoors.
   - **Confirmation:** Essential hides while mounted, then shows faint
     instead; back on the ground it shows in full.
5. Trinkets and alerts
   - **Navigation:** type `/mcdm`, click a Cooldown Bar, then **Bar** in the
     preview and its **+** slot.
   - **Action:** click **Trinket 1** under Items in Your Bags; click it in the
     preview and pick a **Ready Sound**; use the trinket and wait for its
     cooldown; swap trinkets.
   - **Required state:** an equipped trinket with a Use: effect.
   - **Confirmation:** the slot's trinket shows with its cooldown; the sound
     plays when the cooldown ends; after the swap the icon shows the new
     trinket; a spell Blizzard tracks offers **Alerts in Tracked Spells**
     instead, which opens Blizzard's window.
6. Swing Timer (Forever)
   - **Navigation:** type `/mcdm check`; then `/mcdm`, **Swing Timer** under
     Player Bars.
   - **Action:** auto-attack a target dummy with one weapon, then with two,
     then step out of melee range; type `/mcdm check` again.
   - **Required state:** a melee class (a Hunter for ranged), a target.
   - **Confirmation:** the check reports the swing timer API; a lane fills
     once per swing, a second lane appears for the off hand, the fill turns
     Rosewood out of range; the second check says the last swing duration was
     a plain number (if it says secret, tell Claude: the lane stays full then).
     Copy the whole `/mcdm check` output to Claude: it settles alerts, racial
     and trinket categories and keybind support on Forever.

## In-game check (November 13, 2026)

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
     Essential Cooldowns, click **Match Width** in Edit Mode's element panel
     and then Essential's stand-in, click a nudge button; then
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
7. ModeCDM and the Mode look (November 15, 2026)
   - **Navigation:** at the character select screen, click **AddOns**; in
     game, type `/mcdm`.
   - **Action:** in the AddOn list, find ModeCDM; enter the world and turn
     the Cooldown Manager on with the switch at the top right of the
     `/mcdm` window's page; cast a spell from Essential Cooldowns; click a
     spell in the preview and switch **Proc Glow** on; click **Tracked
     Bars** in the list.
   - **Required state:** ModeUI and ModeCDM both enabled (a full client
     restart after first adding ModeCDM), the game's Cooldown Manager option
     on, spells tracked in Blizzard's Cooldown Manager.
   - **Confirmation:** ModeCDM is listed indented under ModeUI with the
     cooldowns icon; Essential icons are 40 by 34 with a thin lit gunmetal
     rim and its shadow outside each icon, 2px apart between the shadows;
     Utility icons are 32 by 28; cooldown numbers in Geist Bold amber; a
     proc swaps the rim to Celadon without the icon changing size; an
     out-of-range spell turns Rosewood; tracked bars are thin Mode Gradient
     bars in your class color with the comet spark; the Power bar under
     Utility lines up with Utility's edges. Your earlier settings are kept.
8. What you track in Blizzard's Cooldown Manager (November 20, 2026)
   - **Navigation:** press Escape, click **Edit Mode** and select Blizzard's
     Tracked Buffs viewer; later type `/mcdm` and click **Tracked Buffs** in
     the list.
   - **Action:** set the viewer's **Visibility** to its hidden choice, close
     Edit Mode and reload; in `/mcdm` on **Tracked Buffs**, point at an icon
     in the preview; click **Emphasized Buffs** in the list, click the **+**
     slot in the preview and point at an icon under **Not in Blizzard CDM**;
     then click a spell on a bar whose buff you set to Not Displayed in
     Blizzard's window (**Open CDM**). Afterwards set the viewer's
     Visibility back.
   - **Required state:** out of combat, buffs tracked in Blizzard's Cooldown
     Manager, the module on.
   - **Confirmation:** the Tracked Buffs preview shows every buff you track
     there, in color and in your order (no sample icons), with "off screen
     while Blizzard's viewer is hidden" in the caption; under **Tracked in
     Blizzard CDM** those buffs show in color and clicking them does
     nothing; a grayed icon's tooltip reads NOT TRACKED IN BLIZZARD CDM -
     ADD IT IN /CDM, and so does the top of that spell's menu. No Lua
     errors, and Blizzard's Cooldown Manager keeps working in combat
     afterwards.

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
| **Power** | the power your character shows now: mana, rage or energy, in its own color | on, 16px, Current text |
| **Combo Points** | one point per point you can hold, lit for each point on your target (Rogues; Druids in Cat Form) | on, 10px, Grouped, Count |
| **Alternate Mana** | a Druid's mana while Bear Form (rage) or Cat Form (energy) shows another power; Forever's own frames show none then | on, 8px, Show Text off |
| **Health** | your health, in your class color | off, 14px, Percent text |

Since version 6 (owner, November 17, 2026) every bar starts in Mode-Round
with Gunmetal and in Dark mode, and a bar in its own border is drawn no
shorter than that border's floor (10px for Mode-Round, 6px for the cut
styles; `Style.EdgeMinHeight`), so Alternate Mana's 8px shows at 10px in
Mode-Round. Version 7 (owner, in game, November 18, 2026) sets Power 16,
Combo Points 10 and Alternate Mana 8, and centers every text.

Each bar has its own settings, on four tabs under a preview with sample
values (every class sees every bar; Animated runs the fill):

| Tab | Settings |
|---|---|
| Bar | **Show Bar**, Status (whether it shows for this character now); Power, Combo Points and Alternate Mana: **Resources** › **Layout** (Separate Resources or Group Resources, shared by the three); **Width** (not while grouped), **Height** (Match Width lives only in Edit Mode's element panel since November 15, 2026: click it, then the element to take the width of); Combo Points: **Layout** (Grouped or Separated), **Spacing** (Separated), **Divider Width** and **Divider Color** (Grouped); Power and Alternate Mana: **Tick Marks** (**Show Tick Marks**; **Tick 1** to **Tick 5**, each a value typed in, 0 for none, with **Shows On**: Any Power, Energy, Rage, Mana or Focus, and **Remove** from Tick 2 on; **+ Add Tick Mark**; **Tick Width**, **Tick Color**); **Open Edit Mode**, **Reset to Defaults** (Show Bar and the size stay) |
| Look | **Border** (Mode or None), **Border Style**, **Border Size** (1px or 2px) and **Rim Color** (Default Metal, Silver, Steel, Gunmetal, Bar Color, Custom, with **Custom Rim Color**; on Power for a Grouped block); **Bar Mode** (Color or Dark), **Bar Texture** (Mode-FG by default, Flat or SharedMedia), **Bar Color** (Power Type, Class Color or Custom; Combo Points: Custom or Class Color), **Dark Text Color** (Power Type or Bar Color, Class Color, Custom), **Bar Opacity**, **Bar Background** (Mode BG by default) and **Background Opacity**; Combo Points: **Full Combo Points Color** (every point takes it once all are lit); **Fill Direction**, **Smooth** and **Fill End Line** |
| Text | **Show Text**; **Text** (Current, Percent, Current and Percent, Current / Max; Combo Points show their count), **Size**, **Offset X/Y**, **Text Color** (Color mode); **Font**, **Outline**, **Text Shadow**, **Slug Text**. The text sits in the middle of its bar (in a Grouped block, of its own strip). |
| Visibility | **Show** (Always, In Combat, Out of Combat, In Combat or With a Target, Mouseover, Hidden), **Opacity**, **Faded Opacity** |

**Group Resources** (`ResourceGroup.lua`). Power, Combo Points and Alternate
Mana share one border on Power's stand-in, top down, a 1px black line between
them, like the unit frames' health and power. Power's Border, Border Style,
Rim Color, Width and Match Width are the block's; each bar keeps its height,
colors, texts and visibility. A bar that's off or has nothing to show leaves
the block, which closes up (a Druid's block changes with each form, in combat
too). Only the block has a height floor (Power grows to it). Combo Points'
and Alternate Mana's stand-ins fold to 1px under the block and leave Edit
Mode, so what hangs from them stays close. Health never joins; with Power off
the bars stand apart again.

**Tick Marks** (`ResourceMarks.lua`). Each bar's own: Power's ticks never
show on another bar. With **Show Tick Marks** on, a line at `value / max` of
the bar, shown only while its power type is shown and the value is under the
maximum.
Forever documents the player's maximum power as readable; if it ever comes
secret, the last readable maximum for that power type is kept (none: hidden).

**Whole pixels** (`ResourceSnap.lua`). At a UI scale that isn't pixel
perfect (Blizzard's default) a stand-in sits between physical pixels and a
bar's 1px border would land on half pixels: faint or gone, with specks at the
corners (owner, in game, November 18, 2026). Each bar's frame hangs from its
stand-in nudged by under a pixel onto whole pixels, and a check every 0.2
seconds places shown bars again when a stand-in moves.

**Placement.** Each bar is an element of ModeUI's Edit Mode
(`ModeUIResourcePower`, `ModeUIResourceCombo`, `ModeUIResourceMana`,
`ModeUIResourceHealth`; positions `cooldownManagerResourcePower` and so
on). They start as a stack under Utility Cooldowns, each 4px under the last
and matching its width. A bar can attach to the screen, your frames, any
viewer or another resource bar, and the viewers and custom bars can attach
to a resource bar. A bar with nothing to show (Combo Points on a Warrior)
still holds its place, so the bars under it don't move.

**Look.** Every box is a status bar in the `frameThin` edge outside it (no masks; drawn in pieces, so thin bars keep whole corners and 1px sides: DESIGN_LANGUAGE.md, "Pieces"): Mode-FG (base and lift) over Mode-BG at 85%, so the world shows through, with Bold text. A bar's stand-in holds its edges, so a bar matched to the cooldowns lines up with their edges, and combo point boxes are Spacing apart between their shadows. Border: Mode or None.

**How values are handled.** Health and power can be secret: they go only
to the status bars, `AbbreviateNumbers` and the text setters, and percent
text comes from the game's 0-100 curve. Combo points light one box each
from `SetValue(count)` on boxes spanning `i - 1` to `i`; Full Color is a
second bar per point spanning `max - 1` to `max`, lit by the same count. No
value is compared, so there is no Hide When Full.

**Saved settings.** `modules.cooldownManager.resources` with one table per
bar (`power`, `combo`, `mana`, `health`), and `resourceLayout` (`"separate"`
or `"grouped"`). Added without a version step: a profile saved before them
takes their defaults; bad data stops startup. Version 6 adds `barMode`,
`darkText`, `darkTextColor`, `rimColor`, `rimCustom`; on Power and Alternate
Mana `marks` (three `{ value, power }` slots), `markColor`, `markWidth`; on
Combo Points `layout`, `dividerWidth`, `dividerColor`, `fullShow`,
`fullColor`. It moves values still at version 5's defaults: Mode-Blizz to
Mode-Round, Default to Gunmetal, heights 14/10/8 to 10/6/6, the combo count
from None to Count. Separate Resources stays, so no bar moves. Version 7
adds `textShow` and, on Power and Alternate Mana, `marksShow`; `marks` is a
list of one to five; `textAnchor` and the None text format go. It moves
heights still at version 6's defaults (10/6/6) to 16/10/8, turns a None text
into Show Text off, keeps the ticks in use (else the first) and turns Show
Tick Marks on when one was in use.

| File | Job |
|---|---|
| `ResourceInit.lua` | the bars, their Edit Mode targets, defaults, ranges, choices and validation |
| `Resources.lua` | frames, stand-ins, Match Width, the border and bar layout, combo boxes, the text's place, status |
| `ResourceSnap.lua` | whole pixels: each bar's frame nudged onto the pixel grid |
| `ResourceGroup.lua` | Group Resources: the block on Power's stand-in |
| `ResourceMarks.lua` | Tick Marks |
| `ResourceUpdate.lua` | filling from the game, colors (Dark mode, Rim Color), texts, events, alpha, settings changes and reset |
| `ResourcePreview.lua`, `ResourceSettings.lua`, `ResourceSettingsLook.lua` | the preview and the page (Bar; Look, Text and Visibility) |

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
  header, drag the **Power** stand-in, then click **Done** in the Edit Mode
  window.
- **Required state:** out of combat for the settings and Edit Mode; then
  spend and regain power, in and out of combat, with a target for combo
  points. On a Druid, shift into Bear Form and Cat Form.
- **Confirmation:** a Power bar in the Mode edge sits under Utility
  Cooldowns at its width, fills smoothly in your class color and shows
  "current / max"; combo point boxes light one by one on your target; a
  Druid sees a thin mana bar in Bear and Cat Form only; the Power bar stays
  where you dropped it; no Lua errors in combat.

### In-game check: version 6 (November 17, 2026)

- **Navigation:** type `/mcdm`, then click **Power** under **Resource Bars**.
- **Action:** look at the bars first, untouched. Then on Power's **Bar** tab
  set **Tick 1** to 40 and **Shows On** to Energy; on the **Look** tab try
  **Border Style** Mode-Blizz and back to Mode-Round, and **Rim Color**
  Silver, Bar Color, then Gunmetal. Click **Combo Points**: on its **Bar** tab
  set **Layout** to Separated, then Grouped, and change **Divider Color**.
  Back on **Power**, set **Resources** › **Layout** to **Group Resources**,
  then shift forms; set it back to **Separate Resources**.
- **Required state:** a Druid (Cat and Bear Form, in and out of combat,
  with a target) and a Rogue; the Cooldown Manager switched on.
- **Confirmation:** every bar is dark with its number in the power's color
  and a fill end line; Mode-Round corners look whole on every bar (the 6px
  bars draw at 10px); combo points sit in one Gunmetal border with lines
  between them and their count on the left; the 40 Energy line stays put in
  Cat Form and is gone in Bear Form; Group Resources shows one border that
  closes up as combo points and mana come and go; no Lua errors.

### In-game check: version 7 (November 18, 2026)

- **Navigation:** type `/mcdm`, then click **Power** under **Resource Bars**.
- **Action:** look at the bars first, untouched, then set **Height** to 10 and
  back to 16. On the **Bar** tab turn on **Show Tick Marks**, type 40 in
  **Tick 1** and press Enter, set **Shows On** to Energy, click
  **+ Add Tick Mark**, type 80 in **Tick 2**, then click its **Remove**.
  Click **Combo Points** in the list. Then **Power** again, **Text** tab:
  turn **Show Text** off and on. Try **Resources** › **Layout** Group
  Resources and back.
- **Required state:** a Rogue with a target; the Cooldown Manager switched
  on; Blizzard's default UI scale.
- **Confirmation:** every bar shows its whole Gunmetal border (top, bottom,
  both ends, round corners) at 16, 10 and 8 (8 draws at 10) and at Height 10,
  Separate Resources (each bar its own border) as well as Group Resources;
  Power 16, Combo Points 10; the 40 line shows on Power only, never on
  Combo Points' bar or preview; the text sits in the middle of each bar;
  no Lua errors.

## Cast Bar

November 18, 2026 (owner). The player's cast bar on its own, in the same
`/mcdm` window: **Cast Bar** under Resource Bars in the list. Only the
player's: Target, Focus and nameplate cast bars stay where they are. While
it is on (the Cooldown Manager on and **Show Bar**), Unit Frames' Player
cast bar steps aside and Blizzard's Player cast bar stays faded; switch it
off and both behave as before. Checked against the mock client only
(`tests/cast_bar.lua`); **native acceptance is pending**.

It takes the resource bars' look as tuned in game: the `frameThin` edge in
Mode-Round and Gunmetal, drawn in pieces and on whole pixels, Rim Color, and
Dark mode (the fill in darkFill, the Comet's head alone, the text in your
class color). Defaults: above Essential Cooldowns, Match Width on, 18px, the
icon hidden, Spell Name on the left and Timer on the right, Show Interrupted
on. Buff Icons, which sat above Essential, hang above the cast bar.

| Tab | Settings |
|---|---|
| Bar | **Show Bar**, Status; **Width**, **Height**; **Icon** (Hidden, Left, Right; the spell icon, a square of the bar's height in its own border) and **Icon Gap**; **Show Interrupted**; **Open Edit Mode**, **Reset to Defaults** (Show Bar and the size stay) |
| Look | **Border** (Mode or None), **Border Style**, **Border Size** (1px or 2px), **Rim Color** (Default Metal, Silver, Steel, Gunmetal, Bar Color, Custom) and **Custom Rim Color**; **Bar Mode** (Color, the default, or Dark), **Bar Texture**, **Bar Color** (Class Color, the default, or Custom, with **Custom Bar Color**), **Not Interruptible**, **Interrupted**; **Dark Text Color** (Class Color, Bar Color, Custom) and **Custom Text Color**; **Bar Background**, **Background Opacity**; **Spark** |
| Text | **Spell Name** and **Timer**, each: **Show**, **Anchor** (Left, Center, Right), **Offset X/Y**; **Size**, **Text Color** (Color mode); **Font**, **Outline**, **Text Shadow**, **Slug Text** |
| Visibility | **Opacity**. It shows while you cast, and with a sample in Edit Mode. |

**Casts.** `Domain.Cast.Read("player")` each cast event; the cast's times go
only to `SetMinMaxValues` (the bar is given the time each frame), its name to
`SetText`, its icon to `SetTexture`, Not Interruptible to
`SetVertexColorFromBoolean`. A channel drains: the fill from the right in the
background color over the cast color. **Show Interrupted** holds an
interrupted cast full in the Interrupted color with "Interrupted" for 1s,
then fades over 0.3s (Blizzard's HoldFadeOutAnim; `Kit.CastInterrupted`, as on
nameplates).

**Placement.** An Edit Mode element (`ModeUICastBar`, position
`cooldownManagerCastBar`) like the others: it attaches to any ModeUI element
and they to it; Match Width in the Edit Mode window.

**Saved settings.** `modules.cooldownManager.castBar`, added without a
version step (a profile from before it takes the defaults; bad data stops
startup). Version 8 moves a saved Buff Icons place still at its old default
(above Essential, no offset) above the cast bar, once.

| File | Job |
|---|---|
| `CastInit.lua` | defaults, ranges, choices, Rim Color, validation; the Edit Mode target and default place |
| `CastBar.lua` | the frames, layout, paint, casts and Show Interrupted, events, the claim and Blizzard's fade, the stand-in |
| `CastPreview.lua`, `CastSettings.lua` | the preview and the page (`SettingsHelpers.lua`: the row helpers it shares with the resource page) |

Shared: `Kit.PlayerCast`, `Kit.NativeFade` (`Shared/Kit/Native.lua`),
`Kit.CastInterrupted`, `Kit.CAST_HOLD` (`Shared/Kit/Cast.lua`),
`Comet:SetTrail` (`Shared/Style/Bar.lua`), `Style.Edge` pieces.

### In-game check: Cast Bar (November 18, 2026)

- **Navigation:** type `/mcdm`, then click **Cast Bar** under **Resource
  Bars** in the window's list.
- **Action:** cast a spell with a cast time, then a channel; cast one and
  move to interrupt it. Then set **Icon** to **Left** (Bar tab), **Bar Mode**
  to **Color** and pick a **Bar Color** (Look tab), set **Spell Name**
  **Anchor** to **Center** (Text tab). Click **Edit Mode** in the window's
  header and look above Essential, then **Done**. Turn **Show Bar** off and
  cast again; turn it back on.
- **Required state:** the Cooldown Manager and Unit Frames switched on, out
  of combat for the settings, then casting in and out of combat.
- **Confirmation:** one cast bar above Essential, matching its width, with
  its whole Gunmetal border; dark with only the Comet's head, the spell name
  left and seconds right in your class color; an interrupt holds red with
  "Interrupted" for a second, then fades; no Unit Frames Player cast bar and
  no Blizzard cast bar while it's on; with Show Bar off, Unit Frames' Player
  cast bar shows the cast again; Buff Icons sit above the cast bar; no Lua
  errors.

## Healer layout (November 19, 2026)

ModeCDM's part of ModeUI's Mode-Healer layout (`Layouts.lua`,
`Contribute("healer", ...)`; new profiles only), the same bars in the same
look as Mode-DPS/TANK but for these:

- **Essential** 42 x 34 (4px bigger), seven to a line, two lines when full
  (14; there is no line limit), at the same place.
- **Utility** 70 under Essential's first line (33 under the second).
- **Resources apart** (Separate Resources): Power off (the Player frame shows
  your mana) and Alternate Mana off. **Combo Points** a 6px strip in
  Mode-Border in its own metal, as wide as
  Essential, 1px on it; only a Druid in Cat Form has them as a healer.
- **Cast Bar** 20 tall (16 until November 20, 2026), as wide as Essential, at a fixed place 8 over
  Essential (1px over the Combo Points strip's place), so it never moves
  when combo points come and go. Tracked Buffs and Emphasized Buffs stack on
  it as before.
- **Defensive Cooldowns** hidden (Show off, not deleted). A new profile's
  default bars hold no spells, so defensives stay where Blizzard's Cooldown
  Manager categories put them: add them to Essential in Blizzard's settings.
- **Left Buffs and Right Buffs** at x -122 and 122, y -16 (28 closer to the
  center and 16 lower), 3px clear of the Target's 44px portrait ring.
  Player Debuffs (Buffs & Debuffs) counts from Right Buffs' right edge, 139.

## Mode-DPS/TANK layout

ModeCDM's part of ModeUI's built-in Mode-DPS/TANK layout (DPS / Tank, the
owner's layout editor, November 18, 2026; `Layouts.lua`, registered with
`addon.Layouts:Contribute("mode-default", "cooldownManager", ...)`). It
writes only the new Mode-DPS/TANK profile; the profile in use never changes.
Places are an element's `point` on the target's `relativePoint`, in UI units
(a pixel each at the pixel-perfect scale), with no gap added. "1440" is a UI
1260 units tall or more; anything shorter takes the 1080 values.

| Element | Settings | Place (1080 / 1440) |
|---|---|---|
| Cooldown Manager | switched on | |
| Essential Cooldowns | 38 by 30, 7 per line, Centered Horizontal, New Lines Down | center on the screen's bottom, 300 / 325 up |
| Utility Cooldowns | 36 by 30, 6 per line, Centered Horizontal, Down | top on Essential's bottom, 69 down (36 under a second Essential row) |
| Resource Bars | Group Resources; Power 10 (text 9), Combo Points 8 (no text: the lit points are the count), Alternate Mana 8, all Bar Mode Color (Power in Class Color, Combo Points and Alternate Mana in their own colors); Health off; Power's Match Width on, matched to Essential (Edit Mode's pick) | Power: bottom on Essential's top, 1 up |
| Cast Bar | height 12, Match Width on, matched to Essential; Icon Hidden | bottom on Power's top, 1 up |
| Tracked Buffs | 30 by 24, 10 per line, Centered Horizontal, New Lines Up | bottom on the Cast Bar's top, 1 up |
| Defensive Cooldowns | 36 by 30, otherwise its defaults (above) | bottom right on ModeUI Player Frame Bars' top right (the bar block), (1, 0): on the frame's top border |
| Emphasized Buffs | 38 by 30, otherwise its defaults | bottom on Tracked Buffs' top, 1 up |
| Left Buffs / Right Buffs | their defaults | screen center, 150 left / 150 right |
| Ultra Emphasized Buffs | its defaults | screen center, 110 / 135 right and 115 up |
| Tracked Bars | its defaults | top on Utility's bottom, 4 down (owner, November 20, 2026: at its default place the stand-in covered the Target frame; the Healer layout too) |

Every icon bar (the four viewers and the five default bars) also takes the
owner's tuning (November 18, 2026, tested at 1080p; the look since November 20, 2026): every bar in Mode-Empty with the neutral, darker `emptyRim`,
Border Size 1, Spacing -1 (neighbours share one shadow pixel) and cooldown
numbers in `cooldownHot` (#FF3948). Defensive Cooldowns hang from the Player
frame's bar block (`unitFramesPlayerBars`, its border on the block's edge),
so Portrait Size, Health Height and Frame Width never push them into the
frame: the bar's stand-in ends in its icons' shadow ring, so on the block's
top the two share one shadow pixel; +1 lines the icons' band up with the
frame's right end. `tests/layouts.lua` checks they clear the portrait ring
at every Portrait Size and Health Height.

Stand-ins as built: each bar's stand-in is one line of its icons, every icon
with its 2px edge on each side, Spacing apart: Essential 288 by 34, Utility
236 by 34 (235 made even), Defensive Cooldowns 118 by 34, Emphasized Buffs 166
by 34 (165), Ultra Emphasized Buffs 116 by 52 (115). A line of an odd pixel
count is rounded up to an even one so a centered line lands on whole pixels:
Tracked Buffs are 332 by 28 (331) and Left and Right Buffs 34 by 164 (163);
a bar that hangs by its middle splits the extra pixel half to each side and
no offset can make up for it. Power's grouped block is Essential's 288 wide
and its bars plus the edges tall (14 with Power alone; each Combo Points or
Alternate Mana strip adds its height and a 1px line); it hangs by its bottom,
so it grows upward and the Cast Bar (12 plus its edges, 16) and Tracked
Buffs ride above it.

### In-game check: Mode-Default layout (November 18, 2026)

- **Navigation:** type `/modeui`, click **Profiles**.
- **Action:** pick **Mode-Default** in **Profile**, click **Switch to This
  Profile**, then **Reload** at the bottom left of the window. Type
  `/mcdm`; click **Edit Mode** in the window's header and look at the
  bars, then **Done**.
- **Required state:** ModeCDM and ModeUI installed, logged in once after
  updating (the Mode-Default profile is made at login; one made before the
  owner's tuning of November 18, 2026 keeps the old values: delete it and
  make it again with **New from DPS / Tank Layout**), Unit Frames on, a
  class with a power bar; out of combat.
- **Confirmation:** the window lists Defensive Cooldowns under **Cooldown
  Bars** and Emphasized Buffs, Left Buffs, Right Buffs and Ultra Emphasized
  Buffs under **Buff Bars**; in Edit Mode Essential sits low in the middle
  (300 up at 1080, 325 at 1440) with Utility 69 below it, and above Essential,
  1 pixel apart each, the grouped resource bars (filled: Power in your class
  color) and the Cast Bar as wide as Essential, then Tracked Buffs, then
  Emphasized Buffs; every bar in Mode-Round Gunmetal with one dark pixel
  between icons and red (#FF3948) cooldown numbers; Defensive Cooldowns sit
  on the Player frame's top border at its right end, one dark pixel above the
  frame's band, right ends lined up; Left and Right Buffs
  stand either side of the screen's middle; no Lua errors. Switching back to
  your old profile shows it as it was.

### In-game check: default bars (November 18, 2026)

- **Navigation:** type `/mcdm`, click **Ultra Emphasized Buffs** under **Buff
  Bars** in the window's list.
- **Action:** change its **Width**, then click **Reset to Defaults** on the
  Copy & Apply tab; click the **-** beside it, then **Delete Bar**; type
  `/reload` and open `/mcdm` again.
- **Required state:** a profile from before this update (version 8) with the
  Cooldown Manager on; out of combat.
- **Confirmation:** after the update the profile's own bars come first and
  the five default bars follow them; Reset to Defaults brings back Cooldown
  text 22 and keeps the width you set; the deleted bar doesn't come back
  after the reload.
