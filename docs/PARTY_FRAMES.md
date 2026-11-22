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
  edge (docs/DESIGN_LANGUAGE.md: **Border** and **Border Metal** on the
  Border tab, Mode-Border by default, a 1px dark glass band with a lit top and a champagne bottom; the rim art covers the
  bars' corners, so nothing is masked). 150 × 34 health by default, Mode-FG in
  Dark (`#161618`) on Mode-BG at 85%, **Spacing** 1: every size is whole pixels, so the rims
  sit exactly one pixel apart. **Arrange** Vertical or Horizontal, with its **Direction**. Foreground and background
  textures, Bar Opacity, Background Opacity, fill direction and the fill end
  line, as on the Unit Frames.
- **Power Bar** (General, Fill and Text tabs): **Power Bar For** Everyone,
  Healers, Mana Users, Healer Mana (healers with mana; every other resource is
  hidden) or No One; **Style** Below Health or Inset (on the health bar in a
  border of its own) with **Power Height**, **Power Width**, **Alignment**,
  **Offset X/Y** and nudges; **Power Color**, foreground and background
  textures, **Bar Opacity**, **Background Opacity** and **Fill**; **Power
  Text** (Percent, Percent No Sign or Current) with alignment, size, offset
  and nudges.
- **Health color**: Class Color (default), Dark (`#1C1D1C`) or Custom.
  Mode textures with light (Glass, Matte, Gradient) draw their white lift over
  the fill, so it reads on dark fills too. Empty bars are Slate at 60%
  (Background Opacity) with no black plate behind them; the plate returns
  only when both empty bars are at 100%. Power: by power
  type or Custom.
- **Incoming Heals** (Fill tab): ride on the end of the health fill, with
  Show, Texture, Color and Heal Opacity, and **Spark End Line** (on by default): a
  bright 1px line with a glow in the heal color where the heals stop
  (`Style.EndSpark`); none while the heals pass the bar's end.
- **Shields** (Fill tab): Combined (`Style.Shield`): below full health
  the shield sits on the health's end and stops at the bar's end; at full
  health the whole shield fills back from max (**Show Overshields**). Its look
  (`Shield:SetLook`): **Texture** (any Mode bar texture; Mode Shield
  hairlines by default), **Shield Opacity** (10-200%; 100% is the standard look) and
  **Color**: Follow Health (the shield tinted from the health bar) or Custom
  with its own color. The finish line stays bright.
- **Texts and icons** (Text tab: **Text Style** with Font, Outline, Slug Text,
  **Shadow** and Text Color, then the **Texts and Icons** card), each with **Show**, **Anchor**,
  **Place** (Inside on the bars, Outside past their edge), **Offset X/Y**,
  **Nudge** arrows (1px) and **Size**: Name, Health Text (Percent, Percent No
  Sign, Current Health or Missing Health), Dead and Offline, Role, Leader, Raid
  Marker, Ready Check, and Summon and Resurrect. By default the role icon and
  the name sit on the left, the health text on the right. Names are the Mode typeface (Urbanist)
  SemiBold in the **Gradient** (class color toward white; Soft Class, Text
  Color and Custom are options); health text is Bold, colored **By
  Health** (Rosewood at 30% and under, through Ivory, to Celadon) or in the
  Text Color, with a soft glow in its own color (**Health Text Glow**, Glow ›
  Text Glows, on by default).
- **Rims and highlights** (Border › Rims and Dispel Overlay, Glow ›
  Highlights): **Your Target** (Border: the rim in Ivory; Tint; or None) with
  **Target Color**, **Aggro Rim** (the rim in the hostile red while a mob is
  on the member), **Mouse Highlight**, **Hover Glow** and **Focus Glow**, and
  the **Dispel Overlay**: for each dispel type
  (Magic, Curse, Disease, Poison, Bleed) **Gradient** (the type color from the
  top edge, 56% fading out over 72% of the health; on by default), **Border**
  (the rim in the type color) and **Health Color** (the health fill in the
  type color), with **Which Debuffs** and **Gradient Opacity**. Rims are
  swapped, never added, so a member's size never changes; a dispel rim wins
  over your target, which wins over aggro. **Type Colors** (Border tab) are
  shared with the aura rims and glows.
- **Fade** (Behavior tab): out-of-range members at Out of Range Opacity (55%), dead and
  offline members at Dead and Offline Opacity (70%). You're always in range.

### The aura manager (Auras tab)

Two kinds, each its own list (**Aura Kind**: Buffs or Debuffs), every group
with its own settings. **Aura Kind** and **Aura Group** sit above the tabs
that edit the group: **Auras**, **Border** (Aura Borders) and **Glow** (Aura
Glows).

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
Text**, **Stack Count**, **Tooltips**, **Timer Text Color** (every group),
**Border** (Border › Aura Borders: By Type, Mode, Custom or
None) on the `frameThin` edge every aura icon wears (By Type and Custom
tint its rim, Mode keeps the Gunmetal metal, None hides it) with **Border
Size** (1 or 2) and **Border Color**, and **Glow** (Glow › Aura Glows: None
by default, GCD Flash or Soft Glow) with **Glow Color** (By Type or Custom).
**Reset…** in the footer offers the group being edited (**Curse Group**; a
tracked group keeps its buffs) or **All of Party Frames**; **Copy To…** gives
the edited group's place and icon look to another group (**Curse Look to
Bleed**; which auras it shows stays its own). Groups
on the same anchor and place continue in one row, in the table's order, placed
and grown by the first one that is shown; move a group to another anchor to
place it on its own.

