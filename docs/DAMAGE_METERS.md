# Interface: Damage Meters

November 13, 2026. Fourth module of the **Interface** category. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending**. APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-damage-meters--november-13-2026).

## How it works

Addons can't read the combat log on the 12.x client Forever runs on. The game
records fights itself (`Blizzard_DamageMeter`, which Forever loads with
`AllowLoadGameType: standard, camelot`) and offers that record to addons through
`C_DamageMeter`. ModeUI reads it and draws its own windows, the way current
third-party meters do (Recount-Revived, Skada's Midnight edition, ForeverMeter).

ModeUI **never touches Blizzard's meter window**. One meter author reported that
writing into Blizzard's windows taints their refresh and makes them log errors
in combat. To see only ModeUI's windows, set Blizzard's meter to hidden with its
own Edit Mode settings. The game only records while its own **Damage Meter**
option is on. ModeUI reads that option (`damageMeterEnabled`) and never changes
it, because game-wide settings belong to the Optimizations module. When it's
off, the page's **Status** line and the windows say so.

Game data is read only in `Shared/Domain/DamageMeter.lua`. Every call there is
guarded, and a missing API counts as "no data". On a client without the meter,
the windows say so.

## Secret values

In combat the game makes amounts, names and source GUIDs secret
(`SecretWhenInCombat`). ModeUI's code is tainted, so it can't do arithmetic on
them, compare them or sort them. Instead:

- **Ranking** is the game's own order. Nothing is sorted.
- **Bars:** each row's StatusBar gets `SetMinMaxValues(0, maxAmount)` and
  `SetValue(totalAmount)`, both `AllowedWhenTainted`. The top source fills its
  bar and the rest scale to it with no math in Lua.
- **Numbers:** `AbbreviateNumbers` (C code, `AllowedWhenTainted`) turns an
  amount into text. `SetFormattedText` joins rank, name and numbers
  (`"%d. %s"`, `"%s (%s)"`).
- **Percent** needs division, so it shows only while the amounts are public,
  after the fight.
- **Never secret:** class (`classFilename`), "you" (`isLocalPlayer`) and
  `deathRecapID`. They drive bar colors, class icons, Always Show Me and Death
  Recap.
- **Spec icons:** on Forever `specIconID` is always secret (it is `NeverSecret`
  on mainline), so rows use class icons (`GetClassAtlas`, confirmed by
  `C_Texture.GetAtlasInfo`).
- **Breakdowns:** the game refuses secret arguments from addons
  (`AllowedWhenUntainted`), so a source whose GUID is secret can't be asked for
  its spells in combat. The panel says "Spell details show after combat." It
  finds the source by its rank and fills in once the GUID is public again.
- **Tooltips:** no secret value ever goes to `GameTooltip`.

After combat the module redraws again after 1 and 3 seconds, so percent and
breakdowns appear without waiting for the next meter event.

## Windows

There are up to three windows: **Window 1** (on by default, Damage Done),
**Window 2** (Healing Done) and **Window 3** (Damage Taken). Each has its own:

- **Meter:** Damage Done, DPS, Damage Taken, Avoidable Damage Taken, Enemy
  Damage Taken, Healing Done, HPS, Interrupts, Dispels or Deaths. These are the
  meters Blizzard's own menu offers.
- **Fight:** Current Fight or Overall. These are saved. An earlier fight picked
  from the header menu stays until the game resets its data or the window
  changes meter.
- **Show** setting, size, bars, text, header and frame.

Clicking a header opens the menu. Meters are on the left (Damage, Healing,
Actions). Fights are on the right: Current Fight, Overall and the last ten
earlier fights with their length. **Reset All Data** is at the bottom.
Right-clicking a row opens the same menu. The mouse wheel scrolls through the
ranking.

Clicking a row opens its **spell breakdown** beside the window, on the side
facing the middle of the screen. It's drawn like the window, with spell icons
and bars in the source's color. Pet spells read "Spell (Pet)". It follows the
window's meter and fight. Clicking its header, or the same row again, closes
it. On the Deaths meter, clicking a row opens the game's **Death Recap**
instead.

## The look

Every size is snapped to whole physical pixels. The window is exactly as tall
as its rows and an even number of pixels each way, so a centered window stays on
the pixel grid. From the outside in:

| Part | Default | Setting |
|---|---|---|
| Rim | 1px, Rounded, #101010 | Frame › Border, Border Size (screen pixels), Border Color |
| Background | #040404 at 75% | Frame › Background Color, Background Opacity |
| Header | 20px, #141518 | Header › Height, Header Color, Header Opacity |
| Title | 11, uppercase, Mode cyan | Header › Text Size, Title Color, Uppercase Title |
| Fight and timer | right side of the header | Header › Show Fight, Show Timer |
| Divider | 1px in the rim color | shown when there is a header and a rim |
| Padding | 1px | Window › Padding |
| Rows | 8 rows, 18 high, 1 apart, 240 wide | Window › Width, Rows, Row Height, Spacing |
| Icon | square class icon, 1px gap | Bars › Icon |
| Bar | Mode Gradient, class colored | Bars › Foreground, Bar Opacity, Bar Color (Class or Custom), Other Color |
| Empty bar | Flat, Onyx track at 25% | Bars › Background, Background Opacity |
| Text | Expressway 12, crisp shadow, 4px in | Text › Font, Outline, Slug Text, Text Shadow, Name Size, Value Size, Text Inset |

Rounded leaves out each corner's outermost pixel (`Kit.Rim`/`Kit.PlaceRim`,
shared). **Other Color** (#78808C) is for anything without a class, like pets
and creatures. **Name Color** is Text Color or Class (Class Colors' custom
colors apply).

Numbers: **Amount** shows one number. **Amount and Per Second** (the default)
adds the other in parentheses. DPS and HPS lead with the per-second amount.
Interrupts and Dispels have no per-second amount. **Show Percent** adds
" · 59%" after the fight. **Show Rank** puts "1." before the name.

**Always Show Me**: when you rank below the last row, your row takes the last
row (or the first, if you've scrolled past it).

## When a window shows

**Show** on the Window tab: Always, In Combat, In a Group or Hidden, plus
**Opacity**. **Click Through** lets clicks and the mouse wheel pass to the game
world. Windows are plain frames (nothing is protected), so they show, hide,
resize and update in combat. Settings also change in combat.

## Edit Mode, Test on Screen and the preview

In **Edit Mode** every window that's on shows, Hidden ones too, with a cyan
stand-in named after it ("Window 1"). The windows show a sample fight so they
can be laid out without one. Window 1 sits on the right edge below the middle.
Windows 2 and 3 stack above it by default, and a window can anchor to a window
listed before it. Position Manager moves the stand-in (it drives the mouse on
what it registers), and the window hangs from the stand-in's top-left corner.

**Test on Screen** shows the sample fight on the real windows. The settings page
preview is the window being edited, drawn by the same code, with the sample
fight. **Animated** plays it out over 20 seconds. Clicking the preview's header,
bars, text or frame opens the Header, Bars, Text or Frame tab.

The sample group is Forever's nine classes plus a creature. One row is marked as
you, for Always Show Me. Healing meters rank the healers first.

## Settings page

Five tabs, each starting with **Editing** (which window):

- **Window:** Show Window, Status, Meter, Fight, Width, Rows, Row Height,
  Spacing, Padding, Show, Opacity, Click Through, Copy Style to All Windows,
  Reset to Defaults, Reset All Data.
- **Bars:** Foreground, Background, Bar Opacity, Background Opacity, Bar
  Color, Custom Color, Other Color, Icon, Always Show Me.
- **Text:** Font, Outline, Slug Text, Text Shadow, Name Size, Text Inset, Name
  Color, Text Color, Show Rank, Show (numbers), Value Size, Show Percent.
- **Header:** Show Header, Height, Text Size, Header Color, Header Opacity,
  Title Color, Uppercase Title, Show Fight, Show Timer.
- **Frame:** Border, Border Size, Border Color, Background Color, Background
  Opacity.

Copy Style copies everything except what each window shows and when: Show
Window, Meter, Fight and Show. Reset to Defaults keeps those too.

## Saved settings

`ModeUIDB` profile `modules.damageMeters`, version 1: `window1`, `window2` and
`window3`, each a full style table (`Init.lua`'s `Style`). Positions are under
`positions.damageMetersWindow1` to `3`. `Initialize` fills defaults and
validates every key, range, color, choice and texture. Bad data stops startup;
it is never reset.

## Files

| File | Job |
|---|---|
| `Shared/Domain/DamageMeter.lua` | guarded `C_DamageMeter` reads, meter types, sessions, spells, class atlases, clock text |
| `Shared/Kit/Shape.lua` | `Kit.Rim`, `Kit.PlaceRim`: the hollow pixel rim |
| `Init.lua` | declaration, windows, positions, colors, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: validation |
| `Driver.lua` | lifecycle, events, the render throttle (4 a second, timer every 0.5s in combat), show rules, settings changes |
| `Layout.lua` | pixel geometry |
| `Window.lua` | building and painting windows, rows and stand-ins |
| `Render.lua` | filling rows: bars, names, numbers, icons, header, empty text, scrolling |
| `Menu.lua` | the header menu |
| `Breakdown.lua` | the spell breakdown and Death Recap |
| `Preview.lua` | the sample fight, the settings preview, Test on Screen |
| `Settings.lua` | the settings page |

Tests: `tests/damage_meters.lua` stubs `C_DamageMeter`. In combat every amount,
name, GUID and spell is a `Secret()` that errors on arithmetic, comparison,
concatenation or measurement, and the stub refuses secret arguments.

## Not in this version

- Bar sliding animation (the 12.0 interpolation argument of `SetValue`).
- Reports to chat.
- Absorbs as its own meter: Blizzard's menu doesn't offer it, and Healing Done
  includes absorbs.
- Classification icons (elite, rare): Forever's meter turns them off too.

## Manual check

1. **Game meter on**
   - **Navigation:** the game's own options, its **Damage Meter** setting. A
     Midnight guide puts it under Gameplay Enhancements; confirm the label on
     Forever.
   - **Action:** turn it on.
   - **Required state:** out of combat.
   - **Confirmation:** in ModeUI, **Interface** › **Damage Meters** › **Window**
     tab, **Status** no longer says the option is off.
2. **Windows**
   - **Navigation:** `/modeui`, then **Interface** › **Damage Meters** in the
     sidebar.
   - **Action:** turn the module on with the switch in the page header. Fight a
     target dummy or a mob.
   - **Required state:** in combat, then out of it.
   - **Confirmation:**
     - During the fight, **Window 1** fills with class-colored bars and
       "1. Name" and "12.3K (1.2K)" text, and the header timer counts up.
       There are no Lua errors.
     - Within 3 seconds after the fight, **Show Percent** (Text tab) adds the
       share.
3. **Breakdown**
   - **Navigation:** the window on screen.
   - **Action:** click your row during a fight, then again after it.
   - **Required state:** in combat, then out of it.
   - **Confirmation:** in combat, the panel says "Spell details show after
     combat." for other players. Afterwards it lists spells with icons, and
     clicking its header closes it.
4. **Menu**
   - **Navigation:** the window on screen.
   - **Action:** click the header, pick **DPS**. Click the header again, pick an
     earlier fight, then **Reset All Data**.
   - **Required state:** any.
   - **Confirmation:**
     - The title reads "DPS", with per-second numbers first.
     - The earlier fight's name and length show in the header.
     - Reset empties the window: "No data yet."
5. **Placement**
   - **Navigation:** **Edit Mode** in the settings window header.
   - **Action:** turn on **Show Window** for Window 2 (Window tab, **Editing**:
     Window 2), then drag Window 1 and nudge it with the arrows.
   - **Required state:** out of combat.
   - **Confirmation:**
     - Both windows show a sample fight under cyan stand-ins named "Window 1"
       and "Window 2".
     - Window 2 follows Window 1.
     - After `/reload` they stay put.
6. **Pixel check**
   - **Navigation:** **Global** › **Optimizations**, UI Scale Pixel Perfect (or
     the game's own scale).
   - **Action:** look at a window's rim, divider and bar edges up close.
   - **Required state:** any.
   - **Confirmation:**
     - The 1px rim and divider are one crisp pixel, never blurred or doubled.
     - Rounded corners miss exactly one pixel.
