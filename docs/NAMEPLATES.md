# Frames: Nameplates

November 12, 2026. Second module ModeUI built; in the **Frames** category since November 13. Off by default
(turn it on with the switch in the page header; the Mode-Default layout turns it on). Static/mock validated only;
**native acceptance is pending** for the latest changes. APIs and their
secret-value rules are in [API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-nameplates--november-12-2026)
and its "Nameplates pass" section.

The **nameplates pass** (November 23, 2026) is the owner's baseline and the
anchoring rework. It came from the Nameplate Designer artifact
(https://claude.ai/artifact/Y6qEMQnZHXYkGaQKu5ca9F; source `design/nameplates/`).

## The baseline (defaults)

Enemy plates:
- **Plate:** a 156 × 16 health bar.
- **Name:** **On Border** at the top left, 13px, 3px into the rim.
- **Your debuffs:** on the same border line at the top right, growing left,
  up to 4, 24 × 20. The name stops where they start and flexes with them.
- **Crowd control:** above that line, centered, up to 2, 35 × 31 (1.5×),
  with the crowd control rim and glow.
- **Buffs:** beside the bar on the right, growing right, up to 3, 22 × 18
  (as tall as the health box).
- **Quest icon:** beside the bar on the left, 18px.
- **Inside the bar:** the raid marker in the middle; the level, then the
  elite icon, on the left; health % on the right.
- **Cast bar:** 12px, 1px below the bar. It is light blue when you can
  interrupt and orange-red when you can't; channels are green. The icon is on
  the left and the spell name on the left; the timer is on the right, with the
  cast target just left of it.
- **Combo points:** below, centered. They sit under the cast bar while a cast
  shows and under the health bar otherwise (**Move Up While Not Casting**).
- **Target:** arrows on both sides, always the outermost part.
- **Soft-target icon:** the loot and interact icon (a bag or gear) above
  everything; no combat icon.
- **Text** (owner, November 24, 2026): the name is in the light text color,
  since the bar already shows the reaction. The name and the health text each
  wear a tight **Ink** halo, a dark ring 1px round the letters, so they read
  over the bar and the world. Plates keep **one size at any distance**, so
  their text and 1px lines stay on whole screen pixels.

Friendly plates are **Name Only**: players in their class color, friendly NPCs
in the friendly color, with the same Ink halo, no auras.

## What it draws

On every nameplate the game gives to addons, ModeUI parents its own plain
frame and fades Blizzard's art. Each plate has:

- **Health and cast boxes:** the bar inside the `frameThin` edge, in each
  kind's **Border** and **Border Metal** (Mode-Border by default). The rim art
  sits outside the bar and covers its own corners, so nothing is masked. Each
  ring is drawn in pieces (DESIGN_LANGUAGE.md, "Pieces"). Health fills in
  **Mode-FG** on Mode-BG at 85%; the cast bar has its own **Cast Bar** texture
  and the **Comet** spark on the fill's leading edge (a channel's on its left),
  hidden while an interrupted cast is held.
- **Name** in SemiBold: on enemy plates in the Text Color by default, on
  friendly ones in the class or reaction color (Gradient is the third
  option). **Health text** (Percent, Current Health, Current and Percent,
  None) in Bold, colored **By Health** or in the Text Color.
- **Text halos** (`Style.TextHalo`): **Name Text Glow** and **Health Text
  Glow** draw eight copies of the text 1px out in every direction, in Ink
  (Deep and Match Text are options) at 60% each. A glowing text drops its
  shadows; the halo takes their place. The copies take every write the text
  takes, secret names and numbers included, and the name's copies are made
  inside its holder, so they carry the holder's forbidden aspect.
- **Same Size at Any Distance** (on by default, both kinds): the game scales
  each nameplate by distance and grows your target's, which put the plate's
  1px rims, shadows and halos between screen pixels and blurred its text. With
  it on, the plate ignores its nameplate's scale (`SetIgnoreParentScale`) and
  takes the scale of the nameplate's parent, the scale a full-size nameplate
  has.
