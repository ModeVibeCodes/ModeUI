# Icon effects research (November 25, 2026)

This is the research behind `index.html`. It is Forever first (the mainline
client, `camelot` game type, Interface 16001, build 1.60.1), with groundwork
for a later Midnight port.

Blizzard code comes from Gethe/wow-ui-source, `forever` branch
(version.txt `1.60.1.71091`). The local client has no extracted Blizzard UI.

## 1. ModeCDM today

- **Glows.** There are four: Proc, Active and Ready on cooldown icons, and
  Buff on buff icons. Ready has two modes, Flash and While Ready.
  - Each glow has five looks (Mode Glow, Border, Pixel, Blizzard, GCD), a
    color and a pulse. See `Glow.lua` and `GlowPopout.lua`.
  - All of them start off on every spell (owner, November 13, 2026).
  - A spell's menu stores its own look in `spells[key][kind]`.
- **Procs are invisible by default.** `M:ApplyGlows` sets Blizzard's
  `SpellActivationAlert` to alpha 0 while the module is on, but ModeCDM's own
  Proc glow is off until a spell switches it on.
- **Icon looks.**
  - Gray on Cooldown comes from `C_Spell.GetSpellCooldown`'s `isActive` and
    `isOnGCD`, which are never secret.
  - Out of Range Tint paints Rosewood instead of Blizzard's red
    (`Skin.lua` `StyleRange`, from the `RefreshIconColor` hook in
    `Blizzard.lua`).
- **ModeCDM's own icons** (spells by ID and items; `Spells.lua`, `Items.lua`):
  - They hard-code tints: `{0.4, 0.4, 0.4}` for unusable and
    `{0.5, 0.5, 1}` for not enough power.
  - They have no range check.
  - Procs come from `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE`.
- **The action bars already use Mode tints** (`ActionBars/Skin.lua`):
  Rosewood for range, `Mix(Tone.power, white, 0.7)` for power, and
  `Tone.graphite.muted` for unusable.
- **Sounds.** Ready Sound (`Alerts.lua`) plays only for spells ModeCDM tracks
  itself. Spells Blizzard tracks link to Blizzard's own alerts.
- **Migrations.lua is at 392 lines**, near the 400-line limit, so new
  migration steps belong in a new file called from `Parts.lua`.

## 2. Blizzard_CooldownViewer (forever)

**TOC:** `AllowLoadGameType: standard, camelot`.

**Files:** SettingsConstants, Util, Secure, VisualAlertTarget,
SoundAlertData, Alert, EditAlertBase, SettingsAlerts,
SettingsDataStoreSerialization, SettingsLayoutManager, SettingsDataProvider,
ItemData, SettingsDialogs, DraggedItemBase, GroupBuffFilter, Settings,
CooldownViewer.lua/.xml, PandemicAlertAnimation.xml,
SlashCommandRegistration.

**Mixins:**
- `CooldownViewerItemMixin` → `CooldownViewerCooldownItemMixin` →
  `CooldownViewerEssentialItemMixin` and `CooldownViewerUtilityItemMixin`.
- `CooldownViewerBuffItemMixin` → `CooldownViewerBuffIconItemMixin` and
  `CooldownViewerBuffBarItemMixin`.

**`CooldownViewerConstants`:**

| Constant | Value |
|---|---|
| `ITEM_USABLE_COLOR` | (1, 1, 1, 1) |
| `ITEM_NOT_ENOUGH_MANA_COLOR` | (0.5, 0.5, 1.0, 1) |
| `ITEM_NOT_USABLE_COLOR` | (0.4, 0.4, 0.4, 1) |
| `ITEM_NOT_IN_RANGE_COLOR` | (0.64, 0.15, 0.15, 1) |
| `ITEM_AURA_COLOR` (swipe while an aura or totem is up) | (1, 0.95, 0.57, 0.7) |
| `ITEM_COOLDOWN_COLOR` (swipe) | (0, 0, 0, 0.7) |

**What its icons do:**
- **Color.** `RefreshIconColor` checks out of range, then
  `C_Spell.IsSpellUsable`, then not enough mana, and otherwise grays the
  icon. Out of range also shows the `OutOfRange` texture
  (`UI-CooldownManager-OORshadow`).
