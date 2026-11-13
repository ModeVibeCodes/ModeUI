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

ModeUI **hides Blizzard's meter window but never writes into it**. One meter
author reported that writing into Blizzard's windows taints their refresh and
makes them log errors in combat. **Hide Blizzard's Meter** (Window tab › Data,
on by default) puts Blizzard's meter frame (`DamageMeter`, which holds its
session windows and their breakdowns) under a hidden ModeUI frame while the
module is on. Nothing in it is changed or called, and it keeps running, so it
keeps recording. Switching the setting or the module off puts it back where it
was. The game only records while its own **Damage Meter**
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
  anchored. Windows anchored on it in Edit Mode follow it during the drag: its
  stand-in rides on the window's corner until the drop.
- **The grip** (three diagonal lines, faint until hovered) sits in the corner
  that grows. Width follows the cursor and **Rows** change a whole row at a
  time. The first resize pins the window by its top-left corner to the screen,
  so that corner stays put. A window grouped above another has its grip at the
  top right and grows upward. Windows anchored on the resized one in Edit
  Mode with **Match Width** (Window 2 above Window 1 by default, and Window 3
  above 2) take its width too, so a stack stays one width. They keep their own
  rows. Grouped windows share the width anyway. A matched window's grip
  changes only its rows (and nothing, with Match Height on too).

Combat hides the grip and ignores drags. Click Through windows can't be moved
or resized by hand.

## Groups