- **Health color:** Reaction and Class, Reaction, Onyx or Custom, used exactly
  as they are. **Threat Colors** (enemies) gives each threat status its own
  color: **Has Aggro**, **Losing Aggro**, **Close to Pulling**.
- **Health Opacity** fades the fill; **Background Opacity** fades only the
  empty part of the bar.
- **Cast bar** (every Mode cast bar, owner, November 23, 2026): **Interruptible**
  light blue (`Style.Tone.cast.casting`), **Not Interruptible** orange-red,
  **Channel** green, **Interrupted** red. Channels drain from right to left. An
  interrupted cast stays a second, full, then fades.
  - **Spell Icon:** Left, Right, Outside Left, Outside Right or None.
  - Texts: **Spell Name**, **Cast Target** (the spell's own target where the
    client gives it, else who the caster is targeting, in its class color) and
    **Timer**.
  - Inside on the right, the timer and the target line up from the bar's edge
    inward, and the spell name stops 4px short of them. Each is anchored to the
    next, so secret text is never measured.
- **Indicators:** a quest icon, Blizzard's elite, rare elite, rare and boss
  icons, and the level in its difficulty color.
- **Soft Target Icon:** the cursor the game shows over your soft target, above
  everything on the plate. By default only the loot and interact icon (a bag,
  gear). **Show Combat Icons** adds the sword on soft enemies and friends.
  **Hide Blizzard's Combat Icon** (opt-in, for every kind) turns the game's own
  enemy and friend icons off (`SoftTargetIconEnemy`, `SoftTargetIconFriend`),
  remembers what they were and restores them when turned off or when the
  module is (`BlizzardIcons.lua`).
- **Auras** in three groups, the **raid marker**, the **target indicator**,
  **combo points** and the **focus** highlight.

**Name Only** (the Style choice) draws just the name, centered, in the class
color for players or the reaction color otherwise. It has no bars, no cast bar
and no auras.

## Placement

Every part has an **anchor**, read like a compass around the health bar, and
an Offset X and Y. The plate is built outward from the bar (`Layout.lua`,
`Stacks.lua`):

1. **The spine:**
   - **The border line:** aura groups set to **Sit on Border** and a name
     placed **On Border** share one line right on the bar's edge. An On Border
     name stops at the inner edge of a border row on the same line (Top Right
     or Top for a name on the left), so the game shortens it with "…" only
     while auras need the room.
   - The cast bar, **Below** or **Above**, with its outside texts.
   - One text line for a name or health text placed outside on Top or Bottom.
2. **Stacks:** past the spine, each anchor point holds an **aura row** and a
   **part row** (the raid marker, the indicators, the combo points).
   - Part row order, from the bar outward: marker, quest, elite and rare,
     level, combo points. Inside the bar, from its edge inward, the order is
     level, elite and rare, quest, marker.
   - A part that shows nothing takes no room, so the rest close up toward the
     bar.
   - **On One Anchor:** with **Auras First** (the default) the aura row sits
     nearest the bar and the part row follows its last icon; **Indicators
     First** puts the part row first and the aura row past it.
3. **Target arrows** are always the outermost part on each side, anchored to
   whatever comes last there.

| Anchor | Text (name, health text) | Markers, indicators, combo points | Aura groups |
|---|---|---|---|
| Top Left / Top / Top Right | on the border line (On Border) or above the spine | past the spine (or after the aura row) | past the spine, or on the border line (Sit on Border) |
| Left / Right | inside the bar | beside the bar, or inside it (**Inside the Bar**) | beside the bar |
| Center | inside the bar | inside the bar | — |
| Bottom Left / Bottom / Bottom Right | below the spine | below the spine | below the spine |

**Secret auras.** In the world, Blizzard's aura containers draw the rows and
size themselves to what they show. ModeUI may not read that size, so each row
keeps an **edge mark**: a 1x1 frame anchored to the container's far edge,
made from Blizzard's `DisableUntrustedLayoutScriptsTemplate`. A container
carries the forbidden aspect `UntrustedLayoutScriptExecution`, and the game
refuses to anchor anything to it or to its mark unless that thing carries the
aspect already: it is never inherited through `SetPoint` (owner's in-game error,
November 23, 2026).
- **Parts that follow a row's mark live in frames made from the template:**
  the name's holder (the name stops at the border row) and the arrows' frames.
  The game moves them as auras come and go.