While the Auras tab is open the preview shows one larger member with only the
group being edited, beside a quick list of that kind's groups (click one to
edit it; dimmed ones are off; + on Tracked Buffs).

## Settings page

The standard tabs (docs/DESIGN_LANGUAGE.md, "Standard tabs"; November 21,
2026), each card on the tab of its idea:

| Tab | Cards |
|---|---|
| General | Show, Size, Arrange, Power Bar |
| Fill | Health Bar, Power Bar, Incoming Heals, Shields |
| Border | Border, Aura Borders, Rims, Dispel Overlay, Type Colors |
| Glow | Highlights, Aura Glows, Text Glows |
| Text | Text Style, Texts and Icons, Power Text |
| Auras | Which Auras, Placement, Icons |
| Behavior | Fade |

**Aura Kind** and **Aura Group** sit above the tabs while Border, Glow or
Auras is open. **Reset…** and **Copy To…** are in the window's footer.

## Settings preview

One member by default. The buttons in the preview header (**One**, **Party**,
**Raid 10**, **Raid 20**, **Raid 40**) show more, raid sizes in groups of five
side by side. Each keeps its scale and the preview grows taller to hold it;
only a layout too big for the window is scaled down, so nothing clips.

Each tab shows what it edits on the first sample, and stops when you leave
it: a healer with mana on **General**, **Fill** and **Text** (so the power
bar shows whichever Power Bar For is picked); the heal and a shield (the
overshield with that state) on **Fill**; the picked element on **Text**
(ready check, summon, dead, raid marker, leader); and the picked dispel
type's overlay on **Border** (with **Preview as Your Target**).
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

## Role After Name, Healer layout (November 19, 2026)

- **After Name** (Text tab, Role element; `roleAfterName`, off by
  default): the role icon hangs from the name's end, its Offset X and Y
  counted from there. The name then takes no width (`SetWidth(0)`: the
  client sizes it to its text; a character name is at most 12 letters) and
  the icon is anchored to its right end. Nothing reads either size back, so
  a secret name still draws; whether the client places the icon right for a
  secret name is the in-game check. With the name hidden the icon keeps its
  own place.
