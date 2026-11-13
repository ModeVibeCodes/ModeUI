# Interface: Nameplates

November 12, 2026. Second module of the **Interface** category. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending**. APIs and their secret-value rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-nameplates--november-12-2026).

## What it draws

On every nameplate the game gives to addons, ModeUI parents its own plain
frame and fades Blizzard's art. Each plate has:

- **Health box**: a 1px slate rim and a 1px black gap with rounded corners, like
  the unit frames, then the health bar. The width and bar height are settings.
  Boxes too small to round (under 12px) stay square.
- **Mode Gradient** on every bar: a flat fill with a soft white gradient over its
  top half. It is ModeUI's only bar texture (`Kit.ModeGradient`), so there is no
  texture setting.
- **Name** above the box, and optional health text inside it (Percent, Current
  Health, Current and Percent, None). All text uses the suite's lifted shadow.
- **Health color**: Reaction and Class (players by class, NPCs by reaction),
  Reaction, Onyx (the dark unit frame fill) or Custom. Class and reaction colors
  are softened toward white by Color Softness (30% by default).
- **Threat Colors** (on by default for enemies): red when the enemy is attacking you, orange
  when you are close to pulling it. Unknown, and so not shown, while the game
  restricts threat.
- **Cast bar** below the health box with the spell icon and name. Amber when
  interruptible, gray when not. Channels drain from right to left.
- **Raid marker** left of the health box, and a **cyan rim** on your target's plate.
- **Auras** (see below).
- Text uses Expressway by default, like all of ModeUI.

## Enemy and friendly plates

Every plate is an **enemy** plate (a unit you can attack, `UnitCanAttack`) or a
**friendly** one, and each kind has its own full set of settings: size, colors,
text, cast bar and markers. **Use ModeUI Plates** turns ModeUI's plates on or off
per kind; a kind switched off keeps Blizzard's plates. A unit that changes sides
(a duel, mind control) switches kinds on `UNIT_FACTION`.

- Enemy defaults: 140 x 12, percent health text, Threat Colors on.
- Friendly defaults: 120 x 8, no health text, Threat Colors off.
- **Copy Style to Friendly/Enemy** copies the whole look; Use ModeUI Plates stays
  each kind's own. **Reset to Defaults** resets only the kind being edited.
- Settings version 3. A version 1 profile (one shared set) copies its values into
  both kinds; version 2 drops the retired texture choice and adds aura defaults.

## Auras

Each kind has an **Auras** tab:

- **What Shows.** **Crowd Control** (stuns, fears, polymorphs) comes first.
  **Debuffs** can be Yours, Ones You Can Dispel, All or None, and **Buffs** can
  be Dispellable or Stealable, Important, Yours, All or None. The game's own aura
  filters decide what matches, so secret aura data is never compared.
- **Placement.** **Position** (Above the name, Below the cast bar, Left or Right
  of the health box), **Alignment** (for Above and Below), **Icon Size**,
  **Spacing** and **Most Shown**. Left icons start past the raid marker.
- **Details.** **Timer Swipe** and **Stack Count**.
- Enemy defaults: crowd control, your debuffs and dispellable buffs, 20px, up to 6.
  Friendly defaults: debuffs you can dispel, 16px, up to 4.
- Icons have a 1px slate rim. Stacks come from the game as text. The swipe is
  drawn when the game allows it; while auras are restricted (secret), icons and
  stacks still show but the swipe may not.

## Preview

The top of the page shows a sample enemy plate (marked with a skull, shown as
your target, casting Shadow Bolt) and a sample friendly plate (casting Flash
Heal), each with sample auras. Both are built and laid out by the same code as
plates in the world, so they always match the current settings: which auras
show, where and how big, and a kind switched off.
**Static** shows each cast 60% done; **Animated** loops the casts. **Pop Out**
moves the preview into its own window, and **Collapse** hides it. It uses the
shared settings preview (`W.Preview`) and `PreviewStates`.

## What stays Blizzard's

- Where plates appear, their stacking, scale, clicks and hit areas.
- Friendly plates inside instances (forbidden to addons).
- Your personal resource display, and widget-only plates (objects and some
  quest units).

Switching the module off gives every plate back to Blizzard at once. Plates are
plain frames, never secure, so they also work in combat. Settings change outside
combat, like every ModeUI page.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, per-kind defaults, ranges, choices, `Initialize(db)` validation and the version 1 migration |
| `Driver.lua` | lifecycle, events, enemy or friendly kind, fading Blizzard's unit frame, per-kind settings, Copy Style and Reset |
| `Plate.lua` | building a plate on a nameplate and its pixel-perfect layout |
| `Update.lua` | health, name, colors, threat, raid marker, target highlight |
| `CastBar.lua` | cast and channel bars |
| `Auras.lua` | aura icons: groups, order and placement |
| `Preview.lua` | the sample enemy and friendly plates on the settings page |
| `Settings.lua` | the settings page: preview, then tabs Nameplates, Text, Cast Bar, Auras, Markers, each with an Editing switch for Enemy or Friendly |

Shared pieces added for this module, and reusable by Party Frames and others:
`Domain/Cast.lua`, `Domain/RaidIcon.lua`, `Domain/Threat.lua`,
`Domain/Nameplate.lua`, `Kit/Palette.lua` (the Onyx and Mode colors, plus
`Kit.ColorFromBoolean`) and `Kit.FontPath`.

## Not in this version

- Class resource bars on enemy plates.
- Dispel-type colors on aura rims (they need a color curve over secret data).

## Manual check

- **Navigation:** `/modeui`, then **Interface** › **Nameplates**.
- **Action:** turn the module on with the switch in the page header. Check the
  preview at the top of the page, use **Editing** to switch between **Enemy** and
  **Friendly**, change a setting for each and watch the preview follow; try
  **Animated** and **Use ModeUI Plates** off for Friendly. Look at enemies and
  friendly NPCs in the open world. Target one, mark one with a raid marker, and
  watch an enemy cast. On the **Auras** tab, change Debuffs, Buffs, Position and
  Icon Size for each kind and watch the preview, then check auras on real
  enemies (apply a debuff, find a buffed enemy). Then switch the module off.
- **Required state:** out of combat to change settings; enemy nameplates shown
  (the game's own nameplate setting).
- **Confirmation:**
  - Onyx plates replace Blizzard's, with the right colors and names.
  - The cast bar fills (or drains, for channels) and is gray when the cast
    can't be interrupted.
  - The target has a cyan rim and markers appear.
  - Enemy and friendly plates follow their own settings, and the preview matches them.
  - Plates have rounded corners and every bar shows the Mode Gradient.
  - Your debuffs appear above enemies with stacks and a timer swipe.
  - Clicking a plate still targets.
  - Switching off brings Blizzard's plates back.