- **Range.** `OnCooldownIDSet` calls `C_Spell.SpellHasRange` and then
  `C_Spell.EnableSpellRangeCheck(baseSpellID, true)`.
  `OnSpellRangeCheckUpdateEvent` sets
  `spellOutOfRange = checksRange and not inRange`.
- **Desaturation.** `RefreshIconDesaturation` grays only on a real cooldown
  (not the global cooldown).
- **Cooldown sources.** `CacheCooldownValues` tries charges, then the spell
  cooldown, then an aura, then the equipped item, then Edit Mode. It sets
  `wasSetFromCharges`, `wasSetFromCooldown` or `wasSetFromAura`.
- **Aura or totem up.** It replaces the cooldown display with the
  `ITEM_AURA_COLOR` swipe and `SetUseAuraDisplayTime(true)`, and leaves the
  icon in full color.
- **Ready cue.** The `CooldownFlash` flipbook
  (`UI-HUD-ActionBar-GCD-Flipbook`) is scheduled 0.75 s before a cooldown
  ends.
- **Global cooldown.** It is recognized by
  `startRecoveryCategory == Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY`
  (133).
- **Charges.** `CacheChargeValues` shows `currentCharges` when
  `maxCharges > 1`, otherwise `C_Spell.GetSpellCastCount`.
- **Procs.** `RefreshOverlayGlow` uses `C_SpellActivationOverlay.IsSpellOverlayed`
  or the overlay events, then calls `ActionButtonSpellAlertManager:ShowAlert`
  or `HideAlert`.
- **Buff icons.** Stacks show when `applications > 1`; `DebuffBorder` comes
  from `AuraUtil.SetAuraBorderAtlasFromAura`; `ShouldBeActive` and
  `SetHideWhenInactive` decide the shown state.
- **Linked auras.** The aura lookup scans the player, then the target
  (`HARMFUL|PLAYER`).
- **Pandemic.** `C_UnitAuras.GetRefreshCarryOverDuration` gives the window,
  and `CheckPandemicTimeDisplay` shows `CooldownPandemicFXTemplate`
  (`CooldownPandemicBarFXTemplate` on bars).

**Alerts.** `Enum.CooldownViewerAlertEventType` has Available, PandemicTime,
OnCooldown, ChargeGained, OnAuraApplied and OnAuraRemoved. An alert is a
Sound (`C_Sound.PlaySoundWithOptions` or text-to-speech) or a Visual
(`Enum.VisualAlertType` MarchingAnts or Flash, in default, Cyan, Red, Green
or Blue).

**Events:**
- All viewers: `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`, `SPELL_UPDATE_ICON`,
  `UNIT_AURA` (player, target), `PLAYER_TARGET_CHANGED`,
  `PLAYER_TOTEM_UPDATE`, `BAG_UPDATE_COOLDOWN`, `PLAYER_IN_COMBAT_CHANGED`,
  `PLAYER_LEVEL_CHANGED`.
- Cooldown viewers add: `SPELL_UPDATE_COOLDOWN`,
  `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE`, `SPELL_UPDATE_USES`,
  `SPELL_UPDATE_USABLE`, `SPELL_RANGE_CHECK_UPDATE`.

**Edit Mode.** `Enum.EditModeCooldownViewerSetting` covers Orientation,
IconLimit, IconDirection, IconSize, IconPadding, BarWidthScale, Opacity,
VisibleSetting, BarContent, HideWhenInactive, ShowTimer and ShowTooltips.
The CVar is `cooldownViewerEnabled`.

**Secure code.** `CooldownViewerSecure.lua` runs in a secure environment
that compares raw times and unwraps secret aura IDs (`secretunwrap`). Addons
can copy which states Blizzard shows, but not its arithmetic.

**Forever vs. live.** CooldownViewer.lua is nearly identical. Forever adds an
`EditMode.RefreshCooldownViewer` callback and returns the spellID for item
category cooldowns.

## 3. Reactive abilities on Forever