- **Healer layout** (`Modules/PartyFrames/Layouts.lua`, new profiles only):
  you and your party (Show Player on; Show When Solo on, so alone you see
  your own frame), 136 x 64 each (135 x 65 asked; members
  are an even number of pixels): Health 58, the line, Power 3 on healers.
  Mode-Border in its own metal, Mode-FG in Dark over Mode-BG, Background Opacity 85. The name
  (11) at the top left, 4px in, with the role icon (10) 2px after it; health
  percent (12) in the middle. Debuffs (Other Debuffs and each dispel type)
  at the bottom left, 20 x 18, up to 3 each; Dispellable by You on its own
  anchor (Left, inside, Y -1) so it starts its own row 1px over the debuffs,
  22 x 20, up to 2 (three would reach the health text); Healing Buffs at the
  bottom right, 22 x 18, up to 3. Group Buffs, Tracked Buffs and Defensives
  hidden (Defensives until its double icon is fixed). Gradient Opacity 35.
  Hung from the Player mana frame's bar block (owner, November 20, 2026;
  seed `healer@6`): its top right on the block's bottom right, 1 down (and,
  with the 1080 places, one physical pixel left: the owner's Edit Mode nudge
  on 1440p at UI height 1200, where the frame and the secure header round
  to whole pixels the other way; the 1440 places are pixel perfect), so
  its right edge is the block's real one at any UI scale and the first
  member sits snug under it (the block's shadow on its top pixel); the last
  member's bottom edge is level with Essential's second row (bands lined
  up, shadows on one pixel). Placed on the screen, it was off by a few
  pixels at 1.2 pixels a unit: hung from its middle the stand-in rounded
  short, and at x -323 it sat 2px right of the frame. A size change of the
  stand-in no longer moves an edge its saved place pins (Ghost.lua), and an
  element's move or resize re-places what hangs from it
  (Shared/Placement/PositionRestore.lua). The live
  header hangs by the point it lays members out from (Top for a column
  growing down) on the stand-in's same point, not by a corner: Blizzard's
  SecureGroupHeaders centers each member on that point and sizes the header
  itself, so a header a little wider than its members moved the column 2px
  right of the Player frame's edge (owner, November 20, 2026).
- **Not yet:** one cap of 3 for the whole bottom-left row (each group keeps
  its own maximum today, so several types can show more than 3 together).
- **Defensives showing twice** (owner): no spell list is involved. With
  Which Auras on Big and External (the default), the two Blizzard aura
  groups (`defensives1`, `defensives2`, one per flag) each run their own
  filter, so an aura with both flags shows in both. Profiles built before
  Mode-Default round 7 are still on Big and External. Fix to come after the
  in-game `/dump` check (the Healer prototype's Blizzard API tab).

## Mode-DPS/TANK layout (November 18, 2026)

The party frames' part of the built-in **Mode-DPS/TANK** layout (DPS / Tank,
`Shared/Runtime/Layouts.lua`), from the owner's layout editor, is in
`Modules/PartyFrames/Layouts.lua`. It only builds the new Mode-DPS/TANK
profile; no existing profile changes.

- On, without you (`showPlayer = false`: you have your own frame), growing
  Down, Spacing 1, power bars for Healers only (`powerShown = "healers"`).
- Each member 136 wide and 28 tall with its rim: 22 health, the 1px line, 3
  power (Below Health) and the 1px rim top and bottom. Below Health keeps the
  power row for everyone, so every member is 28; a member without a power bar
  fills it with health. The editor drew 135 wide, but members are always an
  even number of pixels (`Layout.lua`, Geometry), so 135 would draw 136.
- Aura icons by the owner's 6px rule (6 wider than tall): Healing Buffs 18 x
  12, Defensives 22 x 16, Dispellable by You, Other Debuffs and each debuff
  type 20 x 14, Crowd Control 24 x 18, Group Buffs and the Tracked Buffs
  groups 16 x 10. Everything else keeps its default.
- Health in **Dark** (`healthColorMode = "default"`; owner's tuning,
  November 18, 2026).
- 8px taller (owner, November 18, 2026): 30 health, so each member is 36
  tall with its rim (the stand-in 5 x 36 + 4 = 184). Buffs: only
  **Defensives** shows, set to **Big Defensives**; Healing Buffs, Group Buffs
  and the Tracked Buffs groups are off. Debuffs keep their defaults.
- Every member's edges (the frame, an inset power bar, the dispel rim) are
  drawn in pieces in every profile: a member is shorter than the ring art,
  whose sliced corners read square (DESIGN_LANGUAGE.md, "Pieces").
- Place: the right edge at x -359 from the screen's centre (the Player
  portrait's outer edge: -256 less half its 206 width), the four members'
  middle at y 40 (1080) or -1 (1440). The Edit Mode stand-in is always sized
  for five (5 x 28 + 4 = 144 tall) and the header fills it from the top, so
  without you the four members (115 tall) take its top part. The layout
  writes the stand-in's RIGHT on the screen's CENTER at x -359, y 26 (1080)
  or -15 (1440): 14.5 under the group's middle, rounded, so the group's middle
  sits half a pixel over the editor's.

## Saved settings

`ModeUIDB` profile `modules.partyFrames` (version 7) and the position
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
and the shield look settings arrive at the standard look. Version 5 settings
migrate to the aura edge: Border Size 3 becomes 2 and the old no-type rim
takes the Gunmetal one. Version 6 settings migrate: health and power
Background Opacity still at 100 takes the see-through 60.

## In-game check

- **Navigation:** type `/modeui`, then pick **Frames** › **Party Frames** in the
  sidebar.
- **Action:** look at the edges of the frames. In the preview header, click
  **Party**. Open **Border** and pick **Curse** under **Type**. Open
  **Fill**, and in **Shields** pick **FG** under **Texture**, **Custom** under
  **Color**, and drag **Shield Opacity** to 150%. Open **General** and pick
  **Healer Mana** under **Power Bar For**. Open **Auras**,
  click an aura in the preview, pick **Tracked Buffs 1** in the quick list,
  click **+**, and click a buff.
- **Required state:** out of combat; a party (or **Show When Solo**) for live
  members, and a buff on you or a party member for the picker.
- **Confirmation:** each member has a thin rounded Gunmetal rim, and the
  rims sit exactly one pixel apart, matching the Group Frames probe. The
  Warrior sample's rim is red (aggro) and the Mage's is Ivory (your target).
  Names fade from the class color toward white; the health text is green at
  full and red under 30%. All five Party samples fit in the preview. The
  first sample shows a purple Curse gradient from its top edge. On Fill,
  the first sample's shield turns to Mode-FG in the custom color and grows
  stronger with Shield Opacity. The health bars use Mode Glass. Only a healer
  with mana shows a power bar. Clicking the aura opens the Auras tab. The
  picked buff shows in Tracked Buffs 1's place on the frames.
