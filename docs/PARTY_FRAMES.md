# Frames: Party Frames

November 13, 2026. A **Frames** module, after Nameplates. Off by default (turn it
on with the switch in the page header). Static/mock validated only; **native
acceptance is pending**. Settings version 5 (the Mode design language,
November 15, from the approved Group Frames probe; Mode Glass health and the
Shields tab after the owner's first look). APIs and
their secret-value rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#party-frames--november-13-2026).

## What it draws

You and your party (not a raid), one member under the next by default. Each
member is:

- **Bars**: health, a 1px black line and a 3px power bar inside the `group`
  edge (docs/DESIGN_LANGUAGE.md: 1px Gunmetal, Round 4; the rim art covers the
  bars' corners, so nothing is masked). 150 × 34 health by default, Mode
  Glass on Mode BG (the owner's pick), **Spacing** 1: every size is whole pixels, so the rims
  sit exactly one pixel apart. **Arrange** Vertical or Horizontal, with its **Direction**. Foreground and background
  textures, Bar Opacity, Background Opacity, fill direction and the fill end
  line, as on the Unit Frames.
- **Power Bars and Resources** (its own tab): **Power Bar For** Everyone,
  Healers, Mana Users, Healer Mana (healers with mana; every other resource is
  hidden) or No One; **Style** Below Health or Inset (on the health bar in a
  border of its own) with **Power Height**, **Power Width**, **Alignment**,
  **Offset X/Y** and nudges; **Power Color**, foreground and background
  textures, **Bar Opacity**, **Background Opacity** and **Fill**; **Power
  Text** (Percent, Percent No Sign or Current) with alignment, size, offset
  and nudges.
- **Health color**: Class Color (default), Dark or Custom. Power: by power
  type or Custom.
- **Incoming Heals** (Bars tab): ride on the end of the health fill, with
  Show, Texture, Color and Opacity.
- **Shields** (their own tab): Combined (`Style.Shield`): below full health
  the shield sits on the health's end and stops at the bar's end; at full
  health the whole shield fills back from max (**Show Overshields**). Its look
  (`Shield:SetLook`): **Texture** (any Mode bar texture; Mode Shield
  hairlines by default), **Opacity** (10-200%; 100% is the standard look) and
  **Color**: Follow Health (the shield tinted from the health bar) or Custom
  with its own color. The finish line stays bright.
- **Texts and icons** (Text and Icons tab), each with **Show**, **Anchor**,
  **Place** (Inside on the bars, Outside past their edge), **Offset X/Y**,
  **Nudge** arrows (1px) and **Size**: Name, Health Text (Percent, Percent No
  Sign, Current Health or Missing Health), Dead and Offline, Role, Leader, Raid
  Marker, Ready Check, and Summon and Resurrect. By default the role icon and
  the name sit on the left, the health text on the right. Names are Geist
  SemiBold in the **Gradient** (class color toward white; Soft Class, Text
  Color and Custom are options); health text is Geist Bold, colored **By
  Health** (Rosewood at 30% and under, through Ivory, to Celadon) or in the
  Text Color.
- **Highlights and Overlay**: your target (Border: the rim in Ivory; Tint;
  or None), **Aggro Rim** (the rim in the hostile red while a mob is on the
  member), a mouse highlight, and the **Dispel Overlay**: for each dispel type
  (Magic, Curse, Disease, Poison, Bleed) **Gradient** (the type color from the
  top edge, 56% fading out over 72% of the health; on by default), **Border**
  (the rim in the type color) and **Health Color** (the health fill in the
  type color), with **Which Debuffs** and **Gradient Opacity**. Rims are
  swapped, never added, so a member's size never changes; a dispel rim wins
  over your target, which wins over aggro. Type colors are shared with the
  aura rims and glows.
- **Fading**: out-of-range members at Out of Range Opacity (55%), dead and
  offline members at Dead and Offline Opacity (70%). You're always in range.

### The aura manager (Auras tab)

Two kinds, each its own list (**Kind**: Buffs or Debuffs), every group with its
own settings:

| Group | Which Auras (default first) | Default |
|---|---|---|
| Healing Buffs | All Healing Buffs, Your Healing Buffs (`RAID_IN_COMBAT`) | on; inside bottom right, growing left, 3 |
| Group Buffs | Group Buffs (`!RAID_IN_COMBAT`), Ones You Can Cast, Yours, All | off; inside top right |
| Defensives | Big and External, External, Big, Important | on; inside center, 1 of each |
| Tracked Buffs 1-3 | From Anyone, Yours; the buffs you add with + | on (empty); inside top right |
| Dispellable by You | Dispellable by You (`RAID`), by Your Group | on; first in the inside bottom left row, 3 |
| Magic, Curse, Disease, Poison, Bleed | Ones You Can't Dispel (`!RAID`), All; kept to the type by the game | on; continue that row, 2 each |
| Crowd Control | Crowd Control | off; outside left |
| Other Debuffs | Raid Frame Debuffs, All Without a Type, Yours | on; ends that row |

**Tracked Buffs** work like the Cooldown Manager's bars: click **+ Add or
Remove Buffs** (or + beside the group in the preview's list), click a buff on
you or your party (or type its spell ID), and it joins the group and shows
with that group's settings; click it again in the picker to take it out. A
buff is in one tracked group at a time, and the other buff groups leave
tracked buffs out. The game keeps each group to its spells, in combat too.

Per group: **Show This Group**, **Which Auras**, **Anchor**, **Place**,
**Grow**, **Offset X/Y** and **Nudge**, **Most Shown**, **Per Row**,
**Spacing**, **Icon Width** and **Icon Height**, **Timer Swipe**, **Timer
Text**, **Stack Count**, **Tooltips**, **Border** (By Type, Mode, Custom or
None) with **Border Size** (1-3) and **Border Color**, and **Glow** (Off by
default, GCD Flash or Soft Glow) with **Glow Color** (By Type or Custom).
**Reset Group** (a tracked group keeps its buffs) and **Copy Look To**. Groups
on the same anchor and place continue in one row, in the table's order, placed
and grown by the first one that is shown; move a group to another anchor to
place it on its own.

While the Auras tab is open the preview shows one larger member with only the
group being edited, beside a quick list of that kind's groups (click one to
edit it; dimmed ones are off; + on Tracked Buffs).

## Settings preview

One member by default. The buttons in the preview header (**One**, **Party**,
**Raid 10**, **Raid 20**, **Raid 40**) show more, raid sizes in groups of five
side by side. Each keeps its scale and the preview grows taller to hold it;
only a layout too big for the window is scaled down, so nothing clips.

Each tab shows what it edits on the first sample, and stops when you leave
it: the picked heal, shield or overshield on **Bars**, a healer with mana on
**Power Bars and Resources**, the picked element on **Text and Icons** (ready
check, summon, dead, raid marker, leader), and the picked dispel type's
overlay on **Highlights and Overlay** (with **Preview as Your Target**).
**Show States** in the header adds states to every sample: Dead, Offline, Out
of Range, Your Target, Dispel Overlay, Ready Check, Summon, Raid Marker,
Incoming Heals, Shields, Overshield.

Clicking a bar, text, icon or aura opens its settings. **Test on Screen** and
Edit Mode show the sample party where the frames sit. Party frames themselves
still show only in a party.

## How it works

- **Secure group header** (`SecureGroupHeaderTemplate`): lists you (Show
  Yourself) and party1-4, sorts them (Party Order or Role), reverses them, and
  shows, hides and places the buttons in combat too. ModeUI sets its
  attributes outside combat only; all five buttons are made up front.
- **Unit changes**: the header sets every button's unit again on each
  `GROUP_ROSTER_UPDATE` and on any unit's `UNIT_NAME_UPDATE`, which come in
  bursts while a group forms. The same unit does nothing; a new one, and
  roster events, redraw each member once on the next frame. A member's unit
  events and aura containers follow its unit only when the unit changes, and
  the containers read auras again by themselves then (`SetUnit`); with the
  same unit they read again only when the person behind it changed
  (`UnitGUID`, or always when that can't be read).
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
  glows by type through `AddDispelTypeTexture`. Containers are configured
  only after a settings change: the game's `SetAuraGroupCandidateFilters`
  reads every aura again on each call.
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

`ModeUIDB` profile `modules.partyFrames` (version 5) and the position
`positions.partyFrames`. Version 1 settings migrate: frames still at the old
default size (34 health, 5 power) take the new one, Buffs becomes Healing
Buffs in its place, Debuffs' place goes to every debuff type and Other
Debuffs, each group's size and shape become a width and height, and the old
dispel highlight becomes the per-type effects. Version 2 settings migrate:
frames at 44 health and 4 spacing take 52 and 1, the power bar copies the
bars' opacities, debuff type groups that showed every debuff of their type
show the ones you can't dispel, and Dispellable by You takes the Magic
group's place. Version 3 settings migrate to the Mode design: values still at
their version 3 default take the new one (132 → 150 wide, 52 → 34 health, 6
→ 3 power, Mode Gradient on Mode BG at full opacity, Geist with one shadow,
Gradient names, 55% out of range, Gradient Opacity 56, the name, health text
and role moved to their new places, and debuff effects that were the Border
alone become the Gradient). Anything the player picked stays. Border, Corner
Size and the shield and overshield textures, colors and opacities retire.
Version 4 settings migrate: health still on Mode Gradient takes Mode Glass,
and the shield look settings arrive at the standard look.

## In-game check

- **Navigation:** type `/modeui`, then pick **Frames** › **Party Frames** in the
  sidebar.
- **Action:** look at the edges of the frames. In the preview header, click
  **Party**. Open **Highlights and Overlay** and pick **Curse** under **Type**.
  Open **Shields**, pick **Glass** under **Texture**, **Custom** under
  **Color**, and drag **Opacity** to 150%. Open **Power Bars and
  Resources** and pick **Healer Mana** under **Power Bar For**. Open **Auras**,
  click an aura in the preview, pick **Tracked Buffs 1** in the quick list,
  click **+**, and click a buff.
- **Required state:** out of combat; a party (or **Show When Solo**) for live
  members, and a buff on you or a party member for the picker.
- **Confirmation:** each member has a thin rounded Gunmetal rim, and the
  rims sit exactly one pixel apart, matching the Group Frames probe. The
  Warrior sample's rim is red (aggro) and the Mage's is Ivory (your target).
  Names fade from the class color toward white; the health text is green at
  full and red under 30%. All five Party samples fit in the preview. The
  first sample shows a purple Curse gradient from its top edge. On Shields,
  the first sample's shield turns to Glass in the custom color and grows
  stronger with Opacity. The health bars use Mode Glass. Only a healer
  with mana shows a power bar. Clicking the aura opens the Auras tab. The
  picked buff shows in Tracked Buffs 1's place on the frames.
