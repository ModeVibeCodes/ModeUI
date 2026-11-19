# Interface: Buffs & Debuffs

November 17, 2026. **Built on branch `t3/buffs-debuffs` and merged into
`main` on the owner's word (November 17).** A module in the sidebar's **Interface** group (category `frames`),
after Party Frames. Off by default; a profile whose Unit Frames Player frame
showed auras starts with it on. Planned and approved on the canvas
https://claude.ai/artifact/73o8fB82wKRQUS314hvg5E (the owner's saved picks
are the defaults). APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#buffs--debuffs--november-17-2026).
Run in the client by the owner (November 17): the module, the handover from
Unit Frames, the stand-in and the icons confirmed, no Lua errors; gate items 5
and 6 (the Boss & Important bar and the bar picker row) were merged before an
in-game recheck (see [In-game gate](#in-game-gate)).

## History

| Commit | What |
|---|---|
| `13f6670` | The module: Mode aura bars on Blizzard's aura containers, the stand-in, custom bars, blacklist, the handover from Unit Frames |
| `6a16676` | First in-game look: Icon Width and Height, Icon Zoom (crop), Border Size and Gap, time and stack text settings, Player Debuffs 42 wide with a 2px border, the `BuffFrame.lua:177` error fixed (settings version 2) |
| `dfdc340` | Every icon drew black: the art's clip frame layered above the icon frame |
| `6c11507` | Player Debuffs (Boss & Important), the (All) label, the bar picker's buttons on their own row |
| November 18 | Second look: Spells You Add, Defensives a preset in the owner's look, kinds kept across a switch, Boss off in (All), ON/OFF in the bar list, Which Auras under the preview, Bar Behavior, border padding, shift, offsets and color, the Texts tab with a sample aura, white time and green stacks (settings version 3) |

## What the owner asked for

- Blizzard's player buffs and debuffs by the minimap in the Mode look, in the
  **Mode-Blizz** border, icons **6px shorter than wide**.
- The Player frame's buffs and debuffs controlled here: aura bars the player
  makes, each picking categorized groups, resized, styled (look, borders,
  effects), with a **blacklist**, free-positioned with anchoring options.
- The Player frame's aura settings leave **Unit Frames**.
- After the canvas (owner, November 17): a **1px band** everywhere, debuffs
  **colored by type** on most bars, the canvas layout.
- After the first in-game look (owner, November 17): width and height each
  adjustable (4 or 6px shorter by default), text settings on every bar (time
  and stacks: place, size, color, offsets), Player Debuffs much bigger (42
  wide) with a 2px border and cropped icons, Border Size and offsets on every
  border, and the BuffFrame error fixed.
- After the second look (owner, November 18): the Defensives bar didn't show
  a personal defensive; Defensives keeps its kind (an accidental switch to
  Debuffs lost its picks); Boss Debuffs off in Player Debuffs (All); ON/OFF
  in the bar list; Which Auras under the preview, the preview a little
  bigger and naming the bar; Max Shown and Per Row with Grow under **Bar
  Behavior**; **Border Padding** (was Border Gap), a Border Size slider,
  border offsets, shift and a custom color; Defensives in the owner's look;
  the time and stack settings on one **Icon Texts** card in a **Texts** tab
  with a sample aura; white time text and green (`#53F24F`) stacks.

## Decisions (owner, November 17, 2026)

1. **Stand in** for Blizzard's frames (not reskin in place): Blizzard's
   `BuffFrame` and `DebuffFrame` step aside and stay as Edit Mode anchors;
   the Buffs and Debuffs bars sit in their place.
2. **Player only** moves out of Unit Frames; Target, Target of Target, Focus
   and Target of Focus keep their auras there.
3. Icons were first always width − 6; after the in-game look (owner,
   November 17) **Width and Height are each a setting**, the height starting
   at the design rule (`Style.IconHeight`: 4px shorter under 36 wide, 6px
   from 36) and following the width until it's changed.
4. Time text **below** the icon by default (Player bars and Defensives: on
   the icon, the owner's picks).
5. Sidebar: the caption **Interface** is category ID `frames` (Unit Frames,
   Nameplates, Party Frames); ID `interface` is captioned **Panels**.

## Research

### Forever's Blizzard source

From Gethe/wow-ui-source, branch `forever` (paths under `Interface/AddOns/`).
Forever runs as game type `camelot` in the `mainline` family.

- **The buff frame** is the plain mainline `Blizzard_BuffFrame`
  (`BuffFrame.lua`, `BuffFrame.xml`, `BuffFrameTemplates.xml`); no Camelot
  override. Globals `BuffFrame`, `DebuffFrame`, `DeadlyDebuffFrame`,
  `ExternalDefensivesFrame`. Buttons are unnamed `AuraButtonTemplate`s in
  `.auraFrames` (32 buffs, 16 debuffs, plus `DebuffFrame.privateAuraAnchor1-6`),
  with `.Icon`, `.Duration` (below), `.Count`, `.DebuffBorder`,
  `.TempEnchantBorder`, `.Symbol`. Not secure.
- **Layout:** `AuraContainerMixin:UpdateGridLayout` resizes every button
  (30 × 40) and re-anchors `.Icon` and `.Duration` each pass. Updates run
  `UpdateAuras` → `UpdateAuraButtons` → `button:Update(info)` on `UNIT_AURA`.
  Post-hook points: `BuffFrame`/`DebuffFrame` `UpdateAuraButtons` and
  `UpdateGridLayout`. Never replace them: Blizzard's code compares aura fields
  (`count > 1`, `expirationTime - GetTime()`), which only works untainted.
- **Cancel:** Blizzard's button calls `CancelUnitBuff` on right-click; weapon
  enchants `C_Spell.CancelItemTempEnchantment`. `C_UnitAuras.CancelAuraByInstanceID`
  is `RequiresUnitAuraAccess`, `HasRestrictions`. Addon code never cancels
  auras itself.
- **Edit Mode:** `Enum.EditModeSystem.AuraFrame` (Buff 1, Debuff 2, External
  Defensives 3): Orientation, Icon Wrap, Direction, Limit, Icon Size (50-200%),
  Padding. No Hidden option for the Buff and Debuff frames.
- **Hiding them:** they show themselves again (`UpdateShownState` on
  `PLAYER_IN_COMBAT_CHANGED`) and the status tray moves `BuffFrame`. A lasting
  hide is `UnregisterAllEvents` and a hidden parent, never a write to their
  fields.
- **Secret values:** no exemption for the player's own auras. Aura reads are
  `SecretWhenUnitAuraRestricted` (combat, encounters, challenge modes, PvP);
  `GetUnitAuras` is `ConditionalSecretContents`. `GetAuraDuration` returns a
  duration object. Runtime checks: `C_Secrets.ShouldAurasBeSecret()`,
  `C_Secrets.GetSpellAuraSecrecy(spellID)`.
- **No `SecureAuraHeaderTemplate` route.** Blizzard's UI loads it only on
  Classic, and it needs the addon to read auras by index, which fails while
  auras are secret.
- **`CustomAuraContainerTemplate`** (`Blizzard_AuraContainer`, files identical
  to Retail 12.1.5; ModeUI already uses it in Nameplates and Party Frames):
  `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")`,
  `SetUnit("player")`, `AddAuraGroup(key, filter, { maxFrameCount, layout,
  initializeFrame, candidateFilters, sortMethod, sortDirection })`, setters per
  group, `AddItemEnchantment(slot, options)` for weapon enchants, private
  auras included by default, flow layout (`SetFlowLayoutAxis`,
  `SetFlowLayoutAnchorPoint`, `SetFlowLayoutGrowthDirection`,
  `SetFlowLayoutMaximumLineSize`), sorts (`Default`, `Expiration`, `Name`, ...).
  Buttons: `SetIcon`, `SetApplicationCount`, `SetDurationCooldown`,
  `SetDurationText` (any FontString we place, so text below the icon works),
  `AddDispelTypeTexture`, tooltips, `SetCancelAuraButtons("RightButtonUp")`.
  Buttons get `DenyTaintedAccessWhenAurasAreSecret` (from
  `PLAYER_ENTERING_WORLD`): style them in `initializeFrame` only.
- **Candidate filters:** `includeSpellIDs`, `excludeSpellIDs`,
  `includeDispelTypes`, `excludeDispelTypes`, `maxDuration` (also drops
  permanent auras), and booleans (`isFromPlayerOrPlayerPet`, `isBossAura`,
  `isStealable`, `isRoleAura`, ...). Unknown keys are ignored silently.
  **Spell-ID filters skip harmful auras on a unit you can assist, the player
  included**, unless the spell is never secret
  (`AuraContainerUtil.CanApplyIdentityCandidateFilters`); with
  `includeSpellIDs` such a debuff is rejected outright.
- **Filter components** (`AuraUtil.AuraFilters`): HELPFUL, HARMFUL, PLAYER,
  RAID, CANCELABLE, INCLUDE_NAME_PLATE_ONLY, MAW, EXTERNAL_DEFENSIVE,
  CROWD_CONTROL, RAID_IN_COMBAT, RAID_PLAYER_DISPELLABLE, BIG_DEFENSIVE,
  IMPORTANT, DISPELLABLE. `NOT_CANCELABLE` is gone: use `!CANCELABLE`.
  Dispel type names: Magic, Curse, Disease, Poison, Bleed (Enrage unconfirmed
  as a candidate filter key).
- **Forever's player frame** (`Blizzard_UnitFrame/Camelot/PlayerFrame.lua`)
  draws no auras; the ModeUI Player frame's auras are ModeUI's own
  (`Modules/UnitFrames/Auras.lua`).
- **Weapon enchants:** `C_Item.GetWeaponEnchantInfo` or
  `C_PaperDollInfo.GetTemporaryEnchantmentInfo`; the global
  `GetWeaponEnchantInfo` is a deprecation fallback. `TemporaryEnchantFrame` is
  gone; enchants are TempEnchant buttons inside `BuffFrame`.

### Open-source addons (ideas only)

Licenses: oUF and rothui are MIT, SpartanUI MPL-2.0; ElvUI, BetterBlizzFrames,
EllesmereUI and RealUI are all rights reserved; the Masque Blizzard-buffs
skinner, Plater and SUI have no license file. **No code is copied**; these
inform the design only.

- **BetterBlizzFrames** (`forever/modules/auras.lua`), the closest match:
  unregisters Blizzard's frames, parks the buttons on a hidden frame, draws
  containers in their place, keeps `BuffFrame` as the Edit Mode anchor and
  reads its layout fields, refreshes on the `EditMode.Enter`/`Exit`
  callbacks. Splits the blacklist with `C_Secrets.GetSpellAuraSecrecy`.
- **ElvUI**: containers for player auras on Retail and Forever
  (`CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate`),
  `AddItemEnchantment`, `SetCancelAuraButtons` (Up or Down from the
  `ActionButtonUseKeyDown` setting), groups updated in place, blacklist as
  `excludeSpellIDs`.
- **oUF** rewrote its auras for 12.1 on containers only.
- **Masque's Blizzard-buffs skinner**: the in-place pattern (post-hooks on
  `UpdateAuraButtons`, `UpdateGridLayout`, `OnEditModeEnter`; mirrors the icon;
  falls back when the debuff border's atlas is secret).
- **EllesmereUI**: its debuff "Hide Exhaustion" works only because that spell
  is never secret; reports that a right-click cancel on button-up can start
  mouselook instead.
- **SpartanUI, SUI**: tainted aura reads (`GetAuraSlots`) error while auras are
  secret; pcall-wrapped hooks are fragile.


## As built

### Bars

Every bar is one `CustomAuraContainerTemplate` on unit `player` in a ModeUI
holder; the holder follows the bar's mover, the Edit Mode element (named
`ModeUIBuffsDebuffs<Id>Mover`, element `buffsDebuffs<Id>`) sized for a full
bar so anything anchored to it stays put as auras come and go. The game
forbids anchoring frames to a container, so other bars anchor to movers.

| Bar | Shows (default) | Place (owner's canvas) | Look |
|---|---|---|---|
| Buffs | All Buffs, Weapon Enchants; 32 max, 10 a row | Blizzard's Buff Frame (`frame:BuffFrame`), top right on top right | 32 x 28, 4px apart, grows left, rows down, time below |
| Debuffs | All Debuffs; 16 max, 10 a row | Buffs' top right, 4 right and 147 down | as Buffs, rims by debuff type |
| Player Buffs | Important, Heals Over Time, Yours; 12 max, 8 a row | under the ModeUI Player Frame's right end (top right on bottom right, -6, -2) | 24 x 20, 2px apart, grows left, time on the icon |
| Player Debuffs (All) | Crowd Control, Dispellable by You, Magic, Curse, Disease, Poison, Bleed, Other (Boss Debuffs off by default, owner November 18); 8 max, 6 a row | above the ModeUI Player Frame (top right on top right, 2, 131) | 42 x 36 (owner, after the first in-game look), 2px border, 3px apart, Mode-BlizzEmpty, rims by type, time on the icon |
| Player Debuffs (Boss & Important) (owner, November 17) | Important (`IMPORTANT`), Boss (that aren't Important); 6 max, 6 a row | 6px above Player Debuffs (All), right edges lined up (bottom right on its top right, 0, 6) | 48 x 42, 2px border, 3px apart, Mode-BlizzEmpty, rims by type, time on the icon |
| Defensives (custom, a preset) | Spells You Add, Big and External Defensives, Important; 4 max | left of center (-151, 27) | 42 x 34, 2px apart, Icon Zoom 8, Mode-Thin Silver 2px, Soft glow in Aura Gold, time on the icon, swipe, no tooltips, no right-click cancel (owner, November 18) |

Boss Debuffs can still be picked in Player Debuffs (All). Defensives is a
**preset**: a custom bar (renamed, deleted, styled like any) that always
shows buffs and has no right-click cancel. Switching another custom bar
between Buffs and Debuffs keeps what each kind had picked (`otherCats`).
Player Buffs' rows
go down (the canvas had Up, which would cover the frame
once a second row starts). Custom bars: **+ New Bar** (eight at most),
renamed, deleted (what hangs from one moves to where it is).

### What a bar shows

One aura group per kind picked, in this order (an aura shows once):

- Buffs: Spells You Add (the bar's own list, up to 24, as
  `includeSpellIDs`, which the game applies to buffs on the player; the
  bar's other kinds leave them out with `excludeSpellIDs`), Big Defensives
  (`BIG_DEFENSIVE`), External Defensives
  (`EXTERNAL_DEFENSIVE`), Important (`IMPORTANT`), Heals Over Time
  (`RAID_IN_COMBAT`), Yours (`PLAYER`), Cancelable (`CANCELABLE`), Under a
  Minute (`maxDuration` 60), All Buffs; Weapon Enchants are the container's
  item enchantments (main and off hand, after the groups).
- Debuffs: Crowd Control (`CROWD_CONTROL`), Dispellable by You (`RAID`),
  Important (`IMPORTANT`),
  Boss Debuffs (`isBossAura`), Magic, Curse, Disease, Poison, Bleed
  (`includeDispelTypes`), Other (`excludeDispelTypes` all five), All Debuffs.
- Each token kind adds `|!<token>` for the token kinds before it. All stands
  alone (picking it clears the rest; picking another clears All). A boss
  debuff with a type can show twice (Boss and its type): `isBossAura = false`
  isn't safe to send.
- Max Shown is per kind (each group's `maxFrameCount`); Sort is the game's
  Default, Expiration (Time Left) or Name.

### Buttons

Styled once in `initializeFrame` (`Bars.lua`, the look in `Icons.lua`): the
button is the cell (the icon plus room for time text under or over it: its
size and 2px); the Mode icon (`Kit.AuraIconParts`) on a child frame, Width x
Height, in the bar's Border Style, Metal (or **Custom Border Color**) and
Size, pushed out or in by **Border Shift** and moved by **Border Offset
X/Y** (the band's frame moves; the art stays). The art is cropped by
size, not texture coordinates (the game sets each aura's texture itself): a
square **Icon Zoom**% wider than the visible part on each side, centered in a
frame that clips it (`SetClipsChildren`), a **Border Padding** inside the band.
That frame sits one level above the icon frame, whose black back drew over
the art at the same level (every icon black in game, fixed November 17).
Time text below, above or on the icon and the stack count in any corner,
each with its own size, color and X/Y offset (the module's font, outline and
shadow); swipe; a flat rim the game colors by debuff type
(`Kit.DispelAuraRim` on the child); Soft or Flash glows (by type or a
color); the game's tooltip (bottom left); on buff bars right-click cancel
(`SetCancelAuraButtons`, Up or Down by Cast on Key Down). A new look builds a
new container (the old one disabled); kinds, counts, layout and sorting
change in place; candidate filters only when the blacklist changes (they
make the game read every aura again).

### Blizzard's frames

While the Buffs (Debuffs) bar shows, `BuffFrame` (`DebuffFrame`) is
unregistered and its `AuraContainer`, collapse button and consolidated buffs
are hidden where they are and kept hidden (`Skin.Suppress`). They keep their
parent: Blizzard's layout calls `AuraContainer:GetParent():UpdateSize()`, and
the first build, which moved the container to a hidden frame, made it error
in game. The frame stays where Blizzard's Edit Mode puts it, as the Buffs
bar's anchor. Hiding the bar or switching the module off asks for a reload
to bring Blizzard's back. `DeadlyDebuffFrame` is left alone.

### Blacklist

One list for every Mode bar (64 spells), sent as `excludeSpellIDs`. Defaults:
Well Fed (104280) and Sated (57724), the owner's picks. Buffs always hide;
the player's own debuffs hide only when `C_Secrets.GetSpellAuraSecrecy` says
never secret: the picker rims those Celadon and the rest Rosewood ("hidden as
a buff; as your debuff the game may still show it").

### Edit Mode and the settings page

In ModeUI's Edit Mode each shown bar's container waits and its holder fills
with sample auras in its look (`Samples.lua`); the mover shows over them.
The page (split layout, Auras icon) previews the bar being edited with the
same samples, at up to 125%, under its name and ON or OFF; in the preview
pane the bar's **Which Auras** card (a button per kind) fills the room under
it (on the Bars tab only when the window has no pane). The bar list marks
every bar ON or OFF. Tabs: **Bars** (bar picker, + New Bar and Delete Bar on
their own row, name, Show This Bar, Shows for custom bars that aren't
presets; Spells You Add on buff bars: + Add or Remove Spells; Bar Behavior:
Sort, Max Shown, Per Row, Grow, New Rows Go), **Look** (Icon Width, Icon
Height, Spacing, Icon Zoom, Timer Swipe, Tooltips, Right-Click Cancels;
Border Style, Border Metal, Border Size, Border Padding, Border Shift,
Border Offset X/Y and Nudge, Custom Border Color and Border Color, Rim
Colored by Debuff Type; Glow, Glow Color, Custom Color), **Texts** (the Icon
Texts card with a sample aura at its in-game size in the top right: Time
Text Below, Above, On Icon or None, Time Size, Time Color, Time Offset X/Y
and Nudge; Show Stack Count, Stack Corner, Stack Size, Stack Color, Stack
Offset X/Y and Nudge), **Blacklist** (+ Add or Remove Auras), **Module**
(Text: Font, Outline, Shadow; Reset to Defaults). The blacklist picker also
edits a bar's Spells You Add (buffs on you, or by spell ID).

### Saved settings

`ModeUIDB` profile `modules.buffsDebuffs` (settings version 3): `bars[id]`
(show, kind, cats, otherCats, spells, sort, max, perRow, width, height,
spacing, crop, grow, wrap, timer, timerSize, timerColor, timerX, timerY,
swipe, count, countPoint, countSize, countColor, countX, countY, tooltip,
cancel, edgeStyle, edgeMetal, borderSize, borderGap (Border Padding),
borderShift, borderX, borderY, borderTint, borderColor, byType, glow,
glowColor, glowCustomColor), `customBars` ({ id, name, preset }),
`nextCustom`, `blacklist`, and the text keys
(font, fontMedia, outline: none, outline or thick; shadow, liftedShadow,
slug, textColor, timerColor). Places under `positions`. Version 2 gives each
bar its height (the design rule from its width) and text sizes, makes Player
Debuffs 42 wide with a 2px border where still at the old 30 and 1px, and
turns the outline into a choice. Version 3 (`M.MigrateV3`) makes time
text white and stacks green where still at the old colors, takes Boss
Debuffs out of Player Debuffs (All) when it still had the old picks, and
makes the profile's first custom bar, when it's still the Defensives bar,
the preset in the owner's look (each value only where still at the old
default; right-click cancel off). Unit Frames keeps `player.buffs` and
`player.debuffs` untouched; `M.Adopt` (a module hook in
`DB:ValidateProfile`) turns this module on once when either showed.

### Mode-Default layout

`Layouts.lua` adds this module's part of the built-in Mode-Default layout
(DPS / Tank, `Shared/Runtime/Layouts.lua`); it only writes a new profile. The
same at 1080 and 1440. The module is on.

| Bar | Settings | Place |
|---|---|---|
| Buffs | 30 x 24, 12 per row, 24 max, Grow Left, New Rows Down, Spacing 4, time below | TOPRIGHT on the Minimap's TOPLEFT, (-10, 2) |
| Debuffs | the same, 16 max | TOPRIGHT on the Minimap's BOTTOMLEFT, (-10, 73) |
| Player Buffs | 30 x 24, 5 per row, Spacing 1 | TOPRIGHT on ModeUI Player Frame Bars' BOTTOMRIGHT (the bar block), (0, -1) |
| Defensives (`custom1`) | 40 x 34, 4 max | RIGHT on the screen's CENTER, (-124, 166) |

Player Debuffs (All) and Boss & Important keep their defaults. The owner's
layout editor drew each icon as its size plus 2px of edge each side (3 for a
2px border), rows 39 tall, and the minimap as what shows of it. In game a
bar's element is its cells exactly: the border is inside Width x Height, only
the icon's 1px shadow shows past it, and a cell with the time below is the
icon plus Time Size + 2 (36 tall here). The Minimap element is the map alone,
its edge 3px past it. So the places put outer edges on outer edges: 6px from
the minimap's edge is -(6 + 3 + 1) = -10; Buffs' icon tops on the minimap's
top is 3 - 1 = 2; Debuffs' two rows (2 x 36 + 4 = 76, `M:BarSize`) end on
the minimap's bottom at 76 - 3 = 73 (the editor's 82 counted 39-tall rows);
Defensives' right edge at -123 is -124 for the element. Player Buffs (owner's
tuning, November 18, 2026) hang from the Player frame's bar block
(`unitFramesPlayerBars`, its band on the block's edge), so Portrait Size,
Health Height and Frame Width never move them into the frame: icons 1 under
the block share that band's shadow pixel, right edges lined up; five to a
row (154 wide) stay clear of the portrait ring at every Portrait Size and
Health Height while Frame Width is 161 or more (`tests/layouts.lua` checks
it; the layout uses 166), Spacing 1 so neighbours share one shadow
pixel as the Cooldown Manager's icons do. Every aura icon's rim is drawn in
pieces, each piece registered for the dispel color (DESIGN_LANGUAGE.md,
"Pieces"). Icons show 2px
smaller each way than the editor drew them (32 x 26 with the shadow, not
34 x 28; Defensives 42 x 36, not 46 x 40).

### Files

`Modules/BuffsDebuffs/`: `Init.lua` (declaration, bars, kinds, defaults),
`Layouts.lua` (its part of the Mode-Default layout),
`Migrations.lua` (validation, Adopt), `Driver.lua` (lifecycle, setters,
custom bars, blacklist), `Placement.lua` (sizes, movers, holders),
`Icons.lua` (an icon's look: size, crop, border, texts), `Bars.lua`
(containers, groups, buttons), `Blizzard.lua` (the stand-in), `Samples.lua`,
`Preview.lua`, `Settings.lua`, `SettingsBar.lua` (Bars tab),
`SettingsLook.lua` (Look tab, Module text), `SettingsText.lua` (Texts
tab), `Blacklist.lua` (Blacklist tab, the picker). Shared:
`Style/Tone.lua` (`auraStack`), `Runtime/DB.lua` (Adopt), `Domain/Auras.lua`
(`NeverSecret`, `Spells`), `Kit/AuraIcon.lua` (`DispelAuraRim` on a child),
`Kit/AuraContainer.lua` (`AuraTimeFormatter(hours)`), the Auras icon
(`tools/mode_icons.lua`, `Style.ICONS`). Unit Frames: `Auras.lua`
(`ShowsAuras`), `SettingsExtra.lua` (the Player's Auras tab). Tests:
`tests/buffs_debuffs.lua`, `tests/unit_frames.lua`, `tests/smoke.lua`.

Not built (from the plan): reskin in place (decision 1 went to stand in);
moving Party Frames' aura catalog into Shared (left alone so a confirmed
module doesn't change).

### Extending it

- **A new kind:** one entry in `M.categories[kind]` (`Init.lua`) with an `id`,
  a `label` and one of `token` (an `AuraUtil.AuraFilters` name), `dispel`,
  `boss`, `maxDuration`, `other`, `all` or `enchant`. Order matters: a token
  kind excludes the token kinds before it. Give the samples that count as it
  its id in `cats` (`Samples.lua`); the label goes through `L[...]` (English
  is the fallback).
- **A new fixed bar:** its id in `M.FIXED`, `M.FIXED_LABELS` and
  `M.FIXED_KIND`, a `Bar(...)` in `M.barDefaults` and a place in
  `M.defaultPositions` (all `Init.lua`), a line in `NOTES` (`Settings.lua`).
  Its Edit Mode target is registered from `M.FIXED`, and
  `M.Initialize` gives existing profiles the bar on the next load, so no
  migration is needed (Player Debuffs (Boss & Important) came this way).
- **A new bar setting:** a default in `Bar(...)`, a check in `M.ValidateBar`
  (`Migrations.lua`), a control in `SettingsBar.lua` or `SettingsLook.lua`; if
  it changes how a button is built, it's part of `M:LookKey` (`Icons.lua`,
  a new container) automatically; a setting the container takes in place
  goes in that file's `LIVE` list. Change a shipped default only
  where the saved value still equals the old one (bump `SETTINGS_VERSION`).

## Known limits and open questions

- **An aura can show twice.** A boss debuff with a type shows under both Boss
  and its type in a bar that picks both (`isBossAura = false` isn't safe to
  send). Across bars nothing is left out: a boss debuff in Player Debuffs
  (Boss & Important) still shows in Player Debuffs (All) under its type or
  Other, since no filter can say "not a boss aura".
- **Big Defensive is the game's flag.** Forever may not flag every class's
  personal defensive (owner, November 18: the Defensives bar stayed empty);
  in game `/dump C_UnitAuras.AuraIsBigDefensive(spellID)` tells. Spells You
  Add shows any buff on you by spell ID whatever its flags.
- **The blacklist and your own debuffs.** The game skips spell filters for
  harmful auras on the player unless the spell is never secret; the picker
  marks which.
- **Bringing Blizzard's frames back** (hiding Buffs or Debuffs, or turning
  the module off) asks for a reload: they were unregistered.
- **Blizzard's Edit Mode settings** for its Buff and Debuff frames (Icon Size,
  Padding, Limit, ...) don't reach the Mode bars; only the frame's place
  does, as the Buffs bar's anchor.
- **Combat:** settings changes and Edit Mode moves wait until combat ends;
  the bars themselves keep updating (the containers are Blizzard's).
- **Enrage** isn't offered as a type: unconfirmed as a candidate filter key.
- **Border Size** is a slider from 1 to 2px: the Mode art comes in those
  two bands.
- **Border Shift** was read as pushing the band out from the icon or in over
  it, and **Border Offset X/Y** as moving it (owner, November 18); Border
  Padding (formerly Border Gap) is the room between the art and the band.

## In-game gate

First look (owner, November 17, 2026): the module, the handover and the
stand-in work; Blizzard's buff frame errored (`BuffFrame.lua:177`), Player
Debuffs were too small with borders hard to see, Player Buffs' border didn't
read, and text wasn't adjustable. All addressed above. Recheck, after
`/reload` on this branch:

1. **No errors.** Navigation: the game world, then Blizzard's Edit Mode
   (Game Menu › Edit Mode) and out again. Action: `/reload`, open and close
   Blizzard's Edit Mode, mount and dismount. Required state: out of combat,
   error display on. Confirmation: no `BuffFrame.lua` errors; Blizzard's
   buffs and debuffs stay hidden; the Mode bars stay in place.
2. **Icons.** Navigation: the game world. Action: look at Player Debuffs and
   Player Buffs with a few auras up. Required state: auras on you.
   Confirmation: Player Debuffs 42 x 36 with a 2px border that reads; every
   icon cropped (no game icon frame inside the Mode border); Player Buffs'
   border visible.
3. **Size and border.** Navigation: `/modeui`, **Interface** › **Buffs &
   Debuffs**, **Look** tab. Action: pick a bar; change **Icon Width** (the
   height follows), then **Icon Height**, **Icon Zoom**, **Border Size** and
   **Border Gap**. Required state: out of combat. Confirmation: the preview
   and the bar follow; the height stops following the width once set.
4. **Text.** Same tab. Action: set **Time Text** to Below, Above and On Icon
   with a size, color and offset (try the nudge arrows); move **Stack Count**
   to another corner, size and color; under **Module** › **Text** pick a
   font, **Outline** and **Shadow**. Required state: out of combat.
   Confirmation: live auras and the preview take each change.

Icons confirmed in game (owner, November 17: "Looks good"). Then (merged
into `main` before this recheck; still to confirm):

5. **Boss & Important.** Navigation: the game world, then **Edit Mode** in
   the ModeUI window header. Action: look above Player Debuffs (All); pick
   **Player Debuffs (Boss & Important)** in the **Bar** dropdown on the
   **Bars** tab. Required state: a boss or an Important debuff on you if
   possible (Edit Mode shows samples). Confirmation: the bar sits 6px above
   Player Debuffs (All), right edges lined up, its icons 48 x 42.
6. **Bar picker.** Navigation: **Interface** › **Buffs & Debuffs**,
   **Bars** tab. Action: look at the right end of the **Bar** dropdown;
   click **+ New Bar**. Required state: out of combat. Confirmation: no
   clipped box beside the dropdown; **+ New Bar** and **Delete Bar** sit on
   the row under it (**Delete Bar** only for your own bars).

After the second look (owner, November 18; nothing below run in game yet):

7. **Defensives.** Navigation: `/modeui`, **Interface** › **Buffs &
   Debuffs**, **Bars** tab, **Bar**: Defensives. Action: use your personal
   defensive; if the bar stays empty, click **+ Add or Remove Spells** while
   it's up and click it under "Buffs on you now". Required state: out of
   combat to edit. Confirmation: the defensive shows on Defensives; the bar
   has no **Shows** choice and no **Right-Click Cancels**.
8. **Settings layout.** Same page. Action: open the **Bar** list; look under
   the preview; open **Look** and **Texts**. Required state: out of combat.
   Confirmation: each bar has ON or OFF; Which Auras under the preview;
   **Bar Behavior** holds Sort, Max Shown, Per Row, Grow; the Texts tab's
   **Icon Texts** card has a sample aura at the top right that follows the
   text settings.
9. **Border options.** **Look** tab. Action: move **Border Size**, **Border
   Padding**, **Border Shift**, the border offsets; turn on **Custom Border
   Color**. Required state: out of combat. Confirmation: the preview and the
   bar follow.
