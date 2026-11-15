# Frames: Nameplates

November 12, 2026. Second module ModeUI built; in the **Frames** category since November 13. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending** for the latest changes. APIs and their
secret-value rules are in [API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-nameplates--november-12-2026).

## What it draws

On every nameplate the game gives to addons, ModeUI parents its own plain
frame and fades Blizzard's art. Each plate has:

- **Health and cast boxes** (docs/DESIGN_LANGUAGE.md, settings version 9 from
  the approved Nameplates probe): the bar inside the `frameThin` edge (1px
  Gunmetal, edge-lit, a 1px shadow ring). The rim art sits outside the bar and
  covers its own corners, so nothing is masked. Health fills in **Mode BG**
  on Mode BG (Slate); the cast bar has its own **Cast Bar** texture (**Mode
  Cast**) and the **Comet** spark on the fill's leading edge (a channel's on
  its left), hidden while an interrupted cast is held.
- **Name** in Geist SemiBold, in the **Gradient** (the class or reaction color
  toward white) by default; Class or Reaction and Text Color are options.
  **Health text** (Percent, Current Health, Current and Percent, None) in Geist
  Bold, colored **By Health** (Rosewood at 30% and under, through Ivory, to
  Celadon) or in the Text Color. Cast texts are Geist Bold. One shadow, no
  lifted copy.
- **Health color**: Reaction and Class, Reaction, Onyx or Custom, used exactly
  as they are (true colors). **Threat Colors** (enemies, on by default) gives
  each threat status its own color: **Has Aggro** (the enemy is attacking you;
  red), **Losing Aggro** (it's attacking you, but someone else is about to take
  it; orange) and **Close to Pulling** (it's attacking someone else and you're
  about to take it; orange). With no threat, or while the game hides threat, the
  plate keeps its health color.
- **Health Opacity** (100% by default) fades the health fill without changing
  its color. **Background Opacity** (100% by default) fades only the empty part
  of the health bar, so the world shows through it; the rim, the fill and the
  text stay solid (the edge draws outside the bar, so nothing sits behind it), and the
  target glow texture is hollow. The cast bar keeps a solid background: a
  channel drains by covering the cast color with the track color.
- **Textures**: **Foreground** (Mode Gradient by default, Flat, or any SharedMedia
  status bar) and **Background** (Flat or SharedMedia), for the health and cast bars.
