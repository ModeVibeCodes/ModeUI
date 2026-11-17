# Interface: Buffs & Debuffs

November 17, 2026. **Built on branch `t3/buffs-debuffs`; waits on its in-game
gate.** A module in the sidebar's **Interface** group (category `frames`),
after Party Frames. Off by default; a profile whose Unit Frames Player frame
showed auras starts with it on. Planned and approved on the canvas
https://claude.ai/artifact/73o8fB82wKRQUS314hvg5E (the owner's saved picks
are the defaults). APIs and their rules are in
[API_COMPATIBILITY.md](API_COMPATIBILITY.md#buffs--debuffs--november-17-2026).
Static/mock validated only; nothing here has run in the client yet.

## What the owner asked for

- Blizzard's player buffs and debuffs by the minimap in the Mode look, in the
  **Mode-Blizz** border, icons **6px shorter than wide**.
- The Player frame's buffs and debuffs controlled here: aura bars the player
  makes, each picking categorized groups, resized, styled (look, borders,
  effects), with a **blacklist**, free-positioned with anchoring options.
- The Player frame's aura settings leave **Unit Frames**.
- After the canvas (owner, November 17): a **1px band** everywhere, debuffs
  **colored by type** on most bars, the canvas layout.

## Decisions (owner, November 17, 2026)

1. **Stand in** for Blizzard's frames (not reskin in place): Blizzard's
   `BuffFrame` and `DebuffFrame` step aside and stay as Edit Mode anchors;
   the Buffs and Debuffs bars sit in their place.
2. **Player only** moves out of Unit Frames; Target, Target of Target, Focus
   and Target of Focus keep their auras there.
3. Icons are **always width − 6** (every width, not the design rule's −4
   under 36).
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
| Buffs | All Buffs, Weapon Enchants; 32 max, 10 a row | Blizzard's Buff Frame (`frame:BuffFrame`), top right on top right | 32 x 26, 4px apart, grows left, rows down, time below |
| Debuffs | All Debuffs; 16 max, 10 a row | Buffs' top right, 4 right and 147 down | as Buffs, rims by debuff type |
| Player Buffs | Important, Heals Over Time, Yours; 12 max, 8 a row | under the ModeUI Player Frame's right end (top right on bottom right, -6, -2) | 24 x 18, 2px apart, grows left, time on the icon |
| Player Debuffs | Crowd Control, Dispellable by You, Boss, Magic, Curse, Disease, Poison, Bleed, Other; 8 max, 6 a row | above the ModeUI Player Frame (top right on top right, 2, 131) | 30 x 24, 3px apart, Mode-BlizzEmpty, rims by type, time on the icon |
| Defensives (custom) | Big and External Defensives, Important; 4 max | left of center (-151, 27) | 40 x 34, Mode-BlizzEmpty, Soft glow in Aura Gold, time on the icon |

Player Buffs' rows go down (the canvas had Up, which would cover the frame
once a second row starts). Custom bars: **+ New Bar** (eight at most),
renamed, deleted (what hangs from one moves to where it is).

### What a bar shows

One aura group per kind picked, in this order (an aura shows once):

- Buffs: Big Defensives (`BIG_DEFENSIVE`), External Defensives
  (`EXTERNAL_DEFENSIVE`), Important (`IMPORTANT`), Heals Over Time
  (`RAID_IN_COMBAT`), Yours (`PLAYER`), Cancelable (`CANCELABLE`), Under a
  Minute (`maxDuration` 60), All Buffs; Weapon Enchants are the container's
  item enchantments (main and off hand, after the groups).
- Debuffs: Crowd Control (`CROWD_CONTROL`), Dispellable by You (`RAID`),
  Boss Debuffs (`isBossAura`), Magic, Curse, Disease, Poison, Bleed
  (`includeDispelTypes`), Other (`excludeDispelTypes` all five), All Debuffs.
- Each token kind adds `|!<token>` for the token kinds before it. All stands
  alone (picking it clears the rest; picking another clears All). A boss
  debuff with a type can show twice (Boss and its type): `isBossAura = false`
  isn't safe to send.
