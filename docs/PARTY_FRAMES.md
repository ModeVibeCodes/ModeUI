# Frames: Party Frames

November 13, 2026. A **Frames** module, after Nameplates. Off by default (turn it
on with the switch in the page header). Static/mock validated only; **native
acceptance is pending**. Settings version 2 (second pass, same day). APIs and
their secret-value rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#party-frames--november-13-2026).

## What it draws

You and your party (not a raid), one member under the next by default. Each
member is:

- **Bars**: health, plus an optional power bar, inside the ModeUI border in its
  box form (`Kit.ModeBoxBorder`, the chat windows' corners): **Border** Mode
  (2px) or Thin (1px, for pixel-perfect rows with a 1px gap) and **Corner
  Size** (7px). 132 × 44 health by default. Foreground and background
  textures, Bar Opacity, Background Opacity, fill direction and the fill end
  line, as on the Unit Frames.
- **Power Bar** (Layout tab): **Power Bar For** Everyone, Healers, Mana Users,
  Healer Mana (healers with mana; everyone else's is hidden) or No One;
  **Style** Below Health (its own row, with **Power Height**) or Inset (on the
  health bar in a border of its own, with **Power Width**, **Alignment**,
  **Offset X/Y** and nudges).
- **Health color**: Class Color (default), Onyx or Custom. Power: by power
  type or Custom.
- **Heals and Shields** (Bars tab): incoming heals ride on the end of the
  health fill, **Shields** ride on the heals, and **Overshields** fill back
  from full health with the whole shield, shown while it is bigger than the
  missing health. Each has its own texture (Mode Slate Hatch for shields and
  overshields by default, drawn with crisp 1px lines at any size), color and
  opacity.
- **Texts and icons** (Text and Icons tab), each with **Show**, **Anchor**,
  **Place** (Inside on the bars, Outside past their edge), **Offset X/Y**,
  **Nudge** arrows (1px) and **Size**: Name, Health Text (Percent, Percent No
  Sign, Current Health or Missing Health), Dead and Offline, Role, Leader, Raid
  Marker, Ready Check, and Summon and Resurrect.
- **Highlights**: your target (Border, Tint or None), a mouse highlight, and
  **Debuff Effects**: for each dispel type (Magic, Curse, Disease, Poison,
  Bleed) **Border** (the member's border in the type color; on by default),
  **Health Color** (the health fill in the type color) and **Gradient** (the
  color fading down over the health bar), with **Which Debuffs** and
  **Gradient Opacity**. Type colors are shared with the aura rims and glows.
- **Fading**: out-of-range members at Out of Range Opacity (45%), dead and
  offline members at Dead and Offline Opacity (70%). You're always in range.

### The aura manager (Auras tab)

Ten groups, each with its own settings, so healing buffs are apart from group
buffs and every debuff type is placed and styled on its own:

| Group | Which Auras (default first) | Default |
|---|---|---|
| Healing Buffs | All Healing Buffs, Your Healing Buffs (`RAID_IN_COMBAT`) | on; inside bottom right, growing left, 3 |
| Group Buffs | Group Buffs (`!RAID_IN_COMBAT`), Ones You Can Cast, Yours, All | off; inside top right |
| Defensives | Big and External, External, Big, Important | on; inside center, 1 of each |
| Magic, Curse, Disease, Poison, Bleed | All, Only If You Can Dispel; kept to the type by the game | on; one row at the inside bottom left, 2 each |
| Other Debuffs | Raid Frame Debuffs, All Without a Type, Yours | on; continues that row |
| Crowd Control | Crowd Control | off; outside left |

Per group: **Show This Group**, **Which Auras**, **Anchor**, **Place**,
**Grow**, **Offset X/Y** and **Nudge**, **Most Shown**, **Per Row**,
**Spacing**, **Icon Width** and **Icon Height**, **Timer Swipe**, **Timer
Text**, **Stack Count**, **Tooltips**, **Border** (By Type, Mode, Custom or
None) with **Border Size** (1-3) and **Border Color**, and **Glow** (Off by
default, GCD Flash or Soft Glow) with **Glow Color** (By Type or Custom).
**Reset Group** and **Copy Look To**. Groups on the same anchor and place
continue in one row, in the table's order, placed and grown by the first one
that is shown; move a group to another anchor to place it on its own.

While the Auras tab is open the preview shows one larger member with only the
group being edited.

## Settings preview

One member by default. The buttons in the preview header (**One**, **Party**,
**Raid 10**, **Raid 20**, **Raid 40**) show more, raid sizes in groups of five
side by side, at fixed scales: changing a size grows the sample in place
instead of rescaling or moving it. Clicking a bar, text, icon or aura opens
its settings. **Test on Screen** and Edit Mode show the sample party where the
frames sit. Party frames themselves still show only in a party.

## How it works

- **Secure group header** (`SecureGroupHeaderTemplate`): lists you (Show
  Yourself) and party1-4, sorts them (Party Order or Role), reverses them, and
  shows, hides and places the buttons in combat too. ModeUI sets its
  attributes outside combat only; all five buttons are made up front.
- **Placement**: Edit Mode moves a plain stand-in the size of a full party.
  The header is anchored to UIParent by the corner the group grows from (top
  left for Down and Right, bottom left for Up, top right for Left), copied
  from the stand-in outside combat. When the size changes (width, height,
  border, scale, growth) the stand-in's saved offset moves by however far that
  corner moved, so the group stays put on screen.
- **Blizzard's party frames**: with **Hide Blizzard's Party Frames**,
  `PartyFrame` moves under a hidden ModeUI frame outside combat (hiding the
  raid-style party frames too); off puts it back.
- **Auras in the world** use Blizzard's aura containers: one container per
  member and anchor, one container group per group and filter, kept to its
  dispel type by `candidateFilters` (`includeDispelTypes`, and
  `excludeDispelTypes` for Other Debuffs). Buttons are styled once: rims and
  glows by type through `AddDispelTypeTexture`.
- **Debuff effects** are one aura slot per type on a container
  (`includeDispelTypes`), whose button covers the member and holds that type's
  border, health overlay and gradient in its color; the game shows the button
  only while the member has such a debuff.
- **Heals and shields** come from Blizzard's heal prediction calculator
  (`UnitGetDetailedHealPrediction`): clamped heals and shield amounts and the
  total shield go to the bars, and its "clamped" flag shows the overshield
  through `SetAlphaFromBoolean`. Without a calculator the shield uses
  `UnitGetTotalAbsorbs` and no overshield shows.

## Saved settings

`ModeUIDB` profile `modules.partyFrames` (version 2) and the position
`positions.partyFrames`. Version 1 settings migrate: frames still at the old
default size (34 health, 5 power) take the new one, Buffs becomes Healing
Buffs in its place, Debuffs' place goes to every debuff type and Other
Debuffs, each group's size and shape become a width and height, and the old
dispel highlight becomes the per-type effects.

## In-game check

- **Navigation:** type `/modeui`, then pick **Frames** › **Party Frames** in the
  sidebar.
- **Action:** in the preview header, click **Party** and then **Raid 20**. On
  the **Layout** tab, drag **Width**. Pick **Thin** under **Border**. Under
  **Power Bar For**, pick **Healer Mana**. Open the **Auras** tab, pick **Magic**
  under **Group**, then click the nudge arrows and pick **GCD Flash** under
  **Glow**. On the **Highlights** tab, with **Magic** picked under **Type**,
  turn on **Health Color**.
- **Required state:** out of combat for every change; a party (or **Show When
  Solo**) for live members, and a Magic debuff on a member for the effects.
- **Confirmation:** the preview grows in place while the width changes, and
  so does the group on screen (it stays at its top left). The borders become 1px.
  Only healers with mana show a power bar. Magic debuffs move by one pixel per
  click and flash. A member with a Magic debuff turns blue.