- **Cast bar**: amber when interruptible, gray when not; channels drain from right
  to left. **Spell Icon** Left, Right, Outside Left, Outside Right or Hidden, with
  **Icon Offset X/Y**; **Spell Name**; **Cast Target**
  (who the caster is targeting, in its class color, on a line past the bar; on by
  default for enemies); **Timer** (seconds left, from public cast times or the
  cast's duration object; empty while the game hides both). Pick a text with
  **Position Of** to set its **Anchor** (Left, Center, Right inside the bar; Top
  and Bottom anchors outside it) and **Offset X/Y**. Texts outside the bar take
  a line on their side, and the cast bar and name move past it. An interrupted
  cast stays a second, full, in the **Interrupted** color with "Interrupted" as
  its spell name, then fades, as Blizzard's cast bars do.
- **Indicators**: a quest icon (quest bosses and creatures tied to your active
  quests), Blizzard's elite, rare elite, rare and boss icons, and the level in
  its difficulty color. Pick one with **Indicator** (Quest, Elite and Rare,
  Level); each has **Show This Indicator**, an **Anchor**, **Offset X/Y** and a
  size (icon size, or the level's text size). Indicators on the same anchor line
  up in one row; beside the bar the row sits past the raid marker, and aura rows
  and target arrows sit past it. Clicking one in the preview selects it.
- **Soft Target Icon** (on by default): the cursor the game shows over your soft
  target (a sword on your soft enemy, a bag or gear on what your interact key
  would use), centered above everything on the plate's top edge, with a
  **Size** and **Offset X/Y**. It replaces the icon Blizzard draws on its own
  plate, which ModeUI fades with the rest. Which soft targets get one stays the
  game's interact icon setting in its Accessibility options.
- **Slug Text** (on by default): text drawn from glyph outlines, sharp at any
  size. See [API_COMPATIBILITY.md](API_COMPATIBILITY.md) for how it is applied.
- **Auras** in three groups, the **raid marker**, and a **target indicator**.

**Name Only** (the Style choice) draws just the name, centered, in the class
color for players or the reaction color otherwise, with auras and the raid
marker. It has no bars and no cast bar.

## Placement

Every element has an anchor, read like a compass around the health bar, and an
Offset X and Y (up to 50 each way):

| Anchor | Text (name, health text) | Raid marker and auras |
|---|---|---|
| Top Left / Top / Top Right | above the bar (above the cast bar when it's on top) | above everything over the bar |
| Left / Center / Right | inside the bar | beside the bar (Center: in its middle) |
| Bottom Left / Bottom / Bottom Right | below the bar (below the cast bar when it's below) | below everything under it |

The cast bar sits **Below** or **Above** the health bar, with its own offsets.
The raid marker has a **Size**. Anchors are picked with the anchor compass
(`W.AnchorPicker`).

## Enemy and friendly plates

Every plate is an **enemy** plate (a unit you can attack) or a **friendly** one,
and each kind has its own full settings. **Use ModeUI Plates** turns ModeUI off
for one kind. A unit that changes sides switches kinds on `UNIT_FACTION`.
**Copy Style to Friendly/Enemy** copies the whole look; **Reset to Defaults**
resets the kind being edited.

## Auras

Three groups, in order: **Crowd Control**, **Debuffs**, **Buffs**. The game's own
aura filters decide what belongs to each, so secret aura data is never compared.

- Every group: **Show Auras**, **Timer Swipe**, **Stack Count**, **Icon Shape**
  (Cropped: 6px wider than tall, the default, for example 32 x 26; or Square),
  **Borders** (By Type or Mode), **Border Size** (1-3px, 2 by default),
  **Corners** (Sharp: crisp, pixel-snapped square rims, the default; or Rounded),
  **Spacing**, **Timer Text** in **Timer Text Color** (the action bar cooldown
  color, #FFB12F, by default) and **Crowd Control Glow** in the rim color, with
  **Glow Style**: GCD Flash (Blizzard's action button GCD flipbook,
  `UI-HUD-ActionBar-GCD-Flipbook`, looping; the default) or Soft Glow.
- Each group (pick it with **Group**): **Show This Group**, **Which** (Debuffs:
  Yours, Ones You Can Dispel, All; Buffs: Dispellable or Stealable, Important,
  Yours, All), **Anchor**, **Grow** (Right, Left, Up, Down, Center), **Offset X/Y**,
  **Icon Size** and **Most Shown**. Groups on the same anchor continue as one
  row in the first group's direction. **Sit on Health Bar** puts a Top or Bottom
  group right against the bar; the name and cast bar on that side move past it.
- Icons are built like plate boxes: rounded rim, black gap, the icon inset 2px
  and cropped so it is never stretched. With **By Type** borders the rim takes the
  aura's dispel type color (Magic, Curse, Disease, Poison, Enrage, each
  customizable); auras without a type, or whose type the game hides, keep the
  Mode rim.
- Defaults: enemies show crowd control on the Left (24px, up to 2), your debuffs
  on Top (20px, up to 6), dispellable buffs on the Right (18px, up to 3).
  Friendly plates show debuffs you can dispel on Top (16px, up to 4).

## Target indicator

**Style**: Border (the edge's outer line in the target color, Ivory by default,
on the health and cast boxes; **Border Thickness** 2 or 3 tints the rim too), Glow (a soft halo), Arrows (pointing in from both sides; **Arrow Size** and
**Arrow Gap**, up to 48 and 60), Border and Arrows, or None, in a **Color** of
your choice (Ivory by default). Arrows always sit outside the raid marker, the
indicator, any aura row and the combo points on their side. Name Only plates color the
name for Border and Glow. The target is found by comparing nameplate frames.

## Combo points

November 13, 2026, per the owner: combo points you can track on the plate of
your target (`Combo.lua`, the **Combo Points** card on the **Target** tab). On
WoW Forever combo points live on the target (`GetComboPoints("player",
"target")`), and only Rogues, and Druids in Cat Form, have them
(`Domain.ClassResource`, shared with the Target frame). Forever's own
nameplates draw none: `Blizzard_NamePlates.toc` loads the Rogue and Druid class
nameplate bars only outside `camelot`. So the points follow your target from
plate to plate (`PLAYER_TARGET_CHANGED`, `COMBO_TARGET_CHANGED`) and refill on
the player's power events (`UNIT_POWER_FREQUENT`, `UNIT_MAXPOWER`,
`UNIT_DISPLAYPOWER`, unit-filtered to the player on the module's own frame).

One round socket per point (the player's maximum, else five) in a row: a rim
in the ModeUI border color, a dark socket and a fill (`Shared/Kit/Points.lua`,
also used by the Target frame). The count may be secret, so each socket is its
own StatusBar spanning `(i - 1, i)` and gets the count through `SetValue` only.
Settings, per kind: **Show Combo Points** (on for enemies, off for friendly
plates), **Anchor** (Bottom by default: below the cast bar; Top and Bottom sit
past the name and cast bar, Left and Right beside the bar past the raid marker,
indicators and aura rows, Center on the bar), **Point Size** (8px, snapped to
even pixels), **Spacing** (2px), **Offset X/Y**, **Lit Point Color** (red) and
**Empty Point Color** (Onyx track). Target arrows sit past points beside the
bar. A class without combo points sees a note saying so and nothing shows.

## Focus

The **Focus** tab styles your focus target's plate: **Highlight** (Border, the
edge's outer line in the focus color; Glow; Stripes, diagonal stripes over the health bar at
**Stripe Opacity**; or None), a **Color** (Rosewood by default), **Focus Texture**
(Same as Foreground, or any foreground texture) and **Other Plates Opacity**,
which fades every other plate while you have a focus (100% leaves them alone).
A plate that is both your target and your focus shows the target's border. The
focus is found by comparing nameplate frames, on `PLAYER_FOCUS_CHANGED`. While
the Focus tab is open, the preview sample shows itself as your focus.

## Preview

The top of the page shows one sample plate: the kind chosen with **Editing**,
centered. It's built by the same code as the plates in the world, so it matches
every setting, including Name Only, the target style and auras with their type
colors. **Static** shows the cast 60% done; **Animated** loops it. **Click any
part of the sample** (health bar, name, health text, cast bar, an aura, the raid
marker, the soft-target icon or the combo points) to jump to its settings; parts light up under the mouse.

## Settings page

Tabs: **Nameplates** (style, size, textures, health), **Text** (name, health
text, font), **Cast Bar** (layout, content, colors), **Auras**, **Target** (target
indicator and combo points) and **Indicators** (the level, elite and quest indicator, the raid
marker and the soft-target icon). Clicking text in the preview opens its settings only where the text is
written; the rest of the bar opens the health settings. Each tab starts
with the Editing switch; settings are grouped on cards with accent titles, with
related sliders and choices side by side.

## What stays Blizzard's

- Where plates appear, their stacking, scale, clicks and hit areas.
- Friendly plates inside instances (forbidden to addons).
- Your personal resource display, and widget-only plates.
  Their soft-target icons, and the ones the game draws for objects itself, are
  Blizzard's.

Switching the module off gives every plate back to Blizzard. Plates are plain
frames, never secure, so they also work in combat. Settings change outside combat.

## Settings versions

Version 9. Version 8 settings still at their defaults take the Mode ones
per kind (Mode BG on Mode BG at 100%, the Gradient name, Geist with one
shadow, the Ivory target and the Rosewood focus); picked values stay, and the
Cast Bar texture and Health Text Color arrive with their defaults. Version 1 (one shared set) copies into both kinds; version 2 drops the
retired texture choice; version 3's single aura row becomes the three groups;
version 4's target highlight switch becomes a target style, and each aura group
grows the way its anchor did; version 5's Color Softness is removed; version 6's single indicator place and
sizes go to each indicator; version 7's old orange no-type crowd control rim moves
to #FF5948. New settings (such as the combo points) take their defaults.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, per-kind defaults, ranges and choices |
| `Migrations.lua` | `Initialize(db)`: validation and the settings-version migrations |
| `Driver.lua` | lifecycle, events, enemy or friendly kind, fading Blizzard's unit frame, per-kind settings |
| `Plate.lua` | building a plate and laying out its boxes |
| `Layout.lua` | placing every element by anchor and offset; Name Only |
| `Target.lua` | target indicator styles, arrow placement and name colors |
| `Indicator.lua` | the level, classification and quest indicators |
| `Focus.lua` | the focus highlight, focus texture and fading other plates |
| `Combo.lua` | combo points on the target's plate, following the target |
| `SoftTarget.lua` | the soft-target icon: the game's cursor art for your soft target, above the plate |
| `Update.lua` | health, name, colors, threat, raid marker |
| `CastBar.lua` | cast and channel bars, icon side, target line and timer |
| `Auras.lua` | aura groups, rim colors, grow directions, pixel-snapped placement |
| `AuraContainers.lua` | auras through Blizzard's secure custom aura containers while auras are secret |
| `Preview.lua` | the sample plate on the settings page and its click targets |
| `Settings.lua` | the settings page |

Shared pieces: `Domain/Cast`, `RaidIcon`, `Threat`, `Nameplate`, `Auras`, `ClassResource`;
`Kit/Palette`, `AuraIcon`, `Points`, `Kit.ModeGradient`, `Kit.FontPath`;
`W.AnchorPicker`, `page:Columns` and the settings cards. Textures come from
`tools/build_shape_textures.lua`.

## Not in this version

- Class resources other than combo points (Forever has none for other classes).
- Aura rim colors while the game hides aura details (it would need the
  dispel color curve on secret data).

## Manual check

- **Navigation:** `/modeui`, then **Frames** › **Nameplates**.
- **Action:**
  - Turn the module on. Switch **Editing** between **Enemy** and **Friendly** and
    watch the preview change.
  - On the **Nameplates** tab, in **Health**, move **Health Opacity** and
    **Background Opacity**.
  - Set Friendly **Style** to **Name Only**.
  - Move the name, health text, cast bar and raid marker with their anchors.
  - On **Auras**, pick each **Group** and set **Anchor** and **Grow**.
  - On **Target**, try each **Style**.
  - As a Rogue (or a Druid in Cat Form), on **Target** in **Combo Points**, keep
    **Show Combo Points** on and try each **Anchor**.
  - Click parts of the preview.
  - In the world, look at enemies and friendly players, target one, mark one,
    and put a debuff on an enemy.
  - As a Rogue, target an enemy and use a combo point builder, then target
    another enemy.
  - On **Indicators** in **Soft Target Icon**, keep **Show Soft Target Icon** on.
    In the world, without targeting, face an enemy near enough to become your
    soft target, then kill one and face its corpse to loot it.
- **Required state:** out of combat to change settings; enemy nameplates shown.
- **Confirmation:**
  - The preview matches the plates in the world.
  - Hostile plates are the plain hostile red, not pink. With Background Opacity
    low, the world shows through the empty part of the bar while the rim, the
    health color and the text stay solid; the target border and glow don't tint
    the empty part.
  - Friendly Name Only shows class-colored names.
  - Every element sits where its anchor says.
  - Auras are cropped with rims colored by type.
  - The target style shows on your target.
  - Combo points show only on your target's plate, light up as you build them,
    and move to the new target's plate when you change targets.
  - The sword (on a soft enemy) or the bag (on a lootable unit) sits centered
    above that ModeUI plate, clear of its name and aura rows, and goes away when
    you face something else. No icon floats off to the side of a ModeUI plate.
    (Seeing none at all means the game's interact icon setting has that kind off.)
  - Settings sit on cards, the Editing pills line up with their label, and no
    Lua errors appear.
