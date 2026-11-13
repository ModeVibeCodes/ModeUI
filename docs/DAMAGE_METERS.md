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

**Header buttons** (Header › Header Buttons, on by default) sit at the
header's right, right to left: the lock, Reset All Data, and the fight. The
fight button shows where the window is without spelling it out: just the
character, in the Mode cyan (no box): **C** for Current Fight, **O** for
Overall, or an earlier fight's number in the menu's list. It turns white under
the mouse. Clicking it switches Current and Overall; right-clicking opens the
menu.
The glyphs (`Media/Textures/DamageMeters`, from `tools/build_shape_textures.lua`)
are 16 physical pixels when the header has room, so they draw one to one at
any UI scale. Each shows its name on hover.

## Lock, moving and resizing

**Lock Window** (Window tab, or the lock button) is off by default. Unlocked,
outside combat and outside Edit Mode:

- **Dragging a header** moves the window. A grouped window moves its whole
  group. The drop is saved the way Edit Mode saves it: an offset from the
  window's anchor, on whole pixels, so a window anchored to another stays
  anchored.
- **The grip** (three diagonal lines, faint until hovered) sits in the corner
  that grows. Width follows the cursor and **Rows** change a whole row at a
  time. The first resize pins the window by its top-left corner to the screen,
  so that corner stays put. A window grouped above another has its grip at the
  top right and grows upward. Windows placed on the resized one through Edit
  Mode anchoring (Window 2 above Window 1 by default, and Window 3 above 2)
  take its width too, so a stack stays one width. They keep their own rows.
  Grouped windows share the width anyway.

Combat hides the grip and ignores drags. Click Through windows can't be moved
or resized by hand.

## Groups

Window tab › **Group With**: None, or another window. A grouped window stacks
**Below** or **Above** that window (Side), **Gap** apart (2px by default), and
takes every shared setting from the window at the head of its group: width,
bars, text, header, frame, Show, opacity and the lock. It keeps its own
**Meter**, **Fight** and **Rows**, so a group grows up or down one window at a
time. Changing a shared setting on any window of a group saves it on the head,
so the whole group changes. Groups can chain (Window 3 on 2 on 1) but never
loop. The choices leave out windows that would make a loop, and saved data
with a loop is refused.