- Max Shown is per kind (each group's `maxFrameCount`); Sort is the game's
  Default, Expiration (Time Left) or Name.

### Buttons

Styled once in `initializeFrame`: the button is the cell (icon plus 12px for
time text below); the Mode icon (`Kit.AuraIconParts`) on a child frame at its
top, in the bar's Border Style, Metal and Size; swipe, stacks, time text
(below in the Mode face Bold 10, or on the icon), a flat rim the game colors
by debuff type (`Kit.DispelAuraRim` on the child), Soft or Flash glows (by
type or a color), the game's tooltip (bottom left) and, on buff bars,
right-click cancel (`SetCancelAuraButtons`, Up or Down by Cast on Key Down).
A new look builds a new container (the old one disabled); kinds, counts,
layout and sorting change in place; candidate filters only when the
blacklist changes (they make the game read every aura again).

### Blizzard's frames

While the Buffs (Debuffs) bar shows, `BuffFrame` (`DebuffFrame`) is
unregistered and its `AuraContainer`, collapse button and consolidated buffs
wait on a hidden frame (method calls only); the frame stays where Blizzard's
Edit Mode puts it, as the Buffs bar's anchor. Hiding the bar or switching the
module off asks for a reload to bring Blizzard's back. `DeadlyDebuffFrame` is
left alone.

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
same samples. Tabs: **Bars** (bar picker, + New Bar, name, Delete Bar, Show
This Bar, Shows for custom bars, Which Auras, Sort, Max Shown, Per Row, Grow,
New Rows Go), **Look** (Icon Width, Spacing, Time Text, Timer Swipe, Stack
Count, Tooltips, Right-Click Cancels, Border Style, Border Metal, Border Size,
Rim Colored by Debuff Type, Glow, Glow Color, Custom Color), **Blacklist**
(+ Add or Remove Auras), **Module** (Reset to Defaults).

### Saved settings

`ModeUIDB` profile `modules.buffsDebuffs` (settings version 1): `bars[id]`
(show, kind, cats, sort, max, perRow, width, spacing, grow, wrap, timer,
swipe, count, tooltip, cancel, edgeStyle, edgeMetal, borderSize, byType,
glow, glowColor, glowCustomColor), `customBars` ({ id, name }), `nextCustom`,
`blacklist`, and the text keys (font, fontMedia, outline, shadow,
liftedShadow, slug, textColor, timerColor). Places under `positions`.
Unit Frames keeps `player.buffs` and `player.debuffs` untouched; `M.Adopt`
(a new module hook in `DB:ValidateProfile`) turns this module on once when
either showed.

### Files

`Modules/BuffsDebuffs/`: `Init.lua` (declaration, bars, kinds, defaults),
`Migrations.lua` (validation, Adopt), `Driver.lua` (lifecycle, setters,
custom bars, blacklist), `Placement.lua` (sizes, movers, holders),
`Bars.lua` (containers, groups, buttons), `Blizzard.lua` (the stand-in),
`Samples.lua`, `Preview.lua`, `Settings.lua`, `SettingsBar.lua`,
`Blacklist.lua`. Shared: `Runtime/DB.lua` (Adopt), `Domain/Auras.lua`
(`NeverSecret`, `Spells`), `Kit/AuraIcon.lua` (`DispelAuraRim` on a child),
`Kit/AuraContainer.lua` (`AuraTimeFormatter(hours)`), the Auras icon
(`tools/mode_icons.lua`, `Style.ICONS`). Unit Frames: `Auras.lua`
(`ShowsAuras`), `SettingsExtra.lua` (the Player's Auras tab). Tests:
`tests/buffs_debuffs.lua`, `tests/unit_frames.lua`, `tests/smoke.lua`.

Not built (from the plan): reskin in place (decision 1 went to stand in);
moving Party Frames' aura catalog into Shared (left alone so a confirmed
module doesn't change).

## In-game gate

One check at a time, after `/reload` on this branch:

1. **Handover.** Navigation: `/modeui`, **Interface** › **Buffs & Debuffs**,
   then **Interface** › **Unit Frames**, pick the Player above the preview,
   open the **Auras** tab. Action: click **Open Buffs & Debuffs**. Required
   state: out of combat. Confirmation: Buffs & Debuffs is switched on; the
   Player's Auras tab shows the note and the button (which opens the page);
   no auras draw on the Player frame; the Target's auras still show.
2. **Stand-in.** Navigation: the game world. Action: gain and lose a few
   buffs and a debuff; right-click a buff. Required state: out of combat,
   then in combat (a training dummy). Confirmation: Blizzard's buffs and
   debuffs by the minimap are gone and Mode bars (32 x 26, Mode-Blizz, time
   below) sit in their place; debuff rims take their type's color; a
   right-click cancels a buff out of combat (note whether it does in combat).
3. **Player bars and Defensives.** Navigation: the game world, then
   **Edit Mode** in the ModeUI window header. Action: watch the Player bars;
   drag Player Debuffs and pick **Anchor To**. Required state: auras on you.
   Confirmation: Player Debuffs above the Player frame, Player Buffs under its
   right end, Defensives left of center; in Edit Mode each bar shows samples
   and moves.
4. **Settings and blacklist.** Navigation: **Interface** › **Buffs &
   Debuffs**, tabs **Bars**, **Look**, **Blacklist**. Action: pick another
   kind on a bar, change **Icon Width** and **Border Style**, click
   **+ New Bar**, open **+ Add or Remove Auras** and hide a buff on you.
   Required state: out of combat. Confirmation: the preview and the bars
   follow each change; the hidden buff leaves every bar.
5. **Off.** Navigation: **Interface** › **Buffs & Debuffs**. Action: switch
   the module off and reload when asked. Required state: out of combat.
   Confirmation: Blizzard's buffs and debuffs are back by the minimap.