- **A part row after an aura row** (Auras First) holds regions that can't
  carry the aspect, so in the world it sits past the aura row's full reach;
  the preview follows the mark.
- **Every anchor to a mark is guarded:** if the game refuses it, the part
  keeps clear of the row's full reach instead.
The soft-target icon clears the tallest Top stack from known heights (a row's
height is known, only its length is secret), so it stays still.

**Centered rows** are anchored by their own middle, so they stay centered as
they resize. With icon width + spacing even, a fixed half-pixel nudge keeps
every count on whole pixels.

**Layers.** Both boxes sit one frame level above the plate, each box's bar,
spark clip and rim the next three. Text, markers, indicators and combo points
are on the text layer (+10) and auras on the aura layer (+12), clear of every
rim. They are set again on every layout. This fixes parts inside the bar
sometimes drawing behind it.

## Mode-Default layout

`Layouts.lua` adds the nameplates' part of the built-in Mode-Default (DPS /
Tank) and Healer layouts: the module on. The baseline is every plate's
default, including Aura Spacing 1 (neighbours share one shadow pixel).

## Enemy and friendly plates

Every plate is an **enemy** plate (a unit you can attack) or a **friendly** one,
and each kind has its own full settings. **Use ModeUI Plates** turns ModeUI off
for one kind. A unit that changes sides switches kinds on `UNIT_FACTION`.
**Copy To…** and **Reset…** are in the settings footer (`SettingsActions.lua`).
Both ask first, and **Use ModeUI Plates** stays as it is.

## Auras

Three groups, in order: **Crowd Control**, **Debuffs**, **Buffs**. The game's own
aura filters decide what belongs to each, so secret aura data is never compared.

- **Every group:** **Show Auras**, **Timer Swipe**, **Stack Count**.
  - **Icon Shape:** **Mode** (the design language's rule: 4px shorter than
    wide up to 35, 6px from 36; the default), Cropped (6px shorter) or Square.
    Sizes include the 1px band.
  - **Rim Color** (By Type or Mode) and **Border Size**.
  - **Spacing:** 1 by default, the Cooldown Manager's look.
  - **Timer Text**, and **Crowd Control Glow** with **Glow Style**.
  - **On One Anchor:** Auras First or Indicators First.
- **Each group** (pick it with **Group**): **Show This Group**, **Sit on
  Border**, **Which**, **Anchor**, **Grow** (Right, Left, Up, Down, Center),
  **Offset X/Y**, **Icon Size** and **Most Shown**. Groups on the same anchor
  are one row, continuing in group order.

## Target indicator

**Style:** Border, Glow, Arrows (the enemy default), Border and Arrows, or
None, in a **Color** (Ivory). Arrows are always the outermost part on each
side and move in and out with what shows there (**Arrow Size**, **Arrow
Gap**).

## Combo points

Combo points you can track, on the plate of your target (`Combo.lua`), for
Rogues and Druids in Cat Form (`Domain.ClassResource`). One round socket per
point in a row that joins the stack on its anchor: **Bottom**, centered, by
default. With **Move Up While Not Casting** they sit under the health bar while
nothing is cast and under the cast bar while a cast shows. They are placed
again when the cast box shows or hides. The count may be secret, so each
socket is its own StatusBar that gets it through `SetValue`.

## Focus

Your focus target's plate has a **Highlight** (Border, Glow, Stripes or None)
in a **Color** (Rosewood), a **Focus Texture**, and **Other Plates Opacity**.

## Preview

The magnified previewer (owner, November 23, 2026; `PreviewStage.lua`):

- **State chips:**
  - the cast: No Cast, Casting, Can't Interrupt, Interrupted;
  - the highlight: Target, Focus, Neither;
  - auras: None, Some, Full (every group at Most Shown, its full reach);
  - friendly plates only: Player or NPC.