Forever has no reactive-ability enum or code path. `ActionButton_UpdateUsable`
and `ActionButton_ShowOverlayGlow` don't exist.

The action bar works like this:
- `ActionBarActionButtonMixin:UpdateUsable` runs on `ACTION_USABLE_CHANGED`
  and tints the icon (1,1,1) usable, (0.5,0.5,1) not enough mana and
  (0.4,0.4,0.4) unusable.
- `UpdateSpellAlert` shows the glow through `IsSpellOverlayed` and
  `ActionButtonSpellAlertManager`.
- Out of range turns only the hotkey `RED_FONT_COLOR`.

So "Riposte is usable" means `C_Spell.IsSpellUsable` turning true on
`SPELL_UPDATE_USABLE`. Whether Riposte (or Overpower, Revenge, Execute) also
fires `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` is spell data. **Check in game**:
`/mcdm check` should log it.

## 4. APIs and secret status (Forever docs)

"Secret" means `SecretWhenCooldownsRestricted` or
`SecretWhenUnitAurasRestricted`. "Not marked" means the docs carry no secret
flag on the return.

- **`C_Spell.IsSpellUsable`** → `isUsable, insufficientPower`. Not marked.
- **`C_Spell.IsSpellInRange`, `SpellHasRange`, `EnableSpellRangeCheck`.** Not
  marked. Event: `SPELL_RANGE_CHECK_UPDATE(spell, isInRange, checksRange)`.
- **`C_SpellActivationOverlay.IsSpellOverlayed`.** The return is not marked;
  the argument must be public.
- **`C_Spell.GetSpellCooldown`.** Secret, except `isEnabled`, `isActive` and
  `isOnGCD`, which are NeverSecret.
- **`C_Spell.GetSpellCharges`.** Secret, except `maxCharges` and `isActive`,
  which are NeverSecret.
- **`C_Spell.GetSpellDisplayCount` and `GetSpellCastCount`.** Secret.
- **Duration objects.** `GetSpellCooldownDuration(id, ignoreGCD)`,
  `GetSpellChargeDuration` and `GetSpellLossOfControlCooldownDuration`.
  Methods: `HasSecretValues`, `IsActive`, `GetRemainingDuration`,
  `EvaluateRemainingPercent(curve)`.
- **`C_Spell.GetOverrideSpell`.** Not marked.
- **`C_UnitAuras`:**
  - `GetPlayerAuraBySpellID`, `GetUnitAuraBySpellID` and
    `GetAuraDataBySpellName` are secret.
  - `GetAuraDuration` is not marked.
  - `GetAuraApplicationDisplayCount` and `GetRefreshCarryOverDuration` are
    secret.
  - `UNIT_AURA` is `SecretWhenAurasRestricted`.
- **`C_CooldownViewer`.** `GetCooldownViewerCategorySet`,
  `GetCooldownViewerCooldownInfo` (`linkedSpellIDs`, `selfAura`, `hasAura`,
  `charges`, `flags`) and `GetValidAlertTypes`.
- **`C_Secrets.ShouldSpellCooldownBeSecret` and `ShouldSpellAuraBeSecret`.**
  They say up front whether a value will be secret.
- **Totems.** `GetTotemInfo` (secret when the totem slot is secret) and
  `GetTotemDuration`.
- **Forever-only Spell APIs** (in forever's docs, not live's):
  `C_Spell.IsActiveSpell`, `GetItemCooldown`, `CancelItemTempEnchantment`,
  `CancelAutoRepeatSpell`.
- **Other Forever systems:** `C_Item.GetWeaponEnchantInfo` with
  `WEAPON_ENCHANT_CHANGED`, and `C_SwingTimer` with `PLAYER_SWING`.
- **Setters that accept secrets from addon code:**
  - Cooldown: `SetSwipeColor`, `SetEdgeColor`, `SetDrawSwipe`, `SetDrawEdge`,
    `SetDrawBling`.
  - Texture and region: `SetVertexColor`, `SetVertexColorFromBoolean(bool,
    colorIfTrue, colorIfFalse)`, `SetAlpha`, `SetAlphaFromBoolean`,
    `SetDesaturated`, `SetDesaturation`.
  - `C_CurveUtil.EvaluateColorFromBoolean`.
