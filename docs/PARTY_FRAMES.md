# Frames: Party Frames

November 13, 2026. A **Frames** module, after Nameplates. Off by default (turn it
on with the switch in the page header). Static/mock validated only; **native
acceptance is pending**. APIs and their secret-value rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#party-frames--november-13-2026).

## What it draws

You and your party (not a raid), one member under the next by default. Each
member is:

- **Bars**: health, plus an optional power bar under a 1px black hairline,
  inside the ModeUI border (`Kit.ModeBorder`: one 2px rim in #40454C with
  rounded ends). Foreground and background textures (Mode Gradient and Mode
  Slate at 70% by default), Bar Opacity, Background Opacity, fill direction
  and the 1px fill end line, as on the Unit Frames. **Power Bar For**:
  Everyone, Healers or No One. Without one, the health bar takes the whole
  height.
- **Health color**: Class Color (default), Onyx or Custom. Power: by power
  type or Custom.
- **Incoming heals and absorb shields**: two bars riding on the end of the
  health fill, each with its own color and opacity.
- **Texts and icons**, each with **Show**, **Anchor** (a compass of nine points),
  **Place** (Inside on the bars, or Outside past their edge on that side),
  **Offset X/Y** and **Size**: Name, Health Text (Percent, Current Health or
  Missing Health), Dead and Offline, Role, Leader, Raid Marker, Ready Check, and
  Summon and Resurrect (which also shows another phase). The name has Name Color
  (Class Color, Text Color or Custom) and Name Width. The role can hide the
  damage role. Font, outline, slug text, text shadow and text color are shared,
  with Expressway by default.
- **Highlights**: your target (Border: the member's border in the highlight
  color, cyan by default; Tint; or None), a mouse highlight, and the **Dispel
  Highlight**: the border (or a tint) in the debuff's type color while the
  member has a debuff you (or your group, or anyone) can dispel.
- **Fading**: out-of-range members at Out of Range Opacity (45%), dead and
  offline members at Dead and Offline Opacity (70%). You're always in range.

### The aura manager (Auras tab)

Five groups, each with its own settings:

| Group | Which Auras (default first) | Default place |
|---|---|---|
| Buffs | Yours, Your Heals Over Time, Raid Frame Buffs, Ones You Can Cast, All | inside bottom right, growing left, 3 |
| Debuffs | Raid Frame Debuffs, All, Ones You Can't Dispel, Yours | inside bottom left, growing right, 3 |
| Dispellable | Ones You Can Dispel, Ones Your Group Can Dispel, Any Dispellable | off; outside right |
| Defensives | Big and External, External Defensives, Big Defensives, Important | inside center, 1 of each |
| Crowd Control | Crowd Control | off; outside left |

Per group: **Show This Group**, **Which Auras**, **Anchor**, **Place**
(Inside/Outside), **Grow** (Right, Left, Up, Down), **Offset X/Y**, **Most
Shown**, **Per Row** (wraps into a new row), **Spacing**, **Icon Size**,
**Icon Shape** (Cropped, 4px wider than tall, or Square), **Borders** (By Type
or Mode), **Timer Swipe**, **Timer Text**, **Stack Count** and **Tooltips**.
**Reset Group** and **Copy Look To** (another group gets this group's place and
look; which auras it shows stays its own). Rim colors by dispel type (Magic,
Curse, Disease, Poison, Bleed, No Type) and the timer text color are shared by
every group and by the dispel highlight.

Which auras a group shows is a game filter string (`AuraUtil.AuraFilters`), so
the game decides and no secret aura field is compared. "Raid Frame" choices
are `RAID_IN_COMBAT`, the flag Blizzard's raid frames use in combat.

## How it works

- **Secure group header** (`SecureGroupHeaderTemplate`): the header lists you
  (Show Yourself) and party1-4, sorts them (Party Order, or by Role: tanks,
  healers, damage, using `groupBy = "ASSIGNEDROLE"`), reverses them (Reverse
  Order, `sortDir = "DESC"`), hands each button its unit and shows, hides and
  places the buttons, in combat too. ModeUI sets its attributes outside combat
  only. All five buttons are made up front (`startingIndex` set to -4, then 1),
  so none is created in combat, and each gets its face then
  (`initialConfigFunction` calls back with `CallMethod`).
- **Visibility**: a state driver shows the header in a party and hides it in a
  raid (`[group:raid] hide; [group] show; hide`), or always outside a raid with
  **Show When Solo**. The header has the `unitFrames` roleset, so UI modes hide
  it like Blizzard's unit frames.
- **Placement**: Edit Mode moves a plain stand-in the size of a full party
  (Position Manager refuses protected frames). The header is anchored to
  UIParent at the edge the group grows from (top for Down, left for Right, and
  so on), copied from the stand-in outside combat, so the group never shifts
  as members join or leave. **Grow** and **Spacing** become the header's
  `point` and `xOffset`/`yOffset`.
- **Blizzard's party frames**: with **Hide Blizzard's Party Frames** (on by
  default), `PartyFrame` moves under a hidden ModeUI frame outside combat. That
  hides both the classic party frames and the raid-style ones
  (`CompactPartyFrame` is its child). No Blizzard method is called and no event
  unregistered. Turning it off, or the module, puts `PartyFrame` back on its
  own parent.
- **Members**: each has its own event frame registered for its unit
  (`RegisterUnitEvent`) and follows the header's unit changes
  (`OnAttributeChanged`). Range is re-checked on `UNIT_IN_RANGE_UPDATE` and
  every 0.5 seconds.
- **Auras in the world** use Blizzard's custom aura containers
  (`CustomAuraContainerTemplate`, Shared/Kit/AuraContainer.lua), which keep
  working while auras are secret: one container per member and group (two
  container groups for Big and External), buttons styled once in the Mode
  look. The **dispel highlight** is an aura slot whose one button covers the
  bars and holds the border shape (or the tint); the game colors it by the
  debuff's type and shows it only while there is one. Clients without
  containers, and the preview and Edit Mode samples, use the reader in
  Domain/Auras.lua.

## Settings preview and Test on Screen

The page shows the sample party (Warrior, Priest, Mage, Rogue, Hunter) with a
leader, a raid marker, a ready check, a summon, a dead member, a faded
member, your target, heals, an absorb and a Magic debuff, laid out by the same
code. Clicking a bar, text, icon or aura opens its settings. **Test on Screen**
and Edit Mode show the same sample party where the frames sit.

## Saved settings

`ModeUIDB` profile `modules.partyFrames` (version 1) and the position
`positions.partyFrames`. Element keys are `<element>Show`, `Anchor`, `Place`,
`X`, `Y`, `Size` (for example `roleAnchor`); aura groups are under
`auras.<group>`.

## In-game check

- **Navigation:** type `/modeui`, then pick **Frames** › **Party Frames** in the
  sidebar.
- **Action:** turn the module on with the switch in the page header. Join a
  party (or turn on **Show When Solo** on the **Layout** tab). Open **Edit
  Mode** from the window header and drag the sample party. On the **Auras** tab,
  pick **Debuffs** in **Group**, then change **Anchor** and **Grow**.
- **Required state:** out of combat for every change; a party for live
  members.
- **Confirmation:** Blizzard's party frames are gone, and ModeUI's show you and
  your party in the Onyx look. Left-click targets a member and right-click
  opens its menu. The frames stay put in combat while members join or leave,
  and debuffs show and move as set on the Auras tab.
