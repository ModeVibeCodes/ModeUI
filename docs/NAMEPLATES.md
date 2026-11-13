# Interface: Nameplates

November 12, 2026. Second module of the **Interface** category. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending**. APIs and their secret-value rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-nameplates--november-12-2026).

## What it draws

On every nameplate the game gives to addons, ModeUI parents its own plain
frame and fades Blizzard's art. Each plate has:

- **Health box**: a 1px slate rim, a 1px black gap, then the health bar, in the
  same Onyx look as the unit frames. The width and bar height are settings.
- **Name** above the box, and optional health text inside it (Percent, Current
  Health, Current and Percent, None). All text uses the suite's lifted shadow.
- **Health color**: Reaction and Class (players by class, NPCs by reaction),
  Reaction, Onyx (the dark unit frame fill) or Custom. Class and reaction colors
  are softened toward white by Color Softness (30% by default).
- **Threat Colors** (on by default): red when the enemy is attacking you, orange
  when you are close to pulling it. Unknown, and so not shown, while the game
  restricts threat.
- **Cast bar** below the health box with the spell icon and name. Amber when
  interruptible, gray when not. Channels drain from right to left.
- **Raid marker** left of the health box, and a **cyan rim** on your target's plate.

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
| `Init.lua` | declaration, defaults, ranges, choices, `Initialize(db)` validation (settings version 1) |
| `Driver.lua` | lifecycle, events, fading Blizzard's unit frame, settings changes |
| `Plate.lua` | building a plate on a nameplate and its pixel-perfect layout |
| `Update.lua` | health, name, colors, threat, raid marker, target highlight |
| `CastBar.lua` | cast and channel bars |
| `Settings.lua` | the settings page (tabs: Plates, Health, Text, Cast Bar, Markers) |

Shared pieces added for this module, and reusable by Party Frames and others:
`Domain/Cast.lua`, `Domain/RaidIcon.lua`, `Domain/Threat.lua`,
`Domain/Nameplate.lua`, `Kit/Palette.lua` (the Onyx and Mode colors, plus
`Kit.ColorFromBoolean`) and `Kit.FontPath`.

## Not in this version

- **Auras** (debuffs on enemies). Aura data on mainline is heavily secret; it
  needs its own research before building.
- Class resource bars on enemy plates, and enemy-only or friendly-only sizes.

## Manual check

- **Navigation:** `/modeui`, then **Interface** › **Nameplates**.
- **Action:** turn the module on with the switch in the page header. Look at
  enemies and friendly NPCs in the open world. Target one, mark one with a raid
  marker, and watch an enemy cast. Then switch the module off.
- **Required state:** out of combat to change settings; enemy nameplates shown
  (the game's own nameplate setting).
- **Confirmation:**
  - Onyx plates replace Blizzard's, with the right colors and names.
  - The cast bar fills (or drains, for channels) and is gray when the cast
    can't be interrupted.
  - The target has a cyan rim and markers appear.
  - Clicking a plate still targets.
  - Switching off brings Blizzard's plates back.
