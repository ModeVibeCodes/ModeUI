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
- **List** on the left: **Blizzard** (the four viewers) and **Custom Bars**,
  then **+ Cooldown Bar** and **+ Buff Bar** (up to ten custom bars). A bar
  that's off says so.
- **Page** on the right: the module's title and on/off switch, a live
  preview of the bar chosen in the list, and its tabs: Bar, Look, Text,
  Glows, Spells, Visibility, Copy & Apply.

### Every bar's settings

| Part | Look and behavior |
|---|---|
| Placement | Each bar has a stand-in in ModeUI's Edit Mode (`ModeUICooldownEssential`, ..., `ModeUICooldownCustom1`), one full line long, anchored to the screen, your frames or a viewer. The first line never moves; more lines grow outside it. Essential starts at the bottom middle, 300 px up, Utility under it, Tracked Buffs on top, Tracked Bars to the right; custom bars in the middle of the screen. |
| Growth | **Centered Horizontal** (default), **Centered Vertical**, **Horizontal Right**, **Horizontal Left**, **Vertical Down** or **Vertical Up**, with **New Lines** going Down or Up for rows, Right or Left for columns (Tracked Buffs and Bars: Up). **Icons per Line** (12; bars 1; custom bars 8), Spacing (2 px), Width and Height. Spells Blizzard hides (an inactive buff) leave no gap. |
| Icons | **Border**: **ModeUI** (default; ModeUI's standard border, `Kit.ModeBoxBorder`: one crisp 2px rim in Border Color, #40454C, with corners rounded 4px, on its own frame above the icon), or the action bars' slot rim (**Rounded**, **Square**, with Border Size) or **None**. Inside it the 75% background with the slot grain and the icon, cropped square, starting at the rim's inner edge, so the rim's corners cover the icon's square corners (no mask on Blizzard's textures). Tracked Bars' icons and bar boxes take the same border. Blizzard's round mask and frame art come off. |
| Cooldown | **Desaturate on Cooldown** (on): an icon goes gray while its spell is on a real cooldown (not the global cooldown, nor while its effect is up); off, icons keep full color. A flat swipe in Swipe Color at Swipe Opacity (70%); Blizzard's gold swipe for an active aura stays. **Edge**, **Bling**, **Ready Flash**, **Out of Range Tint** (Blizzard's red tint on an out-of-range spell; off keeps full color) and, on buffs, **Debuff Border**. Blizzard's out-of-range shade, cut to its round mask, stays faded: repainted it showed as a solid red block, and Blizzard leaves it shown on an icon with no spell yet. |
| Bars | Tracked Bars: the icon in the Mode slot beside the bar's own box, filled in Bar Texture (Mode Gradient) and Bar Color over Bar Background; Icon Side, Spark. |
| Text | Icons: **Cooldown** and **Count**; bars: **Name**, **Duration**, **Count**. Each with Show This Text, Anchor, Size, Offsets and Color; Font, Outline, Text Shadow, Slug Text. |
| Glows | Each with a style (Mode Glow, Border or None), a Glow Color and Pulse. Cooldown icons: **Proc Glow** (also Blizzard's own animation; on by default, gold), **Active Glow** (while the spell's effect is up, the time Blizzard shows with its gold swipe), **Off Cooldown Glow** (**Flash** for Glow Time when a cooldown ends, or **While Ready**). One shows at a time: proc, active, off cooldown. Buff icons: **Buff Glow** (while the buff is up). Tracked Bars have none. All but the proc glow start off. |
| Spells | Clicking a spell in the preview opens its menu: **Show on This Bar**, a switch for each of the bar's glows, **Copy**, **Paste** and **Apply to Bar**; on a custom bar also **Earlier**, **Later** and **Remove from Bar**. Hidden spells leave no gap and show faded in the preview. Switches are kept by the game's cooldown ID. **Reset All Spells** on the Spells tab clears them. |
| Visibility | Show: Always, In Combat, Out of Combat, In Combat or With a Target, Mouseover (Faded Opacity) or Hidden; Opacity; **Show Bar**. |
| Copy & Apply | The bar being edited is the source; its look goes to the bars you tick, each keeping its size, lines, spells and show settings. **Reset to Defaults**. |

### Custom bars

**+ Cooldown Bar** makes a bar for spells from Essential and Utility
Cooldowns; **+ Buff Bar** one for Tracked Buffs. Its preview ends with a
**+** slot: clicking it lists, as icons, the spells you track in Blizzard's
Cooldown Manager that the bar can take (pointing at one names it and says
where it shows now). Clicking one adds it. Blizzard's own icon for that spell
moves onto the custom bar, so it keeps updating exactly as before, and its
viewer closes up. A spell sits on one custom bar at a time; adding it to
another moves it. The bar's Bar tab has its **Name**, how many spells it
holds and **Delete Bar** (its spells go back to their viewers). A spell that
isn't tracked now (you removed it in Blizzard's window) stays in the list,
faded and gray in the preview, and comes back when you track it again. On a
viewer the **+** slot opens Blizzard's Cooldown Manager instead.

Custom bars follow the viewer their spells come from for Blizzard's own
Visibility and the game option: the icons are still that viewer's children.

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
  by reference (`rawequal`). A buff's active state can be secret in combat;
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
your choices. Version 3 gave every bar the ModeUI border (a Rounded border, the old default, becomes it, and the old #101010 color its color; Square and None stay). Bad data stops startup; nothing is reset.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration (standalone), the viewers and custom bar kinds, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: version 1 to 2, validation |
| `Driver.lua` | lifecycle, `/mcdm`, events, settings changes, per-spell switches, copy and reset, status |
| `Custom.lua` | the bar list, custom bars and which spell shows where |
| `Blizzard.lua` | finding and hooking Blizzard's viewers and items |
| `Layout.lua` | Growth geometry, stand-ins and holders, placing the icons |
| `Skin.lua`, `Bars.lua`, `Text.lua` | icon skin, swipe and gray; Tracked Bars; texts |
| `Glow.lua` | the four glows; a spell's alpha |
| `Visibility.lua` | Show, Opacity, Mouseover |
| `SpellMenu.lua`, `Picker.lua`, `Preview.lua` | the preview, its spell menu and the + slot's list |
| `Settings.lua`, `SettingsTabs.lua` | the settings page |
| `Window.lua` | the module's own window |

Shared pieces it uses or added: `Shared/Domain/Cooldowns.lua`,
`Shared/Kit/Slot.lua`, `addon:RegisterSettingsWindow` (Edit Mode returns to
a standalone module's window), `PositionManager:SetLabel`, and the
`standalone` module field (no sidebar entry or search results in ModeUI's
window; Edit Mode's Open Module Settings calls `module:OpenSettings`).

## In-game check

- **Navigation:** type `/mcdm`.
- **Action:** turn the module on with the switch at the top right of the
  window's page. Click **+ Cooldown Bar** in the list, then the **+** slot in
  the preview, and click a spell in the list that opens. Then click
  **Edit Mode** in the window's header and drag the new bar's stand-in.
  Click **Exit** in the Edit Mode window.
- **Required state:** out of combat, with the game's Cooldown Manager option
  on and spells tracked in Blizzard's Cooldown Manager (**Open CDM**).
- **Confirmation:** the spell's icon leaves its viewer (the rest close up)
  and shows on the new bar where you dragged it; icons go gray while their
  spell cools down; the Cooldown Manager window comes back after Edit Mode;
  ModeUI's own window (`/modeui`) has no Cooldown Manager page. In combat,
  cooldowns, charges and procs keep updating, with no Lua errors.

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