- **Setters that don't take secrets from addon code:**
  - `SetCooldown`, `SetCooldownDuration` and `SetCooldownFromExpirationTime`.
  - `SetCooldownFromDurationObject` takes a duration object rather than
    secret numbers, and is the right path.
  - `CooldownFrame_Set` compares `start > 0`, so it can't take secrets either.

## 5. Glow art addons can use

- `ActionButtonSpellAlertManager` (`Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua`):
  `ShowAlert(frame, skipBirth)`, `HideAlert` and `HasAlert`. Its template
  is drawn at 1.4× the button with `UI-HUD-ActionBar-Proc-Start-Flipbook`,
  `UI-HUD-ActionBar-Proc-Loop-Flipbook` and `UI-HUD-RotationHelper-ProcAltGlow`.
- Visual alerts: `VisualAlert_Ants_Flipbook` and
  `UI-CooldownManager-VisualAlert-Glow` (`Blizzard_VisualAlerts/VisualAlertTemplates.xml`).
- The pandemic effect `CooldownPandemicFXTemplate`, and the GCD flash
  `UI-HUD-ActionBar-GCD-Flipbook`.
- No built-in glow library like LibCustomGlow. ModeUI's `Kit.SlotGlow`,
  `Kit.PaintSlotGlow`, Pixel and flipbook glows already cover the looks.

## 6. Other addons (features and settings, no code copied)

**TellMeWhen.**
- Icon states, each with its own opacity and color: Usable, Unusable, Ready,
  Not Ready, On Cooldown, Out of Range, Out of Power, Timer running.
- One-shot events: On Start, On Finish, On Charge Spent/Gained, On Duration
  Threshold, On Stacks Changed. Held events: While Condition Passing, While
  Aura Present, While Aura In Pandemic.
- Animations: Shake, Color Flash, Alpha Flash, Fade, Border, Activation
  Border, Pixel and Autocast borders, CDM Pandemic.
- **Lesson:** split one-shot events from held states. Avoid its jargon and
  its separate "Stop Animations" step.