Window tab › **Group With**: None, or another window. A grouped window stacks
**Above** (the default) or **Below** that window (Side), **Gap** apart (2px by
default), and
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
| Border | ModeUI's standard border, as on the unit frames' health bar: one crisp 2px rim in Onyx #40454C (`Kit.BORDER_COLOR`), round corners as deep as a bar the header's height would round (6px by default), above what the window holds | none: the border is locked, like the unit frames' rim |
| Background | the Unit Frames' default health color (Onyx #1C1E21) at 75% (#040404 until settings version 5, which moves a background still at it) | Frame › Background Color, Background Opacity |
| Header | 20px Onyx bar: Mode Gradient in the Unit Frames health color (#1C1E21) | Header › Texture, Height, Header Color, Header Opacity |
| Title | 11, uppercase, Mode cyan, outlined | Text › Title; Header › Uppercase Title |
| Header buttons | fight, Reset, lock; 16px glyphs | Header › Header Buttons |
| Timer | 11, #B9B9B9, outlined, left of the buttons | Text › Timer; Header › Show Timer, Show Fight (adds the fight's name) |
| Hairline | 1px black under the header, like a unit frame's between health and power | shown with the header |
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
The owner found gray text hard to read on a bright rogue-yellow bar.

The border (owner, November 13, 2026: "the new standard border... refer to
unit frames health bar border") is `Kit.ModeBoxBorder` (`Shared/Kit/Border.lua`),
the standard border's rounded-rectangle form for boxes taller than a bar.
`Kit.ModeBorder`'s rounded ends are a quarter of the box's height deep, which
suits a bar but would turn a 180px window's sides into ovals. So the box form
keeps the same rim and color and rounds only the corners, with the same art:
the top and bottom quarters of the cap textures are quarter circles. Its
corners are as deep as `Kit.CapDepth` makes a bar of the header's height plus
the rim (a row's height without a header), so the header rounds exactly like
a bar. Like the unit frames, the background reaches 1px under the rim, and
the corner masks round the background, header and rows that reach a corner.
The resize grip sits clear of the corner. The spell breakdown and the
settings preview use the same shell, so they get the same border.
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
stand-in; its handle, centered above it, names it ("Window 1"). The windows show a sample fight so they
can be laid out without one. Window 1 sits on the right edge below the middle.
Windows 2 and 3 stack above it by default, and a window can anchor to a window
listed before it. Position Manager moves the stand-in (it drives the mouse on
what it registers), and the window hangs from the stand-in's top-left corner.

**Anchoring** (the Edit Mode window, for every module's elements): choosing a
target under **Snap To UI Element**, a side, or **Reset Offset** puts X and Y
back at 0, so the element sits right on that side of its target. Before, a new
target kept the old offsets, which were measured from the old anchor: the
owner's Window 2 went off the screen that way. Choosing Screen keeps an element
where it is. **Anchor To...** (beside the target list) waits for a click on the
element to hang from. What a click would pick is outlined and named at the top
of the screen; Escape, a right-click or combat cancels, and nothing drags
meanwhile. The element goes Above what was clicked at 0, 0, and a small window
offers the sides: a compass of Above, Below, Left, Right and Center, its
corners lining up edges (Above, left edges together...), with **Done** and
**Undo**. Something that already hangs from the element is never offered, so
anchors never loop (`PositionManager:WouldLoop`). Code:
`PositionManager:AnchorTo` (`Shared/Placement/PositionAnchors.lua`) and
`Shared/Settings/EditAnchor.lua`.

**Match Width** and **Match Height** (Edit Mode window, under the sides) size
an anchored element to what it hangs from. A module offers them for its
elements (`PositionManager:SetSizeMatch`); they're dimmed on the screen and
for elements that don't. Damage meter windows have both. **Match Width** is on
by default: the window takes its anchor's width whenever that changes (its
grip, its Width setting, Copy & Apply, or a different frame changing size),
and its Rows stay its own. Before, only the grip passed the width on, so the
owner's Window 2 came apart from Window 1 when Window 1's size changed some
other way. **Match Height** (off by default) gives the window as many rows as
fit its anchor's height. On another meter window the match reads that
window's settings, so it lands on the same refresh; on any other frame it
reads its size on screen, watched by Position Manager's anchor size listener.
The Window tab says when Width (or Rows) follow an anchor.

**Test on Screen** shows the sample fight on the real windows. The settings page
preview is the window being edited, drawn by the same code, with the sample
fight: at most five rows, at 80% size at most, so it stays small whatever
Rows is set to. **Animated** plays it out over 20 seconds. Clicking the preview's header,
bars or frame opens the Header, Bars or Frame tab. Clicking a name, a value or
the title opens the Text tab on that text.

The sample group is Forever's nine classes plus a creature. One row is marked as
you, for Always Show Me. Healing meters rank the healers first.

## Settings page

**Editing** sits at the top right of the preview, as on the Action Bars page,
and names each window with its meter ("Window 1 - DPS"). Six tabs:

- **Window:** Show Window, Status, Meter, Fight, Width, Rows, Row Height,
  Spacing, Padding, Show, Opacity, Lock Window, Click Through, Group With,
  Side, Gap, Reset All Data, Hide Blizzard's Meter.
- **Bars:** Foreground, Background, Bar Opacity, Background Opacity, Bar
  Color, Custom Color, Other Color, Icon, Always Show Me.
- **Text:** Text (Name, Value, Title, Timer), then that text's Font, Size,
  Outline, Slug Text, Text Shadow, Color (names and values: Color or Class) and
  Text Color; Text Inset, Show Rank; Show (numbers), Decimals, Separator, Show
  Percent.
- **Header:** Show Header; Texture, Height, Header Color, Header Opacity;
  Uppercase Title, Show Fight, Show Timer, Header Buttons, and buttons that open
  the Title and Timer text settings.
- **Frame:** Background Color, Background Opacity (the border is locked).
- **Copy & Apply:** Copy From (the window in Editing), **Copy** (All, Window,
  Bars, Text), Apply To (tick windows), **Apply to Selected**, **Apply to All
  Windows**, Reset to Defaults.

Copy & Apply copies by part (`M.copyScopes`):
- **All:** everything except what each window shows and when, its group and
  matching (Show Window, Meter, Fight, Show, Group With, Side, Gap, Match Width
  and Match Height).
- **Window:** the window with its header and border: Width, Padding, Opacity,
  Background Color, Background Opacity, and
  the header's Show Header, Texture, Height, Color, Opacity, Uppercase Title,
  Show Fight, Show Timer and Header Buttons.
- **Bars:** Row Height, Spacing, Foreground, Background, both opacities, Bar
  Color, Custom Color, Other Color, Icon and Always Show Me.
- **Text:** every text's Font, Size, Outline, Shadow, Slug and Color, Name and
  Value color modes, Text Inset, Show Rank, Show (numbers), Decimals,
  Separator and Show Percent.

Every copy is checked before it's kept. A grouped window takes it on its
group's head, so the whole group changes. Reset to Defaults keeps the same keys
as All leaves alone. On a grouped window, every other tab says which window
the group shares its settings with.

## Saved settings

`ModeUIDB` profile `modules.damageMeters`, version 6: `window1`, `window2` and
`window3`, each a full style table (`Init.lua`'s `Style`), and `hideBlizzard`
(Hide Blizzard's Meter, for the whole module). Each window also has
`matchWidth` (on) and `matchHeight` (off), Edit Mode's Match Width and Match
Height; older saves take those defaults. Positions are under
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

Version 3 → 4: groups stack Above by default. The owner grouped Window 2 with
Window 1, it went below and off the screen, and they asked for the top. Every
window still on version 3's default (Below) turns Above. Hide Blizzard's Meter
takes its default (on).

Version 4 → 5: a background still at #040404 takes the Unit Frames' health color.

Version 5 → 6: the window takes ModeUI's standard border, which has no
settings, so `border`, `borderSize` and `borderColor` are removed.

## Files

| File | Job |
|---|---|
| `Shared/Domain/DamageMeter.lua` | guarded `C_DamageMeter` reads, meter types, sessions, spells, class atlases, clock text |
| `Shared/Kit/Shape.lua` | `Kit.Rim`, `Kit.PlaceRim`: the hollow pixel rim |
| `Shared/Kit/Text.lua` | `Kit.ShortNumber(value, decimals)`: abbreviated numbers with set decimals, secret-safe |
| `Init.lua` | declaration, windows, positions, colors, defaults, ranges, choices |
| `Migrations.lua` | `Initialize(db)`: validation, the migrations, group loops |
| `Group.lua` | groups: the head of a group, the settings a window draws with, where a grouped window hangs; Match Width and Match Height |
| `Driver.lua` | lifecycle, events, the render throttle (4 a second, timer every 0.5s in combat), show rules, settings changes |
| `Layout.lua` | pixel geometry |
| `Window.lua` | building and painting windows, rows and stand-ins |
| `Controls.lua` | header buttons, the lock, moving by the header, resizing by the grip |
| `Render.lua` | filling rows: bars, names, numbers, icons, header, empty text, scrolling |
| `Menu.lua` | the header menu |
| `Breakdown.lua` | the spell breakdown and Death Recap |
| `Blizzard.lua` | Hide Blizzard's Meter: Blizzard's meter frame under a hidden frame, and back |
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
     - With Window 2 shown (anchored on Window 1), it moves along during the
       drag, not only after the drop.
7. **Groups**
   - **Navigation:** **Window** tab, **Editing**: Window 2.
   - **Action:**
     - Turn on **Show Window** and set **Group With** to Window 1 (**Side**
       is Above by default).
     - Change **Rows**, then Width.
     - Drag Window 1's header.
   - **Required state:** out of combat.
   - **Confirmation:**
     - Window 2 sits 2px above Window 1, matches its width, text and look, and
       keeps its own meter. **Side** Below puts it 2px under.
     - Rows change only Window 2. Width changes both.
     - Dragging moves both.
     - **Group With**: None puts Window 2 back where it was.
8. **Pixel check**
   - **Navigation:** **Global** › **Optimizations**, UI Scale Pixel Perfect (or
     the game's own scale).
   - **Action:** look at a window's border, the hairline under the header and
     the bar edges up close, next to the Player frame's health bar.
   - **Required state:** any.
   - **Confirmation:**
     - The border is the same 2px Onyx rim as the health bar's, crisp, never
       blurred or doubled, and the hairline is one black pixel.
     - The corners are round and even, with no gap or seam between the rim and
       the background, header or bars inside it.
     - The resize grip sits inside the bottom-right corner's curve.
9. **Anchor To**
   - **Navigation:** **Edit Mode** in the settings window header.
   - **Action:**
     - Turn on **Show Window** for Window 3 first (Window tab, **Editing**:
       Window 3).
     - Click Window 3's stand-in, then **Anchor To...** in the ModeUI Edit Mode
       window, then Window 1.
     - In the window that opens, click the compass's bottom-left button, then
       **Done**.
     - Pick **Screen** in **Snap To UI Element**, drag Window 3 away, and choose
       Window 1 in the same list.
   - **Required state:** out of combat, Window 1 shown.
   - **Confirmation:**
     - While waiting, Window 1 is outlined when the mouse is over it and the
       top of the screen names it.
     - The click puts Window 3 right on top of Window 1, and **X Position** and
       **Y Position** read 0.
     - The compass moves it under Window 1 with the left edges together.
       **Undo** would have put it back.
     - Choosing Window 1 from the list also puts it on top at 0, 0, never off
       the screen.
10. **Blizzard's meter hidden**
    - **Navigation:** **Interface** › **Damage Meters** › **Window** tab, **Hide
      Blizzard's Meter** under Data.
    - **Action:** with the game's Damage Meter option on, turn the module on,
      fight, then switch **Hide Blizzard's Meter** off and on.
    - **Required state:** any; switching works in combat too.
    - **Confirmation:**
      - With it on, Blizzard's meter windows are gone and ModeUI's still fill
        during the fight.
      - Off, Blizzard's windows come back where they were, with the same
        numbers. Turning the module off brings them back too.
      - No Lua errors, including in Blizzard's own Edit Mode.
11. **Match Width and Match Height**
    - **Navigation:** **Edit Mode** in the settings window header, then
      **Interface** › **Damage Meters**.
    - **Action:**
      - With Window 2 shown and anchored on Window 1 (its default), select
        Window 2's stand-in.
      - In the ModeUI Edit Mode window, check that **Match Width** is ticked,
        then leave Edit Mode.
      - Change Window 1's **Width** on the Window tab, then drag its grip.
      - Tick **Match Height** for Window 2 in Edit Mode.
    - **Required state:** out of combat; Window 2 not grouped.
    - **Confirmation:**
      - Window 2 stays exactly as wide as Window 1 both ways, keeps its own
        rows, and never comes apart from it.
      - The Window tab, with Editing on Window 2, says its Width follows
        Window 1.
      - Match Height gives Window 2 Window 1's height in whole rows.
      - On Window 1 itself (anchored on the screen) both are dimmed.
12. **Copy & Apply and the preview**
    - **Navigation:** **Interface** › **Damage Meters** › **Copy & Apply** tab.
    - **Action:**
      - With Editing on Window 1, set **Copy** to Text, tick Window 2 and click
        **Apply to Selected**.
      - Then try Window and Bars.
      - Set Window 1's **Rows** to 20 and look at the preview.
    - **Required state:** any.
    - **Confirmation:**
      - Text copies only fonts and numbers. Window brings the width, border and
        header. Bars brings the bar look.
      - The line beside the buttons says how many windows changed.
      - The preview stays at five rows and a smaller size.
