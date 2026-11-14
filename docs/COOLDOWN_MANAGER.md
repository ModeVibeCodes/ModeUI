# Interface: Cooldown Manager

November 13, 2026. A module of the **Interface** category, after Action Bars.
Off by default (turn it on with the switch in the page header). Only checked
against the mock client (`tests/cooldown_manager.lua`); **native acceptance is
pending**. Its APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#cooldown-manager--november-13-2026).

## What it does

Blizzard's own Cooldown Manager in the Mode look. Forever ships it
(`Blizzard_CooldownViewer`, loaded for the `camelot` game type) with four
viewers: **Essential Cooldowns**, **Utility Cooldowns**, **Tracked Buffs** and
**Tracked Bars**. Blizzard keeps deciding which spells each one tracks (its
Cooldown Settings window) and keeps every icon's cooldown, charges, auras,
range and procs up to date. ModeUI takes over:

| Part | Look and behavior |
|---|---|
| Placement | Each viewer has a stand-in in ModeUI's Edit Mode (`ModeUICooldownEssential`, `...Utility`, `...BuffIcon`, `...BuffBar`), anchored like any other element: to the screen, your frames or another viewer. By default Essential sits at the bottom middle, 300 px up; Utility hangs under it, Tracked Buffs on top; Tracked Bars sits to the right. |
| Layout | Icons per Line (12; bars 1), Lines (Rows or Columns), First Icon (the corner the first icon sits in; Tracked Buffs and Bars start Bottom Left so they grow upward), Center Lines (a short last line moves to the middle), Width, Height and Spacing (2 px). Spells Blizzard hides (an inactive buff with Hide When Inactive) leave no gap. |
| Icons | The Mode slot shared with Action Bars (`Kit.Slot`): a hollow 2px border (#101010) around a #040404 background at 75% with the slot grain, the icon one pixel inside, cropped square to the slot's shape. Essential icons are 42 by 36 like action buttons; Utility and Tracked Buffs 35 by 30. Blizzard's round mask and frame art come off. |
| Cooldown | A flat swipe in Swipe Color (black) at Swipe Opacity (70%); Blizzard's gold swipe for an active aura stays. **Edge** (off), **Bling** (on) and **Ready Flash** (Blizzard's flash just before a cooldown ends; on). **Out of Range Shade** turns Blizzard's shade into a flat red tint inside the border. **Debuff Border** (Tracked Buffs and Bars; off) is Blizzard's colored frame around a debuff on your target. |
| Bars | Tracked Bars: the icon in the Mode slot, a square as tall as the bar, on the Icon Side (Left); the bar in its own box beside it (the same border, Bar Background Mode Slate at 70%), filled in Bar Texture (Mode Gradient) and Bar Color (Mode cyan). Blizzard's background and spark are faded (**Spark** brings the spark back). Blizzard's Bar Content still applies: with the icon hidden, the bar takes the whole width. 220 by 22 by default. |
| Text | Icons: **Cooldown** (the numbers, amber #FFB12F, centered; 15 on Essential, 12 elsewhere) and **Count** (charges or stacks, bottom right). Bars: **Name** (left, inside the bar, stopping short of the time), **Duration** (right) and **Count** (on the icon). Each has Show This Text, Anchor, Size, Offset X and Y, and Color; the font (Expressway), Outline, Text Shadow and Slug Text are per viewer. |
| Glows | Essential and Utility. **Proc Glow**: Mode Glow (gold, Pulse), Border, Blizzard (the game's animation) or None. **Glow When Ready** (off): a cooldown longer than the global cooldown ending lights its icon for Glow Time (2 s), as a Glow or a Border, in Glow Color (Mode cyan). One glow shows at a time. |
| Spells | Clicking a spell in the settings preview opens its menu: **Show in This Viewer** (hidden spells leave no gap, take no mouse and show faded in the preview), and on Essential and Utility **Proc Glow** and **Glow When Ready** for that spell. **Copy**, **Paste** and **Apply to Viewer** move one spell's switches to others; **Reset All Spells** on the Spells tab clears them. Switches are kept by the game's cooldown ID, so they follow the spell when Blizzard reorders it. |
| Visibility | Show: Always, In Combat, Out of Combat, In Combat or With a Target, Mouseover (Faded Opacity until the mouse is over the viewer) or Hidden; Opacity. **Show Viewer** off hides a viewer. Every viewer that's on shows in Edit Mode. |
| Copy & Apply | The viewer in Editing is the source: its look (borders, background, cooldown, text, glows, opacity, bars) goes to the viewers you tick; each keeps its size, lines, spells and show settings. **Reset to Defaults** puts the look back. |

The settings page has a live preview of the viewer in **Editing**: your own
tracked spells (icons and names from the game's spell data), drawn by the
same layout and skin code. With nothing tracked yet, sample icons stand in.
While you edit the Cooldown text, a sample cooldown runs on the first icon.
Tabs: Viewer, Look, Text, Glows, Spells, Visibility, Copy & Apply. The Viewer
tab's **Cooldown Settings** button opens Blizzard's window for choosing the
tracked spells (outside combat), and **Open Edit Mode** opens ModeUI's.

## What stays Blizzard's

- **Which spells, and their order:** Blizzard's Cooldown Settings.
- **Blizzard's Edit Mode options** for each viewer: Visibility, Opacity, Hide
  When Inactive, Show Timer, Show Tooltips and, for bars, Bar Content. They
  apply first; set Visibility to Always to let ModeUI's Show decide. Its
  Icon Size, Icon Padding, Icon Limit, Orientation and Icon Direction are
  replaced by ModeUI's layout, and its Edit Mode box no longer moves the
  viewer.
- **The game option** `cooldownViewerEnabled` (the Cooldown Manager checkbox
  in the game's Options). ModeUI never changes it (game-wide settings belong
  to the Optimizations module); the Status line says when it's off.

## How it follows Blizzard

The viewers and their item frames are plain frames (no secure template), so
everything here also works in combat. But Blizzard's code in them does math
on secret cooldown and aura values, which it may only do while it runs
untainted. So ModeUI:

- **never writes a field** on a viewer or item frame. Its textures, glows and
  state live in weak tables keyed by the frame (`M.dress`, `M.glows`,
  `M.viewerOf`). `tests/cooldown_manager_stubs.lua` fails any write from
  ModeUI's files onto Blizzard's frames.
- **only post-hooks** (`hooksecurefunc`) and runs each hook body through
  `pcall`, reporting an error once without breaking Blizzard's call:
  - viewer `OnAcquireItemFrame` (a new item: skin it), `Layout` (Blizzard's
    grid just placed the icons: place them again at once, on the holder)
    and `RefreshData` (spells changed in place: lay out on the next frame);
  - item `UpdateShownState` (a buff came or went: close the gap on the next
    frame), `RefreshSpellCooldownInfo`/`RefreshCooldownInfo` (Blizzard reset
    the swipe and edge: set ModeUI's again) and, on bars, `SetBarContent`
    (re-place the icon and bar box);
  - `ActionButtonSpellAlertManager:ShowAlert`/`HideAlert`, as Action Bars
    does, for proc glows.
- **never calls a Blizzard method that refreshes or lays out**, and never
  shows, hides, moves, scales or fades Blizzard's viewer frames: they sit in
  the game's managed layout. The icons stay Blizzard's children (so its
  Visibility, Opacity and the CVar still hide them) and are re-anchored to a
  ModeUI holder on the viewer's stand-in, sized to ModeUI's settings and set
  back to scale 1. Visibility, hidden spells and Mouseover fade the icons
  (`SetAlpha`), which Blizzard never sets.
- reads only public values: cooldown IDs (from `C_CooldownViewer`), each
  entry's spell (`GetCooldownViewerCooldownInfo`), names and icons
  (`C_Spell`), and `C_Spell.GetSpellCooldown`'s never-secret `isActive` and
  `isOnGCD`. An item's shown state can be secret (from aura data in combat);
  a secret one counts as shown, so the icon keeps its place. Blizzard's
  texts are styled, never measured.

Switching the module off stops the placement, glows and fading at once (every
icon back at full); the next time Blizzard lays a viewer out, its own grid
returns. Blizzard's look comes back with a reload, which ModeUI offers.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, the viewers, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: validation (version 1) |
| `Driver.lua` | lifecycle, events, settings changes, per-spell switches, copy and reset, status |
| `Blizzard.lua` | finding and hooking Blizzard's viewers and items; spell keys |
| `Layout.lua` | geometry, stand-ins and holders, placing the icons |
| `Skin.lua` | the icon skin and the swipe; preview samples |
| `Bars.lua` | the Tracked Bars skin |
| `Text.lua` | the texts |
| `Glow.lua` | proc and ready glows; a spell's alpha |
| `Visibility.lua` | Show, Opacity, Mouseover |
| `SpellMenu.lua` | the preview's spell menu |
| `Preview.lua` | the settings preview |
| `Settings.lua`, `SettingsTabs.lua` | the settings page |

Shared pieces it added: `Shared/Domain/Cooldowns.lua` (the game's Cooldown
Manager data) and `Shared/Kit/Slot.lua` (the Mode slot and its glows, moved
out of Action Bars, which now uses it too).

## In-game check

- **Navigation:** type `/modeui`, then pick **Interface** › **Cooldown Manager**
  in the sidebar.
- **Action:** switch the module on with the switch in the page header. Then
  click a spell in the preview and untick **Show in This Viewer**, open **Edit
  Mode** from the window header, and drag the Essential Cooldowns stand-in.
- **Required state:** out of combat, with the game's Cooldown Manager option on
  and at least one spell tracked in Blizzard's Cooldown Settings.
- **Confirmation:** the icons above your action bars show square, bordered
  and in centered rows. The unticked spell disappears and the others close
  up, and the viewer follows the stand-in you dragged. In combat, cooldowns,
  charges and procs still update, and no Lua errors appear.