A grouped window has no Edit Mode stand-in of its own. It hangs from the window
it follows, so moving the head moves the group. Its own saved place is kept, and
it returns there when it leaves the group.

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
| Header | 20px Onyx bar: Mode Gradient in the Unit Frames health color (#1C1E21) | Header › Texture, Height, Header Color, Header Opacity |
| Title | 11, uppercase, Mode cyan, outlined | Text › Title; Header › Uppercase Title |
| Header buttons | fight, Reset, lock; 16px glyphs | Header › Header Buttons |
| Timer | 11, #B9B9B9, outlined, left of the buttons | Text › Timer; Header › Show Timer, Show Fight (adds the fight's name) |
| Divider | 1px in the rim color | shown when there is a header and a rim |
| Padding | 1px | Window › Padding |
| Rows | 8 rows, 18 high, 1 apart, 240 wide | Window › Width, Rows, Row Height, Spacing |
| Icon | square class icon, 1px gap | Bars › Icon |
| Bar | Mode Gradient, class colored | Bars › Foreground, Bar Opacity, Bar Color (Class or Custom), Other Color |
| Empty bar | Flat, Onyx track at 25% | Bars › Background, Background Opacity |
| Name, Value | Expressway 12, pure white, outlined, crisp shadow, 4px in | Text › Name or Value: Font, Size, Outline, Slug Text, Text Shadow, Color (Color or Class), Text Color; Text Inset |

Each text (Name, Value, Title, Timer) has its own font, size, outline, shadow,
slug and color (`nameFont`, `valueOutline`, `timerColor`...). Names and values
can take the class color instead (Class Colors' custom colors apply). Text is
outlined and names are pure white by default, so they read on any bar color.
The owner found gray text hard to read on a bright rogue-yellow bar. Rounded
leaves out each corner's outermost pixel (`Kit.Rim`/`Kit.PlaceRim`, shared).
**Other Color** (#78808C) is for anything without a class, like pets and
creatures.

Numbers: **Amount** shows one number. **Amount and Per Second** (the default)
adds the other. **Decimals** (None, 1, 2 or 3; None by default) sets the places
after K, M, B and T: "5K", "5.4K", "5.43K", "5.432K". Numbers under a thousand
are whole ("179", never "179.87417218543"), and so are counts. **Separator**
joins the amount, the other amount and the percent: ( ) "5K (179, 61%)", /
"5K / 179 / 61%", | (written "||" in text, since a lone "|" starts an escape
code), ·, -, comma or two spaces.
`Kit.ShortNumber` builds `AbbreviateNumbers` breakpoints for this, so it works
on secret amounts too (see API_COMPATIBILITY.md). DPS and HPS lead with the per-second amount.
Interrupts and Dispels have no per-second amount. **Show Percent** adds the
share after the fight. **Show Rank** puts "1." before the name.

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
bars or frame opens the Header, Bars or Frame tab. Clicking a name, a value or
the title opens the Text tab on that text.

The sample group is Forever's nine classes plus a creature. One row is marked as
you, for Always Show Me. Healing meters rank the healers first.

## Settings page

**Editing** sits at the top right of the preview, as on the Action Bars page,
and names each window with its meter ("Window 1 - DPS"). Five tabs:

- **Window:** Show Window, Status, Meter, Fight, Width, Rows, Row Height,
  Spacing, Padding, Show, Opacity, Lock Window, Click Through, Group With,
  Side, Gap, Copy Style to All Windows, Reset to Defaults, Reset All Data.
- **Bars:** Foreground, Background, Bar Opacity, Background Opacity, Bar
  Color, Custom Color, Other Color, Icon, Always Show Me.
- **Text:** Text (Name, Value, Title, Timer), then that text's Font, Size,
  Outline, Slug Text, Text Shadow, Color (names and values: Color or Class) and
  Text Color; Text Inset, Show Rank; Show (numbers), Decimals, Separator, Show
  Percent.
- **Header:** Show Header; Texture, Height, Header Color, Header Opacity;
  Uppercase Title, Show Fight, Show Timer, Header Buttons, and buttons that open
  the Title and Timer text settings.
- **Frame:** Border, Border Size, Border Color, Background Color, Background
  Opacity.

Copy Style copies everything except what each window shows and when, and its
group: Show Window, Meter, Fight, Show, Group With, Side and Gap. Reset to
Defaults keeps those too. On a grouped window, every tab says which window the
group shares its settings with. Copy Style and Reset act on the group's head.

## Saved settings

`ModeUIDB` profile `modules.damageMeters`, version 3: `window1`, `window2` and
`window3`, each a full style table (`Init.lua`'s `Style`). Positions are under
`positions.damageMetersWindow1` to `3`. `Initialize` fills defaults and
validates every key, range, color, choice, texture and group (no window grouped
with itself, no loops). Bad data stops startup; it is never reset.

Version 1 → 2: text still at version 1's gray (#D4D4D4) turns white and
outlined, and the header text drops the fight's name, which is now on its
button. A chosen text color stays as it was. New settings take their defaults:
Decimals 1, Lock Window off, Group With None (Below, 2px), Header Buttons on.

Version 2 → 3: the shared Font, Text Shadow and Slug Text go to all four texts,
and Text Color goes to values. The owner asked for outlined text and pure white
names, so every text gets Outline and names get white. Name Color's "Text
Color" becomes "Color". Decimals still at version 2's default (1) becomes None.
A header still at version 2's #141518 takes the Onyx health color, and Texture
takes Mode Gradient. The old shared keys are removed.

## Files

| File | Job |
|---|---|
| `Shared/Domain/DamageMeter.lua` | guarded `C_DamageMeter` reads, meter types, sessions, spells, class atlases, clock text |
| `Shared/Kit/Shape.lua` | `Kit.Rim`, `Kit.PlaceRim`: the hollow pixel rim |
| `Shared/Kit/Text.lua` | `Kit.ShortNumber(value, decimals)`: abbreviated numbers with set decimals, secret-safe |
| `Init.lua` | declaration, windows, positions, colors, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: validation, the version 2 migration, group loops |
| `Group.lua` | groups: the head of a group, the settings a window draws with, where a grouped window hangs |
| `Driver.lua` | lifecycle, events, the render throttle (4 a second, timer every 0.5s in combat), show rules, settings changes |
| `Layout.lua` | pixel geometry |
| `Window.lua` | building and painting windows, rows and stand-ins |
| `Controls.lua` | header buttons, the lock, moving by the header, resizing by the grip |
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
6. **Decimals, buttons, lock and resizing**
   - **Navigation:** the window on screen, and **Interface** › **Damage Meters**
     › **Text** tab.
   - **Action:**
     - Set **Decimals** to None, 1, 2 and 3, and try each **Separator**.
     - Click the **C** button, then right-click it.
     - Click the lock.
     - Unlock, drag the header, then drag the grip in the bottom-right corner.
   - **Required state:** out of combat, after a fight.
   - **Confirmation:**
     - Numbers read "5K", "5.4K", "5.43K" and "5.432K", and small per-second
       numbers are whole.
     - The separators read "5K (179)", "5K / 179" and "5K | 179" (one bar).
     - **C** becomes **O** (Overall), and right-click lists the fights.
     - Locked, the grip disappears and the header no longer drags.
     - Unlocked, the window moves, and the grip changes width and whole rows
       with the top-left corner fixed. After `/reload` the place and size stay.
7. **Groups**
   - **Navigation:** **Window** tab, **Editing**: Window 2.
   - **Action:**
     - Turn on **Show Window**, set **Group With** to Window 1 and **Side** to
       Below.
     - Change **Rows**, then Width.
     - Drag Window 1's header.
   - **Required state:** out of combat.
   - **Confirmation:**
     - Window 2 sits 2px under Window 1, matches its width, text and look, and
       keeps its own meter.
     - Rows change only Window 2. Width changes both.
     - Dragging moves both.
     - **Group With**: None puts Window 2 back where it was.
8. **Pixel check**
   - **Navigation:** **Global** › **Optimizations**, UI Scale Pixel Perfect (or
     the game's own scale).
   - **Action:** look at a window's rim, divider and bar edges up close.
   - **Required state:** any.
   - **Confirmation:**
     - The 1px rim and divider are one crisp pixel, never blurred or doubled.
     - Rounded corners miss exactly one pixel.
