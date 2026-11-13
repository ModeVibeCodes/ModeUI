# Frames: Nameplates

November 12, 2026. Second module ModeUI built; in the **Frames** category since November 13. Off by default
(turn it on with the switch in the page header). Static/mock validated only;
**native acceptance is pending** for the latest changes. APIs and their
secret-value rules are in [API_COMPATIBILITY.md](API_COMPATIBILITY.md#interface-nameplates--november-12-2026).

## What it draws

On every nameplate the game gives to addons, ModeUI parents its own plain
frame and fades Blizzard's art. Each plate has:

- **Health and cast boxes**: a 1px near-black rim (#25282C) and a 1px black gap
  with rounded corners, then the bar in **Mode Gradient** (ModeUI's only bar
  texture). Both boxes use the same small-radius rim textures, so they round
  alike at every size. Insets are whole physical pixels; boxes under 8 units stay square.
- **Name** and **health text** (Percent, Current Health, Current and Percent, None).
  All text uses the suite's lifted shadow and Expressway by default.
- **Health color**: Reaction and Class, Reaction, Onyx or Custom, used exactly
  as they are (true colors). **Threat Colors** (enemies, on by default) gives
  each threat status its own color: **Has Aggro** (the enemy is attacking you;
  red), **Losing Aggro** (it's attacking you, but someone else is about to take
  it; orange) and **Close to Pulling** (it's attacking someone else and you're
  about to take it; orange). With no threat, or while the game hides threat, the
  plate keeps its health color.
- **Health Opacity** (100% by default) fades the health fill without changing
  its color. **Background Opacity** (55% by default) fades only the empty part of
  the health bar, so the world shows through it; the rim, the fill and the text
  stay solid. To make that possible the health box draws its rim and gap in four
  clipped bands around the bar rather than as filled shapes behind it, and the
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
  a line on their side, and the cast bar and name move past it.
- **Indicators**: a quest icon (quest bosses and creatures tied to your active
  quests), Blizzard's elite, rare elite, rare and boss icons, and the level in
  its difficulty color. Pick one with **Indicator** (Quest, Elite and Rare,
  Level); each has **Show This Indicator**, an **Anchor**, **Offset X/Y** and a
  size (icon size, or the level's text size). Indicators on the same anchor line
  up in one row; beside the bar the row sits past the raid marker, and aura rows
  and target arrows sit past it. Clicking one in the preview selects it.
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

**Style**: Border (the rims turn the target color; **Border Thickness** up to
3px), Glow (a soft halo), Arrows (pointing in from both sides; **Arrow Size** and
**Arrow Gap**, up to 48 and 60), Border and Arrows, or None, in a **Color** of
your choice (cyan by default). Arrows always sit outside the raid marker, the
indicator and any aura row on their side. Name Only plates color the
name for Border and Glow. The target is found by comparing nameplate frames.

## Focus

The **Focus** tab styles your focus target's plate: **Highlight** (Border, the
rims in the focus color; Glow; Stripes, diagonal stripes over the health bar at
**Stripe Opacity**; or None), a **Color** (amber by default), **Focus Texture**
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
part of the sample** (health bar, name, health text, cast bar, an aura or the raid
marker) to jump to its settings; parts light up under the mouse.

## Settings page

Tabs: **Nameplates** (style, size, textures, health), **Text** (name, health
text, font), **Cast Bar** (layout, content, colors), **Auras**, **Target** (target
indicator) and **Indicators** (the level, elite and quest indicator, and the raid
marker). Clicking text in the preview opens its settings only where the text is
written; the rest of the bar opens the health settings. Each tab starts
with the Editing switch; settings are grouped on cards with accent titles, with
related sliders and choices side by side.

## What stays Blizzard's

- Where plates appear, their stacking, scale, clicks and hit areas.
- Friendly plates inside instances (forbidden to addons).
- Your personal resource display, and widget-only plates.

Switching the module off gives every plate back to Blizzard. Plates are plain
frames, never secure, so they also work in combat. Settings change outside combat.

## Settings versions

Version 7. Version 1 (one shared set) copies into both kinds; version 2 drops the
retired texture choice; version 3's single aura row becomes the three groups;
version 4's target highlight switch becomes a target style, and each aura group
grows the way its anchor did; version 5's Color Softness is removed; version 6's single indicator place and
sizes go to each indicator. New
settings take their defaults.

## Files

| File | Job |
|---|---|
| `Init.lua` | declaration, per-kind defaults, ranges, choices, validation, migrations |
| `Driver.lua` | lifecycle, events, enemy or friendly kind, fading Blizzard's unit frame, per-kind settings |
| `Plate.lua` | building a plate and laying out its boxes |
| `Layout.lua` | placing every element by anchor and offset; Name Only |
| `Target.lua` | target indicator styles, arrow placement and name colors |
| `Indicator.lua` | the level, classification and quest indicators |
| `Focus.lua` | the focus highlight, focus texture and fading other plates |
| `Update.lua` | health, name, colors, threat, raid marker |
| `CastBar.lua` | cast and channel bars, icon side, target line and timer |
| `Auras.lua` | aura groups, rim colors, grow directions, pixel-snapped placement |
| `Preview.lua` | the sample plate on the settings page and its click targets |
| `Settings.lua` | the settings page |

Shared pieces: `Domain/Cast`, `RaidIcon`, `Threat`, `Nameplate`, `Auras`;
`Kit/Palette`, `AuraIcon`, `Kit.ModeGradient`, `Kit.FontPath`;
`W.AnchorPicker`, `page:Columns` and the settings cards. Textures come from
`tools/build_shape_textures.lua`.

## Not in this version

- Class resource bars on enemy plates.
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
  - Click parts of the preview.
  - In the world, look at enemies and friendly players, target one, mark one,
    and put a debuff on an enemy.
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
  - Settings sit on cards, the Editing pills line up with their label, and no
    Lua errors appear.