- **The stage:** the kind being edited, magnified (2x, less when its full
  reach can't fit, in quarter steps) and pixel snapped.
  - **The health bar stays in the middle across**, so an anchor change never
    slides the plate sideways.
  - Up and down, the plate's full reach is centered, from the layout and every
    row at Most Shown, so changing states never moves it.
  - The preview has a fixed height.
- **One plate** (owner, November 23, 2026: the strip of smaller plates was
  removed). Other states come from the chips, and the preview stays 230px
  tall.
- **Click any part** of the stage plate to jump to its settings.

The old preview estimated the plate's size with its own copy of the layout,
measured before painting, and re-centered the whole footprint. That is why it
used to drift off center.

## Settings page

The standard tabs under the **Editing** switch:

- **General:**
  - **Show**.
  - **Size**.
  - **Cast Bar**.
  - **Combo Points:** Anchor, **Move Up While Not Casting**, sizes, offsets.
  - **Indicators:** per indicator, Show, **Inside the Bar**, Anchor, size,
    offsets.
  - **Raid Marker:** Anchor, **Inside the Bar**, size, offsets
    (`SettingsParts.lua`).
  - **Soft Target Icon:** size, offsets, **Show Combat Icons**, **Hide
    Blizzard's Combat Icon**.
- **Fill:** Health Bar, Cast Bar (Interruptible, Not Interruptible,
  Interrupted, **Channel**), Combo Points, Focus.
- **Border:** Border, Aura Borders, Target, Aura Border Colors.
- **Glow:** Focus, Crowd Control, **Name Text** and **Health Text** (each a
  Glow switch, **Glow Color** and **Glow Strength**).
- **Text:**
  - Text Style.
  - **Name Text**, with **On Border**.
  - Health Text.
  - Cast Bar Text.
- **Auras:** Groups (with **Sit on Border**), Icons (Shape, **On One Anchor**,
  Spacing), Timer, Stacks.
- **Behavior:** **Size** (**Same Size at Any Distance**), Focus.

## What stays Blizzard's

- Where plates appear, their stacking, clicks and hit areas, and their
  scale while **Same Size at Any Distance** is off. The
  156-wide plate fits inside Blizzard's Forever click area, which is 166 wide
  at Medium.
- Friendly plates inside instances (forbidden to addons).
- Your personal resource display, and widget-only plates. Their soft-target
  icons, and the ones the game draws for objects itself, are Blizzard's.

Switching the module off gives every plate back to Blizzard. Plates are plain
frames, never secure, so they also work in combat. Settings change outside combat.

## Settings versions

**Version 13** (readable text, `MigrationsV12.lua`). Enemy names still in
Class or Reaction take the Text Color; a picked name color stays. The halo
keys and **Same Size at Any Distance** arrive with their defaults; a Health
Text Glow switched off stays off and now draws the halo when switched on.

**Version 12** (the nameplates pass, `MigrationsV12.lua`). A value still equal
to its version 11 default takes the baseline; anything picked stays. The new
switches keep a customized plate looking as it did:
- **On Border** is on only where the name was still at Top with no offset.
- **Inside the Bar** is on for the level and elite only where they were still
  at their default Left place.
- **Auras First** applies only where crowd control and debuffs were still at
  their default places.
- **Move Up While Not Casting** applies only where the combo points were
  still below.
- Cast colors still at the old amber and gray take light blue and orange-red.

Earlier versions:
- 11: semi-transparent empty bars.
- 10: the aura edge.
- 9: the Mode design language.
- 8: the no-type crowd control rim.
- 7: one place per indicator.
- 6: Color Softness retired.
- 5: placement, Name Only, target styles.
- 4: three aura groups.
- 3: auras.
- 2: one set of settings per kind.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, per-kind defaults (the baseline), ranges and choices |
| `Migrations.lua` | `Initialize(db)`: validation and the settings-version migrations |
| `MigrationsV12.lua` | version 11 → 12 and version 11's defaults (`M.V11`), version 12 → 13 |
| `Driver.lua` | lifecycle, events, enemy or friendly kind, fading Blizzard's unit frame, per-kind settings |
| `Plate.lua` | building a plate, laying out its boxes, Same Size at Any Distance |
| `Layout.lua` | layers, the spine (border line, cast bar, text lines), text placement and halos, the On Border name |
| `Stacks.lua` | stacks per anchor, edge marks, the arrows, the Top stacks' room, name stops |
| `Target.lua` | target indicator styles and name colors |
| `Indicator.lua` | the level, classification and quest indicators |
| `Focus.lua` | the focus highlight, focus texture and fading other plates |
| `Combo.lua` | combo points on the target's plate, following the target |
| `SoftTarget.lua` | the soft-target icon |
| `BlizzardIcons.lua` | Hide Blizzard's Combat Icon |
| `Update.lua` | health, name, colors, threat, raid marker |
| `CastBar.lua` | cast and channel bars, icon side, the inside text chain, target and timer |
| `Auras.lua` | aura groups, sizes, row origins, the reader's placement and edge marks |
| `AuraContainers.lua` | auras through Blizzard's secure custom aura containers, one per row, with their marks |
| `Preview.lua` | sample units, auras, casts and states; the preview's reach |
| `PreviewStage.lua` | the magnified previewer: chips, stage, strip |
| `Settings.lua`, `SettingsParts.lua` | the settings page |
| `SettingsActions.lua` | preview clicks (`JumpTo`) and the footer's Copy To… and Reset… scopes |

## Not in this version

- Class resources other than combo points.
- Fitting Blizzard's click and stacking areas to ModeUI's plate.

## Manual check

- **Navigation:** `/modeui`, then **Frames** › **Nameplates**.
- **Action:**
  - In the preview, click each chip: **Casting**, **Can't Interrupt**,
    **Interrupted**, **No Cast**, **Target**, **Focus**, **Neither**, **No
    Auras**, **Some**, **Full**. Switch **Editing** to Friendly and click
    **Player** and **NPC**.
  - On **Auras**, pick **Debuffs** and move **Anchor** between Top Right and
    Top; switch **On One Anchor** on **Icons**.
  - On **General**, in **Indicators**, turn **Inside the Bar** off and on for
    Level.
  - In the world, target a quest enemy with a long name, and apply your
    debuffs one at a time, in and out of combat.
  - Watch an enemy cast something you can interrupt and something you can't,
    and interrupt one.
  - As a Rogue, build combo points on an enemy, with and without a cast going.
  - Face a lootable corpse, then an enemy without targeting.
  - Look at a friendly player and a friendly NPC.
  - On **General**, in **Soft Target Icon**, turn **Hide Blizzard's Combat
    Icon** on, then off.
  - Look at an enemy over a busy background (grass, spell effects), near and
    far, then target it. On **Behavior**, in **Size**, turn **Same Size at
    Any Distance** off and on.
  - On **Glow**, in **Name Text**, set **Glow Color** to Deep, then back to
    Ink, and move **Glow Strength**.
- **Required state:** out of combat to change settings; enemy nameplates
  shown (friendly ones too for the names).
- **Confirmation:**
  - The preview's health bar stays in place while anchors and states change.
  - The chips switch the one plate between states; Player and NPC show only
    while editing Friendly.
  - The name sits on the border at the top left and shortens with "…" only as
    debuffs fill in from the right.
  - With no buffs, the right arrow sits right beside the bar and moves out as
    buffs appear.
  - The raid marker, level, elite and health % always draw above the bar.
  - Casts: light blue (can interrupt), orange-red (can't), the target left of
    the timer.
  - Combo points sit centered: under the cast bar while one shows, under the
    health bar otherwise.
  - Soft-target icons: a bag on the corpse, no sword on the enemy.
  - Friendly plates show only names: the player in class color, the NPC in
    green.
  - The game's own enemy soft-target icon is gone while Hide Blizzard's
    Combat Icon is on and back when it's off.
  - The enemy name (light) and health % read clearly over the red bar and
    the ground, each with a thin dark ring and no drop shadow.
  - With Same Size at Any Distance on, near, far and targeted plates are the
    same size and the text stays sharp; off, distant plates shrink again.
  - No Lua errors.