- [Animations.lua](https://raw.githubusercontent.com/ascott18/TellMeWhen/master/Components/EventHandlers/Animations/Animations.lua),
  [locale](https://raw.githubusercontent.com/ascott18/TellMeWhen/master/Localization/TellMeWhen-enUS.lua)

**WeakAuras.**
- Spell cooldown conditions: On Cooldown, Charges, Since Ready, Spell Usable,
  Insufficient Resources, Spell in Range. Proc glow is a separate trigger.
- An ordered If/Then Conditions list where later rows win. Glow types:
  Action Button Glow, Pixel Glow, Autocast Shine, Proc Glow.
- **Pitfall:** the same glow set in both Actions and Conditions.
- No Midnight version.
- [Prototypes.lua](https://raw.githubusercontent.com/WeakAuras/WeakAuras2/main/WeakAuras/Prototypes.lua)

**LibCustomGlow parameters.**

| Glow | Parameters |
|---|---|
| Action Button Glow | color, frequency |
| Pixel Glow | color, N lines (8), frequency, length, thickness (2), x/y offset, border |
| Autocast Shine | color, N particle groups, frequency, scale, offset |
| Proc Glow | color, startAnim, duration, offset |

[source](https://github.com/Stanzilla/LibCustomGlow)

**Midnight-era CDM addons (from their CurseForge pages):**
- **Cooldown Manager Ckraigs:** per-spell glows, a pandemic glow, and an
  animated Guide & Previews window.
- **MiliUI CDM:** proc glow style and color, a brief glow when ready, a
  pandemic border, per-spell sounds, a live preview per bar where you click
  a spell to edit it, and a global theme with per-bar overrides.
- **ArcUI:** Cooldown State Visuals (desaturate, alpha, tint), a range
  overlay, ColorCurve duration colors, and "proc overrides dim".
- **EllesmereUI CDM:**
  - Per-icon proc, active and cooldown states.
  - An "Only In Combat" switch per glow.
  - Pixel Glow thickness up front, with lines and speed behind a cog.
  - A sound when a spell is ready.
- **CDMAuras:**
  - Glow, Border, text and custom icon alerts, with Any/All conditions.
  - You create an alert by right-clicking a spell in Blizzard's Cooldown
    Settings.
  - It hooks the viewer with `hooksecurefunc`.
- **Cooldown Manager Tweaks:** separate ready and on-cooldown highlights;
  inactive buffs desaturated and faded.
- **GM CDM (Forever):** active-buff glows and borders, and condition-based
  looks.
- **Desaturate Begone CDM and Disable Desaturate CDM** exist only to remove
  Blizzard's gray on cooldown, so that default is divisive.

**Action bar conventions.** Out of range is red, out of power blue, unusable
gray. Range Color Skills uses yellow when a spell is both out of range and
out of mana. tullaRange dropped desaturation for unusable spells.

## 7. Midnight secret values (what ports)

**Branchable, so states can be built on them:**
- Cooldown vs. GCD (`isActive`, `isOnGCD`).
- Max charges and whether a charge is recharging.
- Usable and not enough power.
- Range.
- Proc overlay events.

**Display only:**
- Time left on cooldowns and auras.
- Current charges.
- Most aura data.
- Power amounts.

So "Ending Soon", stack thresholds, power thresholds and arbitrary
"target debuff missing" can't be Lua comparisons on Midnight.

**Workarounds:**
- Color curves on duration objects: `C_CurveUtil` with
  `EvaluateRemainingPercent`.
- The boolean setters: `SetVertexColorFromBoolean`, `SetAlphaFromBoolean`.
- Reuse the CDM's own items: `isActive`, the pandemic effect, and the
  hooks.

Sources:
- [Blizzard's Midnight addon post](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
- [12.0.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [12.0.1 notes](https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes/notes)
- [DurationObject](https://warcraft.wiki.gg/wiki/ScriptObject_DurationObject)
- [community guide (secondary)](https://github.com/Amadeus-/WoWAddonDevGuide/blob/master/12a_Secret_Safe_APIs.md)

## 8. Patterns adopted and pitfalls avoided

**Adopted:**
- A fixed list of states, each with one look per layer and a fixed
  priority.
- Held looks vs. one-shot motion and sound.
- Bar Style defaults with per-spell Bar/Own.
- A live preview where clicking an icon edits it.
- Look and Color first, with glow details under More.
- Recipes as shortcuts.
- "Proc overrides dim".

**Avoided:**
- A free-form rule builder.
- The same effect set in two places.
- Jargon.
- Every parameter on the first screen.
- Effects stacking with no priority.
- Thresholds written as Lua comparisons.

## 9. Blizzard file paths (forever, under `Interface/AddOns/`)

- `Blizzard_CooldownViewer/`: `CooldownViewer.lua`, `CooldownViewer.xml`,
  `CooldownViewerItemData.lua`, `CooldownViewerAlert.lua`,
  `CooldownViewerSecure.lua`, `CooldownViewerVisualAlertTarget.lua`,
  `PandemicAlertAnimation.xml`, `Blizzard_CooldownViewer.toc`
- `Blizzard_VisualAlerts/VisualAlertTemplates.xml`
- `Blizzard_ActionBar/Shared/`: `ActionButton.lua`,
  `ActionButtonSpellAlerts.lua/.xml`
- `Blizzard_ActionBar/Camelot/ActionButtonOverrides.lua`
- `Blizzard_FrameXML/SpellActivationOverlay.lua`
- `Blizzard_FrameXMLUtil/Cooldown.lua`
- `Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua`
- `Blizzard_BuffFrame/BuffFrame.lua`
- `Blizzard_APIDocumentationGenerated/`: the `Spell`, `SpellShared`,
  `SpellActivationOverlay`, `UnitAura`, `CooldownViewer`, `FrameAPICooldown`,
  `DurationUtil`, `LuaDurationObjectAPI`, `SecretPredicateAPI`, `CurveUtil`,
  `SimpleTextureBaseAPI`, `SimpleRegionAPI`, `ActionBarFrame`, `SwingTimer`,
  `Totem`, `Item` and `VisualAlertConstants` documentation files
