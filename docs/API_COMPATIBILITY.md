# Forever API compatibility notes

> Moved from Play The Game Tools with Unit Frames on November 12, 2026.

## Interface unit frames — November 11, 2026

Forever is the mainline client with Camelot overrides
([Blizzard_UnitFrame.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitFrame/Blizzard_UnitFrame.toc)).
`UnitHealth` always declares secret returns; max health, power and names are
conditionally secret
([UnitDocumentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)).
Unit frames pass these values only to StatusBar `SetMinMaxValues`/`SetValue`
and FontString `SetText`/`SetFormattedText`, all `AllowedWhenTainted`. Percent
text uses `UnitHealthPercent` with `CurveConstants.ScaleTo100`.
`AbbreviateNumbers` has no generated secret-argument documentation; it is
pcall-guarded and falls back to percent. The Health Deficit text slot reads
`UnitHealthMissing` (`SecretReturns`, on the Forever branch too) and builds its
text with `C_StringUtil.TruncateWhenZero` and `C_StringUtil.WrapString`, both
`AllowedWhenTainted` (StringUtilDocumentation.lua, mainline 12.1.5 and the
Forever branch); every call is pcall-guarded and the slot stays empty on a
client without them. Secure unit buttons are created,
shown, moved and resized only outside combat. Position Manager refuses
protected frames, so Edit Mode moves a plain stand-in whose anchor the button
copies outside combat. Native player/target art, and the Target of Target
(`TargetFrameToT`, a child of `TargetFrame` on Forever), and the Focus frame and
its Target of Focus (`FocusFrame`, `FocusFrameToT`; `FocusFrame` inherits
`TargetFrameTemplate` in Blizzard_UnitFrame/Mainline/TargetFrame.xml, which
Forever loads) are faded (alpha only) rather
than reparented, keeping pet, class resource, aura and cast-bar children
working. Runtime secrecy and taint behavior remain unverified in the client.
The Blizzard-style redesign adds `SetPortraitTexture(texture, unit)`
(documented; plain unit tokens), `UnitPowerPercent` with the same curve, and
the documented `UNIT_PORTRAIT_UPDATE`, `UNIT_MODEL_CHANGED` and
`PORTRAITS_UPDATED` events. Class icons use `GetClassAtlas` only when present
and confirmed by `C_Texture.GetAtlasInfo`; it is not confirmed in the Forever
source. [Details](UNIT_FRAMES.md).


## Unit frame combo points — November 13, 2026

Forever's `Blizzard_UnitFrame/Camelot/ComboFrame.lua` parents `ComboFrame` to
`TargetFrame`, centres it on the Target portrait and reads
`GetComboPoints("player", "target")`. The Forever
[UnitDocumentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
marks `GetComboPoints`, `UnitPower` and `UnitPowerMax` as secret when unit
power is restricted. ModeUI passes the count only to StatusBar `SetValue`
(one bar per point spanning `(i - 1, i)`), reads the maximum only when public
(else five for a Rogue or Druid), and registers `COMBO_TARGET_CHANGED` (used by
Camelot's `TargetBoundComboPointBar`) through `pcall`. Fading `ComboFrame`
uses the same alpha hook as the other native frames. Unverified in game.

## Nameplate combo points — November 13, 2026

The target's nameplate shows the same combo points (`Modules/Nameplates/Combo.lua`,
same `Domain.ClassResource` reads and secret-safe sockets from
`Shared/Kit/Points.lua`). Forever's
[Blizzard_NamePlates.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.toc)
loads `Blizzard_ClassNameplateBar_Rogue` and `_Druid` with
`[ExcludeLoadGameType camelot]`, so Blizzard draws no combo points on Forever
nameplates and there is nothing to hide. The target plate is found by comparing
`C_NamePlate.GetNamePlateForUnit("target")` with each plate's nameplate frame.
The player's `UNIT_POWER_FREQUENT`, `UNIT_MAXPOWER` and `UNIT_DISPLAYPOWER` are
registered with `RegisterUnitEvent(event, "player")` on the module's own frame,
and `COMBO_TARGET_CHANGED` through `pcall`. Unverified in game.

## Unit frame cast bars — November 13, 2026

Same cast API use as the nameplates (`UnitCastingInfo`, `UnitChannelInfo`,
duration objects, the `UNIT_SPELLCAST_*` events, unit-filtered). Blizzard's
bars are named in the Forever source: `PlayerCastingBarFrame`
(`Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml`) and
`<frame>SpellBar` from `TargetFrameMixin:CreateSpellbar`
(`Blizzard_UnitFrame/Mainline/TargetFrame.lua`). They are faded with the alpha
hook, never hidden or reparented. The ModeUI cast bar is a plain child of the
secure unit button, shown and hidden in combat. Unverified in game.

## Nameplate soft-target icon — November 14, 2026

Blizzard draws the soft-target icon on its own plates
(`Blizzard_NamePlates.lua` `NamePlateDriverMixin:UpdateSoftTargetIconInternal`,
Forever branch): when the plate's unit is `softenemy`, `softfriend` or
`softinteract` and that kind's CVar is on (`SoftTargetIconEnemy`,
`SoftTargetIconFriend`, `SoftTargetIconInteract`, with
`SoftTargetNameplateSize` above 0), it calls
`SetUnitCursorTexture(UnitFrame.SoftTargetFrame.Icon, unit, nil, nil, true)` and
shows the icon if that returns true. Forever passes the fifth argument; mainline
12.1.5 passes only the texture and unit, and its UnitDocumentation lists four
arguments (`SecretArguments = "AllowedWhenUntainted"`; ModeUI passes only a
texture and a nameplate unit token, never a secret). `SoftTargetFrame` has no
`ignoreParentAlpha`, so on a ModeUI plate it is hidden with the faded unit
frame. ModeUI's plates make the same call on their own texture, with Forever's
arguments, refreshed on `PLAYER_SOFT_ENEMY_CHANGED`, `PLAYER_SOFT_FRIEND_CHANGED`,
`PLAYER_SOFT_INTERACT_CHANGED` (payloads unused), `CVAR_UPDATE` for those CVars,
and `EventRegistry`'s `Gamepad.PreferredGamepadInteractTargetChanged`, as
Blizzard's driver does. Soft targets are matched by
`C_NamePlate.GetNamePlateForUnit` frames, not `UnitIsUnit`. CVars are read
with `C_CVar.GetCVar`. A secret return from `SetUnitCursorTexture` hides the
icon. The settings preview uses `Interface\Cursor\Attack` and `Interact`, which
the glue screens load (`Blizzard_GlueXML/Mainline/Redlist.xml`). Unverified in
game.

## Interrupted cast bars — November 14, 2026

Blizzard's cast bars inherit `CastingBarFrameAnimsTemplate`
(`Blizzard_UIPanels_Game/Shared/CastingBarFrameTemplates.xml`, the same on the
Forever branch). `CastingBarMixin:PlayInterruptAnims` plays `HoldFadeOutAnim`
on every interrupt, without the `GetAlpha() > 0` check `PlayFadeAnim` makes:
an Alpha animation on the bar itself (1 to 1 for 1s, then 1 to 0 over 0.3s)
whose OnFinished hides the bar. An Alpha animation's from and to alpha replace
the region's own while it plays, so a bar faded with `SetAlpha(0)` showed for
1.3s. While Unit Frames fade a region, its Alpha animations that target the
region itself (`GetAnimationGroups`, `GetAnimations`, `GetTarget`) are set to
0 and 0 with `SetFromAlpha`/`SetToAlpha` (public numbers; documented
`AllowedWhenUntainted` only for secret arguments) and restored when it shows
again. Nameplate cast bars are unaffected: Blizzard's sits under the faded
unit frame, and a child can't show through a parent at alpha 0.

Nameplate cast events now read their payload: `interruptedBy` on
`UNIT_SPELLCAST_CHANNEL_STOP` and `complete` on `UNIT_SPELLCAST_EMPOWER_STOP`,
as Blizzard's bars do. Both are secret while casts are restricted; a secret
`interruptedBy` still counts as an interrupt, a secret `complete` does not.
Unverified in game.

## Unit frame status — November 13, 2026

`UnitAffectingCombat` and `UnitCanAttack` carry no secret flags in Forever's
UnitDocumentation; `IsResting` is the global Blizzard's PlayerFrame uses. The
pull pulse reads only those (plus `UnitExists`), not `UnitThreatSituation`,
which is `SecretWhenUnitThreatStateRestricted`: "your target is in combat"
stands in for "it is fighting you". Events: `PLAYER_UPDATE_RESTING`,
`PLAYER_REGEN_DISABLED`/`_ENABLED`, `PLAYER_TARGET_CHANGED` and unit-filtered
`UNIT_FLAGS`. The pulse is an Alpha animation looping BOUNCE on a texture.
Unverified in game.

## Interface nameplates — November 12, 2026

Source: the user's local copy of Blizzard's interface code, `WoWUI-live`
(build 12.1.5.70575, mainline). It contains no Forever/Camelot overrides, so
everything below is the mainline baseline. Every call is guarded, and native
behavior on Forever is unverified until checked in game.

- **Nameplate frames.** `C_NamePlate.GetNamePlateForUnit(unit, includeForbidden)`
  returns the nameplate frame for a `nameplateN` token. Forbidden nameplates
  (friendly units in instances) are never returned to addon code, and their
  events are separate (`FORBIDDEN_NAME_PLATE_*`)
  (`Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua`,
  `NamePlateManagerDocumentation.lua`). `NAME_PLATE_UNIT_ADDED` and
  `NAME_PLATE_UNIT_REMOVED` carry the unit token. Blizzard's driver acquires a
  pooled `UnitFrame` on each nameplate in `NamePlateBaseMixin:AcquireUnitFrame`
  and releases it on removal (`Blizzard_NamePlates/Blizzard_NamePlateBase.lua`).
  ModeUI parents a plain frame to the nameplate, fades `UnitFrame` with
  `SetAlpha(0)` (hooked so Blizzard can't restore it while ModeUI owns the
  plate), and restores alpha 1 on removal. Hit testing, stacking and clicks are
  untouched. `SetNamePlateSize` and the hit-test setters are restricted and not used.
- **Personal resource display.** `GetNamePlateForUnit("player")` returns the
  player's plate (`Blizzard_NamePlates.lua`, `SetupClassNameplateBars`). ModeUI
  leaves it, and widget-only plates (`UnitNameplateShowsWidgetsOnly`), to Blizzard.
- **Health.** As for unit frames: `UnitHealth` always secret, `UnitHealthMax`
  conditionally; both go only to `StatusBar:SetMinMaxValues`/`SetValue`
  (`SecretArguments = "AllowedWhenTainted"`, `SimpleStatusBarAPIDocumentation.lua`).
- **Reaction and class.** `UnitReaction`, `UnitIsPlayer`, `UnitIsTapDenied` have
  no secret returns. `UnitClass`'s class token is secret while unit identity is
  restricted; ModeUI then falls back to the reaction color.
- **Threat.** `UnitThreatSituation("player", unit)` is secret while threat is
  restricted (`SecretWhenUnitThreatStateRestricted`); ModeUI shows no threat
  color then.
- **Target highlight.** `UnitIsUnit` can be secret, so ModeUI compares the
  nameplate frame returned for `"target"` instead.
- **Raid markers.** `GetRaidTargetIndex` always returns a secret
  (`SecretReturns = true`). Only `Texture:SetSpriteSheetCell` (4 x 4 cells,
  `AllowedWhenTainted`, `SimpleTextureBaseAPIDocumentation.lua`) receives it, on
  `Interface\TargetingFrame\UI-RaidTargetingIcons` (as `SetRaidTargetIconTexture`
  in `Blizzard_UnitFrame/Mainline/TargetFrame.lua`). A missing marker is a plain
  nil; that a secret is never nil is assumed, not documented.
- **Cast bars.** `UnitCastingInfo`/`UnitChannelInfo` returns are secret while
  spell casts are restricted (`SecretWhenUnitSpellCastRestricted`). The bar is
  `SetMinMaxValues(startMs, endMs)` plus `SetValue(GetTime() * 1000)` each frame,
  so no secret arithmetic happens in Lua. `SetTimerDuration` with
  `UnitCastingDuration` is not used: its arguments are `AllowedWhenUntainted`
  only. `notInterruptible` may be secret; it picks the bar color through
  `Region:SetVertexColorFromBoolean(value, colorIfTrue, colorIfFalse)`
  (`AllowedWhenTainted`, `SimpleRegionAPIDocumentation.lua`). Channels drain by
  `SetReverseFill(true)` with the track color filling over the cast color.
  The name goes to `FontString:SetText` and the icon to `Texture:SetTexture`,
  both `AllowedWhenTainted`.
- **Opacity.** Health Opacity is the alpha argument of
  `StatusBar:SetStatusBarColor(r, g, b, a)`; Background Opacity is the track's
  vertex alpha. Both values are public settings. The health box's rim and gap are
  drawn in four bands with `Frame:SetClipsChildren(true)`
  (`SimpleFrameAPIDocumentation.lua`; `AllowedWhenUntainted`, which a plain
  boolean always satisfies) so that nothing opaque sits behind the bar.
- **Auras in 12.1: aura containers.** While auras are secret (combat,
  encounters, Mythic+, PvP), addon code can no longer read or count a unit's
  auras: Patch 12.1 notes say `GetUnitAuras` returns a secret vector and the
  index/slot/instance APIs raise errors for addons (errors ModeUI's `pcall`
  swallowed, so plates showed nothing). Plates in the world therefore use
  Blizzard's `CustomAuraContainerTemplate` (`Blizzard_AuraContainer`, whose Lua
  runs in the secure environment): one `AuraContainer` per plate and anchor,
  `AddAuraGroup(key, filter, { maxFrameCount, layout, initializeFrame })` per
  group, then `SetAuraGroupFilterString`/`MaxFrameCount`/`Layout`/`Enabled`,
  `SetFlowLayoutAnchorPoint`/`Axis`/`GrowthDirection`, `SetUnit`, `SetEnabled`
  and `UpdateAllAuras`. `SetUnit` and `SetEnabled` read the auras again only
  when the value changes; `SetAuraGroupCandidateFilters` reads them again and
  re-registers events on every call. `initializeFrame` builds the Mode icon on each button and
  registers it with `SetIcon`, `SetDurationCooldown`, `SetApplicationCount` and
  `AddDispelTypeTexture` (`PreserveAsset` with a `customDispelColorMap`, "None"
  for auras without a type). The container follows `UNIT_AURA` itself. Buttons
  are styled once, so a change to the aura look builds new containers. Detected
  with `C_XMLUtil.GetTemplateInfo`; clients without it, and the settings
  preview, use `GetUnitAuras`. Center growth becomes rightward growth from a
  centered first icon (flow layouts grow Left, Right, Up or Down only), and
  target arrows clear the most icons a side row can hold. Native confirmation
  is pending.
- **Rounded slices on moving plates.** Sliced rim, gap and glow textures call
  `SetSnapToPixelGrid(false)` and `SetTexelSnappingBias(0)` (`Kit.Unsnap`), as
  Blizzard's `NineSlice.lua` does for its pieces; snapped slices clipped and
  flickered while plates moved at sub-pixel positions with the camera.
- **Indicator.** `UnitLevel`, `UnitClassification`, `UnitIsQuestBoss` and
  `C_QuestLog.UnitIsRelatedToActiveQuest` document no secret returns; ModeUI
  still reads them through `Query.Plain` and hides a part on a secret or unknown
  answer. Icons use Blizzard's atlases (`nameplates-icon-elite-gold`/`-silver`,
  `UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star` from
  `Blizzard_NamePlateClassificationFrame.lua`; `...-Boss-Quest` from
  `TargetFrame.xml`). Level color is `GetCreatureDifficultyColor`
  (`DifficultyUtil.lua`). Updates on `UNIT_LEVEL`,
  `UNIT_CLASSIFICATION_CHANGED` and `QUEST_LOG_UPDATE`.
- **Cast target and timer.** The target is `UnitName(unit .. "target")` (may be
  secret, goes to `SetText`), refreshed on `UNIT_TARGET`. The timer uses
  `endMs - GetTime()*1000` when the times are public; otherwise
  `UnitCastingDuration` (`SecretReturns`) or `UnitChannelDuration` and the
  duration object's `GetRemainingDuration`, inside `pcall`, formatted by
  `SetFormattedText` (`AllowedWhenTainted`).
- **Slug text.** Slug rendering is set only in XML (`<Font slug="true">`, used by
  `SystemFont_Outline_Slug_*` in `Blizzard_Fonts_Shared`); no Lua API sets it.
  `Kit/Fonts.xml` declares slug templates; `Kit.SlugFont` copies one with
  `CreateFont` + `Font:CopyFontObject` and sets the face with `Font:SetFont`,
  then `FontString:SetFontObject`. Whether `SetFont` keeps the slug flag on the
  copy is not documented; native confirmation is pending.
- **Not used.** `SetShown` and `SetTimerDuration` reject secret arguments from
  addon code (`AllowedWhenUntainted`). Blizzard notes that tainted callers must
  use `SetAlphaFromBoolean` instead (`Blizzard_UnitFrame/Shared/UnitFrameUtil.lua`).
  Its alpha range (`SingleColorValue`, default 255) is undocumented, so ModeUI
  avoids it.

## Nameplate auras — November 12, 2026

Same source (`WoWUI-live` 12.1.5 mainline); unverified on Forever.

- **Choosing auras.** `C_UnitAuras.GetUnitAuras(unit, filter, maxCount)` returns
  a list whose contents can be secret while unit auras are restricted
  (`ConditionalSecretContents`, `UnitAuraDocumentation.lua`). Which auras match
  is decided by the game through filter strings (`AuraUtil.AuraFilters` in
  `Blizzard_FrameXMLUtil`): `HARMFUL|PLAYER` (yours), `HARMFUL|RAID` (ones you
  can dispel), `HARMFUL|CROWD_CONTROL`, `HELPFUL|DISPELLABLE`,
  `HELPFUL|IMPORTANT`, `HELPFUL|PLAYER`, plus `INCLUDE_NAME_PLATE_ONLY` as
  Blizzard's own nameplates use (`Blizzard_NamePlateAuras.lua`). A leading `!`
  negates a component; debuffs use `!CROWD_CONTROL` when crowd control has
  its own group, retried without it if a client rejects the negation. ModeUI
  never compares an aura field.
- **Icon and stacks.** `aura.icon` goes only to `Texture:SetTexture`. The stack
  text comes from `C_UnitAuras.GetAuraApplicationDisplayCount(unit, id, 2)` (a
  string, secret while restricted) and goes only to `FontString:SetText`.
- **Timer swipe.** Every `Cooldown` setter (`SetCooldown`,
  `SetCooldownFromDurationObject`, …) is `AllowedWhenUntainted`
  (`FrameAPICooldownDocumentation.lua`), so a secret time can't be drawn by an
  addon. ModeUI tries `C_UnitAuras.GetAuraDuration` with
  `SetCooldownFromDurationObject` (pcall-guarded), then public
  `duration`/`expirationTime` with `SetCooldown`, else hides the swipe.
  Permanent auras (duration 0) have no swipe.
- **Not used.** Blizzard's secure `CustomAuraContainerTemplate`
  (`Blizzard_AuraContainer`, `UseSecureEnvironment`) can display secret auras
  for addons. It's a larger API (groups, slots, processing policies, its own
  buttons) and may not exist on Forever; it is the route to take if aura
  timers in restricted content turn out to matter.

## Interface action bars — November 13, 2026

Source: the user's local copy of Blizzard's interface code, `WoWUI-live`
(build 12.1.5.70575, mainline), as for nameplates. It has no Forever/Camelot
overrides, so this is the mainline baseline; every call that may be missing is
guarded, and native behavior on Forever is unverified until checked in game.
[Details](ACTION_BARS.md).

- **Blizzard's buttons are reused, not recreated.** `ActionBarMixin:ActionBar_OnLoad`
  (`Blizzard_ActionBar/Shared/ActionBar.lua`) creates the named buttons
  (`ActionButton1-12`, `MultiBarBottomLeftButton1-12`, …, `MultiBar7Button1-12`,
  `PetActionButton1-10`, `StanceButton1-10`) and sets `button.bar` to their bar.
  `SecureButton_GetModifiedAttribute` (`Blizzard_FrameXML/SecureTemplates.lua`)
  resolves `useparent-actionpage` through `frame.bar` before the parent, and
  `ActionBarController_UpdateAll` sets `MainActionBar`'s `actionpage` for
  vehicle, override, temporary-shapeshift and bonus bars. So a button moved to a
  ModeUI bar still pages from Blizzard. Keybinds reach buttons by name
  (`ActionButtonDown` → `GetActionButtonForID`, `MultiActionButtonDown` →
  `_G[barName].actionButtons[id]`), not by parent.
- **Protected calls.** `SetParent`, `SetPoint`, `Show` and `EnableMouse` are
  `IsProtectedFunction` (`SimpleScriptRegion*APIDocumentation.lua`,
  `SimpleFrameAPIDocumentation.lua`); ModeUI moves, sizes and reparents buttons and
  bars only outside combat (`addon.Defer`). Frame `SetAlpha` is not protected and
  is `AllowedWhenTainted`, so fading runs in combat. Blizzard's own redraws in
  combat (`UpdateButtonArt`, `UpdateHotkeys`) only fade art there; re-placing
  waits for the refresh after combat.
- **Show grid.** `BaseActionButtonMixin:SetShowGrid` changes `showgrid` only when
  `issecure()`, so addons can't force empty buttons to show. ModeUI draws its
  own empty slots instead; Blizzard still shows every button while a spell is
  dragged (`ACTIONBAR_SHOWGRID`).
- **Blizzard's art.** `MainActionBar` (enableMouse, border art, end caps, page
  arrows), `PetActionBar` and `StanceBar` move under a hidden ModeUI frame. They
  are not managed frames (`Blizzard_ManagedFrameSystem` re-parents only frames
  inheriting `ManagedFrameTemplate`), and Edit Mode re-parents only those, so
  the parent holds. Multi bars have no art and no mouse (`MultiActionBars.xml`)
  and are left alone; their empty containers are invisible. `MainMenuBar` is
  tried as an older name. While hidden, `PetActionBar`'s OnUpdate (pet range
  coloring) doesn't run.
- **Show conditions.** `RegisterStateDriver(frame, state, values)` and
  `UnregisterStateDriver` (`Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua`,
  loaded with the game, `AllowLoad: Game`) evaluate `SecureCmdOptionParse` and
  set `state-<name>`; `SecureHandlerStateTemplate` runs `_onstate-<name>` in the
  restricted environment, where a frame handle may `Show`, `Hide`, `SetAttribute`
  and `GetAttribute` (`RestrictedFrames.lua`). Conditions used: `petbattle`,
  `combat`, `@target,exists`, `pet`/`nopet`, `vehicleui`, `overridebar`,
  `possessbar`. These are C-side macro conditions not listed in the generated
  docs; custom text is checked with `SecureCmdOptionParse` under `pcall` and falls
  back to "show".
- **Vehicle bar.** `SecureHandlerWrapScript(OverrideActionBar, "OnShow"/"OnHide",
  header, body)` (`SecureHandlers.lua`) needs an explicitly protected header
  (the bar is) and runs only when `IsWrapEligible` (out of combat, or the wrapped
  frame is protected). If the wrap is unavailable, Action Bar 1 simply stays shown.
- **Skin.** `Texture:RemoveMaskTexture` and `SetTexCoord` (`AllowedWhenTainted`)
  crop the icon. The highlight, pushed, checked and flash regions get a flat
  texture. `Cooldown:GetCountdownFontString` (`FrameAPICooldownDocumentation.lua`)
  styles the countdown numbers. `FontString:SetText` and `SetTextColor`
  (`AllowedWhenTainted`) take the counts, including secret ones, for lifted
  shadows. `ActionButton_UpdateRangeIndicator` tints the keybind with
  `SetVertexColor` (`RED_FONT_COLOR` out of range); ModeUI's hook keeps its own
  color otherwise.
- **Hooks only.** Every hook is `hooksecurefunc` on an instance method;
  ModeUI writes no fields to Blizzard tables. `GetNumShapeshiftForms` (used by
  `StanceBar.lua`, not in the generated docs) sizes the stance bar.

### Action bars, second pass — November 13, 2026

- **Keybind Mode.** `SetBinding(key, command)` (returns false when a key can't be
  bound), `GetBindingKey(command)`, `GetBindingText(key, true)`,
  `SaveBindings(GetCurrentBindingSet())` and `LoadBindings(GetCurrentBindingSet())`,
  as `Blizzard_QuickKeybind/QuickKeybind.lua`, `Blizzard_ClickBindingUI` and
  `Blizzard_Settings_Shared/Blizzard_Keybindings.lua` use them. These are old
  global functions without generated docs, and bindings change only outside
  combat. The keys pressed go through `CreateKeyChordStringUsingMetaKeyState`,
  `IsKeyPressIgnoredForBinding` and `GetConvertedKeyOrButton`
  (`Blizzard_SharedXML/BindingUtil.lua`), with plain fallbacks. Commands are
  Blizzard's `commandNamePrefix` .. `BUTTON` .. index (`MainActionBar.xml`
  `ACTION`, `MultiActionBars.xml` `MULTIACTIONBAR1-7` with Right = 3 and Left = 4,
  `PetActionBar.xml` `BONUSACTION`, `StanceBar.xml` `SHAPESHIFT`). Saving in
  combat (if combat starts mid-mode) is pcall-guarded.
- **Live preview.** It reads Blizzard's own buttons: `icon:GetTexture()` and
  `IsShown()`, `HotKey`/`Count`/`Name:GetText()`, and
  `Cooldown:GetCooldownTimes()` (milliseconds; used only while public). Anything
  that may be secret only goes to `SetTexture` or `SetText` (`AllowedWhenTainted`);
  a secret text's width is never measured. Reading fields on Blizzard's tables
  doesn't taint them.
- **Placement.** Bars may anchor to bars before them through their stand-ins
  (plain frames). Each secure bar is pinned to `UIParent` at its stand-in's
  measured place, from `Positioning:Geometry` (`GetCenter`, effective scale), so a
  protected frame never anchors to another frame. The alignment guides are
  textures on a plain full-screen frame (`SetColorTexture`). The nudge arrows use
  `Texture:SetRotation` when present.

### Action bars, paging and glows — November 13, 2026

- **Paging.** `SecureHandlerSetFrameRef(header, "buttonN", button)`
  (`SecureHandlers.lua`) gives each bar's state handler its buttons;
  `HANDLE:GetFrameRef` and `HANDLE:SetAttribute` (`RestrictedFrames.lua`) set
  `actionpage` from the restricted environment, which works in combat.
  `SecureActionButtonMixin:CalculateAction` (`SecureTemplates.lua`) reads a
  button's own `actionpage` before its `useparent-actionpage` bar, so a cleared
  attribute (`nil`) hands the page back to Blizzard. A state driver that
  matches nothing leaves its attribute unchanged (`resolveDriver` in
  `SecureStateDriver.lua`), so page conditions always end in `none`.
  `bonusbar:N` and `mod:*` are C-side macro conditions without generated docs.
- **Procs.** `ActionButtonSpellAlertManager:ShowAlert(button)` and
  `:HideAlert(button)` (`Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua`)
  create and show `button.SpellActivationAlert`, a plain child frame. ModeUI
  hooks both with `hooksecurefunc` and only changes that frame's alpha.
- **Cooldown state.** `C_ActionBar.GetActionCooldown(action)` returns a
  `SpellCooldownInfo` that is secret while cooldowns are restricted, but its
  `isActive` and `isOnGCD` fields are `NeverSecret`
  (`SpellSharedDocumentation.lua`). `isOnGCD` is only trusted on
  `SPELL_UPDATE_COOLDOWN`, the event ModeUI uses. `button.action` (Blizzard's
  current slot) is read, never written. Icon Opacity uses region `SetAlpha`
  (`AllowedWhenTainted`).
- **Empty buttons.** Blizzard's own empty buttons (Always Show Buttons, or a
  spell being dragged) are shown by Blizzard; ModeUI only draws their
  background at Background Opacity.
- **Desaturation and keybind text.** `Texture:SetDesaturated` is
  `AllowedWhenTainted`; Blizzard calls `icon:SetDesaturated(false)` in
  `ActionBarActionButtonMixin:Update` and `true` only for level-linked actions
  (`UpdateUsable`). ModeUI hooks the icon's `SetDesaturated` to keep its own gray
  while a cooldown runs. Keybind text comes from `GetBindingText(key, 1)` in
  `UpdateHotkeys` (abbreviated as `s-`, `c-`, `a-`); ModeUI shortens it with
  `FontString:SetText` after that call, and calls the button's own
  `UpdateHotkeys` (outside combat) to restore it. The preview's Blizzard proc
  style uses Blizzard's `ActionButtonSpellAlertTemplate` (`ActionButtonSpellAlerts.xml`)
  on a ModeUI frame.
- **Glow menu closing.** The menu registers `GLOBAL_MOUSE_DOWN`
  (`SystemDocumentation.lua`) while open and closes when the click is outside it
  and its button (`IsMouseOver`). It is not in the settings popups list, so
  scrolling the page leaves it open.


## Action bars: micro menu and bag bar — November 13, 2026

From the `forever` branch of Gethe/wow-ui-source (build 1.60.1.70938); native
behavior still needs in-game confirmation.

- **Micro menu** (`Blizzard_MicroMenu`, Camelot overrides): buttons are parented
  to `MicroMenu` by `MicroMenuMixin:AddButton`, which sets `layoutIndex`;
  Forever adds Character, Profession, Spellbook, Talent, Legacy, QuestLog,
  Housing, Guild, LFD, Collections, EJ, Help/Store and MainMenu (game rules
  permitting). `MicroMenu:Layout` (a GridLayoutFrame) only moves its own
  children, so reparented buttons stay put. Its `GetEdgeButton` returns nil when
  empty; `HelpOpenWebTicketButton:SetPoint("CENTER", nil, ...)` then anchors to
  its parent, the Character button. Vehicles and pet battles reparent
  `MicroMenu` itself (`OverrideMicroMenuPosition`), not the buttons.
- **Moving micro buttons** (found in game, November 13, 2026): reparenting a
  shown micro button fires its `OnShow`/`OnHide`, which calls
  `MicroMenuContainer:Layout()`. `GetEdgeButton` then compares the centers of
  the lowest and highest `layoutIndex` buttons still on `MicroMenu`, shown or
  not. A button hidden since load (Help) was never placed, so its center is
  nil and the compare errors once it is first or last. ModeUI moves hidden
  buttons first and gives them back last (`M:ShownLast`); moving a hidden
  button fires nothing.
- **Micro button art:** `LoadMicroButtonTextures` sets Normal/Pushed/Disabled/
  Highlight atlases; `SetPushed`/`SetNormal` re-apply the highlight and toggle
  `Background`/`PushedBackground`; `MainMenuMicroButton`'s OnUpdate re-sets its
  atlases every second. Atlas changes keep a texture's anchors, so the inset
  holds; the hooks re-inset anyway. `OnEnable`/`OnDisable` set the button's
  alpha (0.5 disabled), so ModeUI fades its own bar, never the buttons.
- **Bag bar** (`Blizzard_ActionBar` Camelot): 45x45 `SquareBagSlotButtonTemplate`
  slots with a `SquareMask` on the icon, a `KeyRingButton` (hidden unless
  `C_ActionBar.ShouldShowKeyring()`), dividers and no expand toggle.
  `BaseBagSlotButtonMixin:UpdateTextures` re-applies the frame atlases;
  `BagsBarMixin:Layout` re-anchors every shown bag button to `BagsBar` (on
  `CURSOR_CHANGED` item pickups, `expandBagBar`, Edit Mode updates), so ModeUI
  hooks it (`hooksecurefunc`) and re-places them. The backpack's free-slot text
  is `MainMenuBarBackpackButton.FreeSlots` ("(%d)", shown by CVar
  `displayFreeBagSlots`).
- **Protection:** none of these buttons or frames inherits a secure template in
  the source; runtime `IsProtected()` is unconfirmed, so combat re-placing
  checks it and waits when it is true.
- **Edit Mode:** `MicroMenuContainer` and `BagsBar` are Edit Mode systems;
  `ApplySystemAnchor` moves only those frames, never the buttons.

## Interface damage meters — November 13, 2026

Sources: Forever's own interface code on the `forever` branch of
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_DamageMeter),
checked against the user's local mainline copy (`WoWUI-live`, build
12.1.5.70575). [Details](DAMAGE_METERS.md).

- **Forever has the meter.**
  [Blizzard_DamageMeter.toc](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_DamageMeter/Blizzard_DamageMeter.toc)
  loads with `AllowLoadGameType: standard, camelot`. Forever adds only
  `Camelot/DamageMeterEntryOverrides.lua`, which turns off classification icons.
  [DamageMeterDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
  matches mainline except `specIconID`, which is `SecretValue` on Forever and
  `NeverSecret` on mainline. ModeUI uses class icons instead.
- **Reads.** `C_DamageMeter.GetCombatSessionFromType(sessionType, type)` and
  `GetCombatSessionFromID(sessionID, type)` return `combatSources` already
  ranked (Blizzard's window shows them in order, unsorted), plus `maxAmount`,
  `totalAmount` and `durationSeconds`. `GetCombatSessionSourceFromType` and
  `GetCombatSessionSourceFromID` (with `sourceGUID` or `sourceCreatureID`)
  return `combatSpells`, also unsorted by Blizzard. `GetAvailableCombatSessions`
  lists earlier fights. `GetSessionDurationSeconds(sessionType)` has no secret
  flag. `IsDamageMeterAvailable` returns availability and a reason.
  `ResetAllCombatSessions` is Blizzard's own Reset. Events:
  `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`,
  `DAMAGE_METER_RESET`.
- **Secrets.** The session and source reads are `SecretWhenInCombat`.
  `name` and `sourceGUID` are `ConditionalSecret`. `classFilename`,
  `isLocalPlayer`, `deathRecapID` and `classification` are `NeverSecret`.
  Arguments are `SecretArguments = "AllowedWhenUntainted"`, so addon code
  passes only public ones; a secret GUID means no breakdown until after combat.
  Secret values go only to StatusBar `SetMinMaxValues`/`SetValue`,
  `AbbreviateNumbers` (`AllowedWhenTainted`, `LocalizationDocumentation.lua` on
  both branches), FontString `SetText`/`SetFormattedText`, Texture `SetTexture`,
  and `C_Spell.GetSpellName`/`GetSpellTexture` (`AllowedWhenTainted`,
  `SpellDocumentation.lua`). Nothing compares, sorts, adds or measures them,
  and none go to `GameTooltip`.
- **The game's option.** Blizzard's window checks the `damageMeterEnabled`
  CVar (`DamageMeter.lua`, `ShouldBeShown`). Third-party meters report that the
  game records only while it's on. ModeUI reads it with `C_CVar.GetCVarBool`
  and never writes it.
- **Blizzard's window is never written into.** It is an Edit Mode system frame
  (`EditModeDamageMeterSystemTemplate`). A third-party author (LittleThings)
  reported that writing into its session windows taints their refresh. ModeUI
  never calls into it or sets its fields. Hiding it is in the fourth pass
  below.
- **Death Recap.** `OpenDeathRecapUI(deathRecapID)` is what Blizzard's window
  calls. ModeUI calls it only out of combat, guarded.
- **Unverified natively:** whether the game records with its option off,
  which meter types return data on Forever (one author reports Avoidable Damage
  Taken is unavailable there; the window then says "No avoidable damage
  taken."), and the exact client behavior of `AbbreviateNumbers` text.

### Damage meters, fourth pass — November 13, 2026

- **Hide Blizzard's Meter.** Blizzard's session windows are created as children
  of the global `DamageMeter` frame
  (`CreateFrame("FRAME", "DamageMeterSessionWindow" .. i, self, ...)` in
  `DamageMeterMixin:SetupSessionWindow`), and the spell breakdown
  (`SourceWindow`) sits inside each session window. The Forever branch's
  `Blizzard_DamageMeter` matches mainline. So `DamageMeter:SetParent(hidden
  ModeUI frame)` hides all of it and its mouse areas without touching the
  `damageMeterEnabled` CVar. The CVar only gates `ShouldBeShown`, so recording
  goes on. Blizzard's own `SetShown` calls still run, under a hidden parent.
  Action Bars hides Blizzard bar art the same way. The frame isn't protected
  (checked with `IsProtected`, deferred to after combat if it ever is).
  Alternatives considered: the CVar would also stop Blizzard's recording as far
  as third-party authors report, and alpha alone (as MidnightHiddenCombatMeter
  does in combat) leaves its windows taking clicks. Unverified natively: that
  Blizzard's Edit Mode is unbothered by the reparented system frame.
- **Anchoring in Edit Mode.** `PositionManager:ChangeTarget` kept the old x/y
  when the target changed, and those offsets were measured from the old anchor,
  so a window could land off the screen. `PositionManager:AnchorTo` sets
  target, side and x/y 0 (Screen keeps the place via `DetachAnchor`) and
  refuses a target that already hangs from the element (`WouldLoop`, which
  follows owned targets' saved anchors), because the client rejects a circular
  `SetPoint`. **Anchor To...** reads `GetMouseFoci` only for named Blizzard
  frames (as `FrameAnchors` did). ModeUI targets are matched by their rectangle
  under `GetCursorPosition()`, since stand-ins don't take the mouse while it
  waits. Clicks are seen through `GLOBAL_MOUSE_DOWN`.
- **Match Width / Match Height.** For an anchor on another meter window the
  size comes from that window's settings (`Geometry`), with no client call. For
  any other frame it comes from `Positioning:Geometry` (forbidden, restricted
  and secret-anchored frames refused), read only out of combat. Changes are
  noticed by Position Manager's anchor size listener: an addon-owned hidden
  frame pinned to the target's corners, whose `OnSizeChanged` fires natively.
  The target is never hooked or resized. Unverified natively: that listener
  firing for Blizzard frames that change size.

### Damage meters, second pass — November 13, 2026

- **Decimals.** `AbbreviateNumbers(number, options)` takes
  `options.breakpointData`, a list of `NumberAbbreviationBreakpoint`
  (`breakpoint`, `abbreviation`, `significandDivisor`, `fractionDivisor`,
  `abbreviationIsGlobal`; `LocalizationSharedDocumentation.lua`), largest first.
  [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_AbbreviateNumbers)
  gives the formula from the pre-12.0 Lua version: at or above a breakpoint,
  `floor(n / significandDivisor) / fractionDivisor` plus the suffix; below them
  all, `tostring(n)`. That is why a per-second amount under a thousand showed
  every decimal in game ("165.71428571429"). `Kit.ShortNumber` gives K, M, B
  and T breakpoints for 0-2 decimals and a last one at 0 (else 1) that rounds
  small numbers down to whole ones. The validity rules
  (`RequiresValidAbbreviationBreakpoints`) aren't documented, so the fullest set
  the client accepts is tried once per decimals on a public number, falling
  back to the plain call. `C_StringUtil.RoundToNearestString` and
  `FloorToNearestString` (`AllowedWhenTainted`) were the alternative for small
  numbers. Unverified natively: whether the client prints trailing zeros
  ("5.0K").
- **Moving and resizing by hand.** The window (a plain, unprotected frame) is
  `SetMovable` and `StartMoving`/`StopMovingOrSizing` from its header's
  `OnDragStart`/`OnDragStop`. `SetUserPlaced(false)` (guarded) keeps the
  client's layout cache from restoring the drop over ModeUI's saved place. The
  drop is saved through Position Manager (`Positioning:ReadFrame`, then
  `SetOffsets`), and the window hangs from its stand-in again. Resizing reads
  `GetCursorPosition()` over `UIParent:GetEffectiveScale()` and changes Width
  and Rows settings. Both run only out of combat, because Position Manager
  saves no places in combat.
- **The | separator.** FontString text treats "|" as the start of an escape
  code ("|cff..", "|r", "|T"), so the separator is written "||", which shows
  one "|".
- **Header glyphs.** Own textures (`Media/Textures/DamageMeters`), not
  Blizzard atlases, which may not exist on Forever. Tooltips show only public
  text.

## Interface chat and windows — November 13, 2026

Sources: Forever's own interface code on the `forever` branch of
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns)
(Forever is the `camelot` game type: `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT`,
[ProjectConstants.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ProjectConstants/Camelot/ProjectConstants.lua)),
checked against the user's local mainline copy (build 12.1.5.70575).
[Chat details](CHAT.md), [Windows details](WINDOWS.md).

**Chat** ([FloatingChatFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua),
[FloatingChatFrame.xml](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.xml)):

- **Frames.** `ChatFrame1`–`ChatFrame10` and their `ChatFrameNTab`; the count
  is `Constants.ChatFrameConstants.MaxChatWindows` (10). `NUM_CHAT_WINDOWS` is
  only defined behind the `loadDeprecationFallbacks` CVar, so ModeUI doesn't
  use it. Temporary whisper windows (`ChatFrame11+`) come from
  `FCF_OpenTemporaryWindow`; `CHAT_FRAMES` lists every window by name.
- **Art.** Chat windows use `FloatingBorderedFrame` (no NineSlice): the
  `Background` region and eight named border textures, plus the button frame's,
  all listed in `CHAT_FRAME_TEXTURES`. `FCF_FadeInChatFrame`/`FadeOut` fade only
  textures that are shown, so hidden ones stay hidden. `Background` is anchored
  once by `FloatingChatFrame_UpdateBackgroundAnchors` (−2, +3 / +15, −6 with the
  scroll bar), which the combat log calls again; the dock and button frame are
  anchored to it (`FCF_SetButtonSide`, `FCFDock_*`). ModeUI re-anchors the region
  after that function (post-hook).
- **Tabs.** `ChatTabArtTemplate`: `Left`, `Middle`, `Right`, `ActiveLeft/Middle/Right`,
  `HighlightLeft/Middle/Right`, `glow`, `Text` (centered 5 px below the middle
  of a 32 px tab). `FCFTab_UpdateColors(tab, selected)` shows the active art and
  colors the text; `FCFTab_UpdateAlpha` and the fades call `SetAlpha` on tabs.
  The `CHAT_FRAME_TAB_*` alphas are read through `ChatFrameUtil.GetTabAlphas`
  inside `securecallfunction`; Blizzard keeps them away from addon taint on
  purpose (it feeds `UIFrameFade`), so ModeUI never writes them. It post-hooks
  each tab's `SetAlpha` instead (`Skin.PinAlpha`), the approach long used by
  chat addons. `ChatFrameUtil.IsTabAlerting(tab)` and
  `FCFDock_GetSelectedWindow(dock)` are only read.
- **Edit box.** `ChatFrameEditBoxTemplate`: `$parentLeft/Mid/Right`,
  `focusLeft/Mid/Right`, `header`, `headerSuffix`, `languageHeader`, `prompt`,
  `NewcomerHint`. Blizzard anchors it once in XML. `ChatEdit_*` globals are only
  deprecated aliases, so nothing is hooked there; ModeUI only calls widget
  setters and `HookScript`s focus.
- **Buttons.** `ChatFrameMenuButton` (a `DropdownButton`) and
  `ChatFrameChannelButton` are children of `ChatFrame1ButtonFrame`;
  `ChatFrameToggleVoiceDeafenButton`/`MuteButton` hang from the channel button.
  `QuickJoinToastButton` and `TextToSpeechButtonFrame` are contained alerts of
  `ChatAlertFrame`, which is anchored once in its `OnLoad`. ModeUI reparents the
  four chat buttons into its compartment and re-anchors `ChatAlertFrame`.
  `C_VoiceChat.GetActiveChannelID` is only read.
- **Fonts.** `ChatFrameMixin` re-applies `GetFont()`'s file and flags with the
  saved size on `UPDATE_CHAT_WINDOWS`, so a face set with `SetFont` stays and the
  per-window size is Blizzard's. The setters go through
  `ScrollingMessageFrameSecureMixin` ("secure elevation barriers").
- **Edit Mode.** `ChatFrame1` inherits `EditModeChatFrameSystemTemplate`
  ([EditModeSystemTemplates.xml](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.xml)):
  its `Selection` (a plain child frame) is anchored once in XML, TOPLEFT
  −32, +60 and BOTTOMRIGHT +25, −32. The chat mixin doesn't override
  `AnchorSelectionFrame`; the base one only calls `UpdateClampOffsets`, which
  sets `SetClampRectInsets` from the selection's rect. Snapping reads the
  selection: `GetLeftOffset` and the rest take `Selection:GetPoint(1)` /
  `GetPoint(2)` x or y less `SELECTION_PADDING` (2), and the magnet code
  `Selection:GetRect()` ([EditModeSystemTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua)).
  ModeUI re-anchors the selection (TOPLEFT then BOTTOMRIGHT, relative to the
  window, as Blizzard reads them) over its box and tab row plus the 2-unit
  padding, sets the clamp insets to the box, and post-hooks the window's
  `AnchorSelectionFrame` to set them again. Geometry only: no Edit Mode
  table, setting or layout is written.
- **Not protected.** No chat frame is protected. Secure slash commands typed in
  the edit box run from its `ParseText`; ModeUI never replaces its scripts,
  methods or fields. Chat messages can be secret (`SecretInChatMessagingLockdown`,
  secret whisper tab names): ModeUI never reads or measures message, tab or
  header text.

**Windows** ([SharedUIPanelTemplates.xml](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml)):

- **Templates.** `PortraitFrameBaseTemplate` (`NineSlice`, `PortraitContainer`,
  `FrameGlow`, `TitleContainer.TitleText`), `PortraitFrameTexturedBaseTemplate`
  (adds `Bg`, `TopTileStreaks`), `ButtonFrameTemplate` (adds `Inset` with its
  own `NineSlice` and `Bg`), `DefaultPanelTemplate`, `BasicFrameTemplate` (corner
  and edge textures, `TitleBg`). NineSlice pieces: `TopLeftCorner` … `Center`
  ([NineSlice.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/NineSlice.lua)).
  `ApplyLayout` re-sets atlases but never alpha, so faded pieces stay faded.
  `SetTitle` only sets text. Forever's `CharacterFrame` is
  `PortraitFrameBaseTemplate` with its art in `LeftPaneHost`/`RightPaneHost`
  ([CharacterFrame.xml](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml)).
  `SettingsPanel`'s title is `NineSlice.Text`, so pieces are faded one by one.
- **Controls.** `PanelTabButtonTemplate`/`TabSystemButtonTemplate`
  (`Left…RightActive`, highlights, `Text`): `PanelTemplates_SelectTab`,
  `DeselectTab` and `SetDisabledTabState` only show and hide art and reset the
  font, so ModeUI post-hooks them. Side tabs (`LargeSideTabButtonTemplate`:
  `Background`, `Icon`, `SelectedTexture`). `UIPanelCloseButton` (Forever's
  `UIPanelCloseButtonDefaultAnchors` places it once in `OnLoad`).
  `MinimalScrollBar` and `WowTrimScrollBar` (`Track`, `Track.Thumb`, `Back`,
  `Forward`, `Backplate`, `Background`) re-set atlases on state changes, so
  their textures are faded, not replaced.
- **Load on demand.** `PlayerSpellsFrame` (`Blizzard_PlayerSpells`),
  `ProfessionsFrame` (`Blizzard_Professions`), `CollectionsJournal`
  (`Blizzard_Collections`), `AchievementFrame` (`Blizzard_AchievementUI`),
  `LFGListingFrame`/`LFGBrowseFrame` (`Blizzard_GroupFinder_VanillaStyle`),
  `InspectFrame`, `ClassTrainerFrame`, `AuctionHouseFrame`, `MacroFrame`; ModeUI
  skins them on `ADDON_LOADED`. Not on Forever: `PVEFrame`, `EncounterJournal`,
  `PVPUIFrame`, `ProfessionsBookFrame`.
- **Combat.** `SetPoint`, `SetSize`, `Show`/`Hide` and `SetParent` are blocked
  on protected objects in combat; `SetAlpha`, `SetTexture`, `SetVertexColor`,
  `SetFont` and `CreateTexture` are not. Collections and Professions hold
  `SecureFrameTemplate` children, so windows reporting `IsProtected()` are
  skinned through `Defer`. ModeUI never calls `ShowUIPanel`/`HideUIPanel`.
- **Unverified natively:** that the glass tab, sheen and rims render at
  exactly one physical pixel at the user's UI scale; that no window path is
  tainted (casting from the spellbook, using toys, the Game Menu buttons, which
  Blizzard rebuilds on every show); that `ChatAlertFrame` keeps its new anchor;
  and the World Map's look without a fill.

### Chat and windows, second pass — November 13, 2026

Checked against the `forever` branch of Gethe/wow-ui-source and the local
12.1.5 copy. [Chat details](CHAT.md), [Windows details](WINDOWS.md).

- **Chat font.** `ChatFrameMixin:OnLoad` sets `ChatFontNormal` once; every
  Blizzard size change reads `GetFont()` and keeps the file. A chat frame's
  `SetFont` is `FontableFrameMixin:SetFont` (Lua), which returns nothing, so
  `Skin.Font` only falls back on an explicit `false` (FontStrings answer true
  or false). Each line's FontString takes the frame's font object on every
  refresh, so the frame is the only place a face sticks.
- **Chat scroll bar.** `ScrollBar` is a `MinimalScrollBar` (Track
  Begin/Middle/End, Track.Thumb, Back/Forward `.Texture`).
  `FloatingChatFrame_UpdateScroll` calls `SetShown` on every refresh and the
  fades call `UIFrameFade` (which calls `Show`), so ModeUI pins its alpha
  (`Skin.PinAlpha`) and re-places it after `FCF_UpdateScrollbarAnchors`
  (post-hook). `ScrollToBottomButton.Flash` is shown by
  `ChatFrameUtil.StartFlash`; `Skin.Suppress` hides it again.
- **Chat tab width.** `PanelTemplates_TabResize` measures `tab.Text` in the
  font it has. ModeUI post-hooks it and, for static docked or undocked tabs
  only (never `WHISPER`/`BN_WHISPER`, which Blizzard gives a fixed width
  "to avoid propagation of secret values"), measures again in the Mode face
  with plain widget calls. It never calls `FCFDock_*` or writes `dock.isDirty`.
- **Menus.** `DropdownButtonMixin.Event.OnMenuOpen`/`OnMenuClose` through the
  dropdown's callback registry; `dropdown.menu` is the open menu frame. Menu
  frames come from one pool for every menu, and while open their
  `CreateTexture` errors, so ModeUI lends one frame of its own and takes it
  back on close; the menu's background texture (`common-dropdown-bg`) is
  re-made with its alpha on every `Generate`.
- **Lists.** `ScrollUtil.AddInitializedFrameCallback(scrollBox, callback,
  owner)` runs after Blizzard fills each row; ModeUI only sets fonts and
  fades row textures there.
- **Guild window.** `MemberList.InsetFrame` is raised to frame level 100,
  over the roster rows (`CommunitiesMemberList.xml`), which is why a fill on
  an inset now goes on its parent. Offline members are Blizzard's
  `DISABLED_FONT_COLOR` (text color, not alpha). `PortraitOverlay` holds the
  club avatar and tabard; `MaximizeMinimizeFrame` is a
  `MaximizeMinimizeButtonFrameTemplate`; the right side tabs inherit
  `RightSideTabTemplate` (an unnamed tab texture, `Icon`, a checked texture).
- **Character window.** Forever's Camelot paper doll: slots
  `Character<Name>Slot` (left: Head–Wrist, right: Hands–Trinket1, bottom:
  MainHand, SecondaryHand, Ranged), each an ItemButton with `IconBorder` and
  `BorderFrame`; `CharacterModelScene`; `PaperDollFrame`. Not protected.
  - Stats: `UnitStat`, `UnitArmor`, `UnitAttackPower`,
    `UnitRangedAttackPower`, `GetSpellBonusDamage`, `GetSpellBonusHealing`,
    `GetCritChance`, `GetSpellCritChance`, `GetRangedCritChance`,
    `GetHitModifier`, `GetSpellHitModifier`, `GetCombatRatingBonus`
    (`CR_HIT_MELEE`, `CR_HIT_SPELL`, defined by Forever's paper doll),
    `GetMeleeHaste`, `UnitSpellHaste`, `GetExpertise`, `GetDodgeChance`,
    `GetParryChance`, `GetBlockChance`, `GetManaRegen` — all called by
    Forever's own paper doll, all `SecretWhenUnitStatsRestricted`: a secret
    value shows a dash. Main stat: `C_SpecializationInfo.GetSpecialization`
    and the 6th return of `GetSpecializationInfo`.
  - Quality: `GetInventoryItemQuality` and `C_Item.GetItemQualityColor`
    (falling back to `ITEM_QUALITY_COLORS`).
  - Enchants: no API names an enchant ID. ModeUI reads
    `C_TooltipInfo.GetInventoryItem("player", slot)`: the line of type
    `Enum.TooltipDataLineType.ItemEnchantmentPermanent` (15), stripped of
    `ENCHANTED_TOOLTIP_LINE`'s "Enchanted: "; otherwise, for weapons, the
    timed line ("Name (30 min)"), gated by Forever's
    `C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot)` `hasEnchant`.
  - Events: `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED`,
    `UNIT_STATS`, `UNIT_AURA`, `COMBAT_RATING_UPDATE`, `UNIT_ATTACK_POWER`,
    `UNIT_RANGED_ATTACK_POWER`, `UNIT_DAMAGE`, `UNIT_SPELL_HASTE`,
    `SPELL_POWER_CHANGED`, `WEAPON_ENCHANT_CHANGED`,
    `PLAYER_SPECIALIZATION_CHANGED` (each registered under `pcall`).
- **Unverified natively:** the timed tooltip line's exact text on Forever,
  the proc-enchant table's names on Forever, whether `ColumnDisplay` and
  list-row strips look right faded in every window, and how Window Text
  reads in long windows (Achievements, Collections).

## Tooltip — November 13, 2026

Checked against the `forever` branch of Gethe/wow-ui-source and the local
12.1.5 copy (the tooltip files match; Forever has no tooltip overrides).
[Details](TOOLTIP.md).

- **Frame.** `GameTooltip` → `GameTooltipTemplate` → `SharedTooltipTemplate`
  → `SharedTooltipArtTemplate`: a `NineSlice` (`TooltipDefaultLayout`) and
  `TopOverlay`/`BottomOverlay`. `SharedTooltip_SetBackdropStyle` (on load, on
  hide, on clear for comparisons, and after the data post-calls for azerite
  and corrupted items) calls `NineSliceUtil.ApplyLayout` (atlases and points,
  never alpha), `NineSlice:Show()` and `SetCenterColor`, so ModeUI fades the
  NineSlice with `SetAlpha(0)` and keeps its own fill and border.
- **Lines.** `GameTooltipTextLeft/RightN`; lines 3+ are made by the engine.
  Blizzard's Lua doesn't call `SetFontObject` on them (the Auction House buy
  dialog swaps line 1's font object). `FontString:SetText` accepts secret
  text, and a line's sizes are then secret, so ModeUI only sets fonts.
  `TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, fn)`
  runs addon post-calls insecurely through a forbidden delegate, before
  `Show()`; ModeUI sets fonts there and again in an `OnShow` hook.
- **Health bar.** `GameTooltip.StatusBar` (`GameTooltipStatusBar`):
  `SetValue(UnitPercentHealthFromGUID(guid))` (secret) from Blizzard's secure
  mixin; `HealthBar_OnValueChanged` colors it green on each change, so ModeUI
  re-colors it in an `OnValueChanged` hook. ModeUI only sets its texture,
  color, points and height.
- **Placement.** `GameTooltip_SetDefaultAnchor(tooltip, parent)` does
  `SetOwner(parent, "ANCHOR_NONE")` and anchors to `GameTooltipDefaultContainer`
  (an `EditModeHudTooltipSystemTemplate` frame: Forever has the HUD Tooltip
  Edit Mode system). ModeUI post-hooks it for `GameTooltip` only and calls
  `ClearAllPoints`/`SetPoint` (or `SetOwner(parent, "ANCHOR_CURSOR")`);
  GameTooltip isn't protected, so these work in combat. Blizzard's container
  is never touched.
- **Combat.** `GameTooltip:Hide()` from an `OnShow` hook is allowed (Blizzard's
  own `GameTooltip_OnShow` does it in Edit Mode); `GameTooltip_OnHide` is
  hardened for addon-touched tooltips. A post-call is too early to hide
  (`Show()` follows it).
- **Border colors.** `tooltip:GetItem()` → `C_Item.GetItemQualityByID` (no
  secret returns) and `C_Item.GetItemQualityColor`. `tooltip:GetUnit()` can
  return a secret token (`UnitTokenFromGUID` is
  `SecretWhenUnitIdentityRestricted`), and `UnitClass` errors on a secret
  token from addon code, so ModeUI checks the token is public first.
- **Unverified natively:** engine-made lines keeping the Mode face across
  tooltips, the health bar's placement under every unit tooltip, and Hide in
  Combat with tooltips Blizzard refreshes every 0.2 s (unit frames).

### Character window, third pass — November 13, 2026

- **Stats pane.** `CharacterStatsPaneScrollBox` (`ClassBackground`, `Border`
  `common-insideframe`, a scroll line) with `.ScrollBox` rows:
  `CharacterStatFrameCategoryTemplate` (`Background` `UI-Character-Info-Title`,
  `Title`) and `CharacterStatFrameScrollBoxBaseElementTemplate` (`Background`
  `UI-Character-Info-Line-Bounce2`, which Blizzard shows on every other row,
  `Label`, `Value`). ModeUI fades the headers' art and desaturates the row
  stripe (its shown state stays Blizzard's).
- **Model area.** Slots are 37 px; the left column's right edge (x 61) and the
  right column's left edge (x 341) bound the model, above the weapon row. The
  stats block hangs from a frame anchored to `CharacterHeadSlot`,
  `CharacterHandsSlot` and `CharacterWristSlot`, so it never reaches a slot.
- **Other parts.** `PaperDollFrame.TopBackgroundStripHost` (rock strip,
  `_UI-Frame-InnerTopTile`), `RightPaneToggleButton`, and
  `CharacterFrameModeTab1..6` (`LargeSideTabButtonTemplate`, a Frame whose
  `SelectedTexture` shows when checked). `SetPaperDollBackground` resets the
  model's `BackgroundOverlay` alpha on every show, so ModeUI leaves the model
  backdrop alone.
- **Dropdowns.** `WowStyle1/2DropdownTemplate` roots are `DropdownButton`, an
  intrinsic `Button` (`GetObjectType` answers "Button"); ModeUI recognises
  them by `Background`, `Arrow` and DropdownButtonMixin's methods. The Guild
  chat edit box's middle piece is `Mid`.

### Tooltip, second pass — November 13, 2026

- **Screen.** `SetClampedToScreen(true)` and `SetClampRectInsets(0, 0, 0, 0)`
  on each skinned tooltip (plain widget calls; GameTooltip isn't protected).
  ModeUI's border is inside the tooltip, so clamping keeps it on the screen.
- **Size.** `SetMinimumWidth` and `SetPadding(right, bottom, left, top)`,
  reset by Blizzard's style calls, so set in the post-call and on show.
- **Text colors.** `FontString:SetTextColor` takes plain colors; a line's
  `GetText` is only compared when `issecretvalue` says it's public, and the
  level number is recolored with `SetText` on that public text only.
  `UnitIsPlayer`, `UnitReaction(unit, "player")`, `UnitIsTapDenied` and
  `UnitLevel` (no secret returns) are called only with a public token from
  `tooltip:GetUnit()`; `UnitClass` likewise (it's
  `SecretWhenUnitIdentityRestricted`: a secret class leaves Blizzard's
  colors). Level colors come from `GetCreatureDifficultyColor` /
  `GetQuestDifficultyColor` when present. Quest lines come from the post-call's
  tooltip data line types (`QuestTitle` 17, `QuestObjective` 8,
  `QuestPlayer` 18), matched to the shown line by position or public text.
- **Edit Mode.** `PositionManager:RegisterElement(..., { anyTarget = true })`
  allows every target registered so far (the game's frames and ModeUI's
  bars and meter windows) plus picked frames.
- **Unverified natively:** the line Blizzard puts the class name on for
  every player, `GetCreatureDifficultyColor` on Forever, and padding and
  minimum width surviving every tooltip refresh.

## Game menu button and addon compartment — November 13, 2026

Checked against the `forever` branch of Gethe/wow-ui-source (Forever loads
the game type `camelot`). Code: `Shared/Settings/Launchers.lua`.

- **Game menu.** `Blizzard_GameMenu.toc` loads `Shared/GameMenuFrame.lua` for
  camelot. `GameMenuFrameMixin:InitButtons()` runs on every show (and on
  `STORE_STATUS_CHANGED`/`TRIAL_STATUS_UPDATE`): it empties `self.buttons`,
  calls `Reset()` (releases the pooled buttons) and adds Options, Shop,
  `AddSection()`, AddOns, Edit Mode, Support, Macros, `AddSection()`, Log Out,
  Exit Game and Return to Game. Forever's `AddButton(text, callback,
  isDisabled, disabledText, useGoldRedButton)` appends to `self.buttons`;
  `MainMenuFrameMixin:AddButton` (`Blizzard_SharedXML/Shared/Frame/MainMenuFrameTemplates.lua`)
  gives each button a `layoutIndex`, the pending `topPadding` (20 after
  `AddSection`) and calls `MarkDirty()`. ModeUI post-hooks `InitButtons` with
  `hooksecurefunc`, adds its button, moves it in `self.buttons` before the
  first button after Options that starts a section (AddOns), gives it and that
  button a 20 px `topPadding`, renumbers `layoutIndex` and narration in list
  order (as Play The Game Tools does, so both addons' buttons fit), and
  re-runs `ResetGamepadButtons`/`SetupGamepadButtons`. It adds nothing in
  combat. The click does what Blizzard's own buttons do: `PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)`,
  `HideUIPanel(GameMenuFrame)`, then opens the settings window.
- **Addon compartment.** `Blizzard_Minimap.toc` loads the mainline
  `AddonCompartment.lua`, then camelot's own `Camelot/AddonCompartment.lua` and
  `.xml` (the mainline XML is excluded for camelot). Camelot keeps the mixin
  and only restyles `AddonCompartmentFrame` (a
  `DropdownButton` on `MinimapCluster`). `AddonCompartmentMixin:RegisterAddon({ text,
  icon, func, funcOnEnter, funcOnLeave })` adds an entry and shows the button;
  entries are sorted by text with hyperlinks stripped. Registering this way
  needs no global function (the TOC's `AddonCompartmentFunc` would).
- **Unverified natively:** the button's exact spot when other addons also add
  game menu buttons, and the compartment entry's sort position with a color
  code at the start of its text.

### Friends button and anchoring — November 13, 2026

- **Friends button.** `QuickJoinToastButton` (`Blizzard_QuickJoin`): a
  `ContainedAlertFrame` with textures `FriendsButton`, `QueueButton`,
  `FlashingLayer` (re-atlased and faded by its toast animations) and the font
  strings `FriendCount`/`QueueCount`. `ChatAlertFrame` (an
  `AlertContainerMixin`) re-anchors it in `UpdateAnchors`
  (`AlertFrameAutoAnchoredMixin:AdjustAnchors`); ModeUI post-hooks that and
  puts it back in the compartment. `TextToSpeechButton` shows itself through
  `UpdateVisibleState` (`SetShown`) and joins the compartment the same way.
- **Anchoring.** `PositionManager:AnchorNear` picks the side from the two
  frames' centers (`Positioning:Geometry`, public numbers only). Before
  anchoring, the target's anchor points are walked (`GetNumPoints`/`GetPoint`,
  16 levels): a target that already hangs from the element would make a
  native anchor loop, which the client refuses; that anchor is refused.
- **Unverified natively:** what exactly sent the owner's meter window and
  tooltip to the top left corner; the simulated client doesn't reproduce it.
  The loop and off-screen checks above stop both causes that fit.

## Bags — November 13, 2026

Checked against the `forever` branch of Gethe/wow-ui-source. Forever loads
`Blizzard_UIPanels_Game` as the `camelot` game type: the mainline
`[Family]\ContainerFrame.lua`/`.xml` plus `Camelot\ContainerFrame.lua` (two
small overrides: the portrait mask, and empty combined slots show the bag
icon). [Details](BAGS.md).

- **Bag IDs.** `Constants.InventoryConstants.NumBagSlots` (4) and
  `NumReagentBagSlots`; bag 0 is the backpack, 1-4 the equipped bags, 5 the
  reagent bag. `KEYRING_CONTAINER`/`Enum.BagIndex.Keyring` (-2), shown when
  `C_ActionBar.ShouldShowKeyring()`, sized by `GetKeyRingSize()` (Blizzard's
  `ContainerFrame_GetContainerNumSlots` does the same).
- **Reads.** `C_Container.GetContainerNumSlots`, `GetContainerNumFreeSlots`,
  `GetContainerItemInfo` (→ `ContainerItemInfo`: `iconFileID`, `stackCount`,
  `isLocked`, `quality`, `hyperlink`, `isFiltered`, `hasNoValue`, `itemID`,
  `itemName`, ...), `GetContainerItemQuestInfo`, `GetContainerItemCooldown`,
  `C_NewItems.IsNewItem`, `C_Item.GetItemInfoInstant`,
  `C_Item.GetDetailedItemLevelInfo`, `C_Item.GetItemQualityColor`,
  `GetMoney`. All are `SecretArguments = "AllowedWhenUntainted"` (ModeUI
  passes plain bag and slot numbers) with no secret returns; Domain still
  keeps only public values.
- **Search and sort.** `C_Container.SetItemSearch(text)` sets the game's bag
  search (Blizzard's `BagItemSearchBox` uses it) and fires
  `INVENTORY_SEARCH_UPDATE`; matches come back through `isFiltered`.
  `C_Container.SortBags()` is Blizzard's "Clean Up Bags"; no restrictions in
  the documentation; ModeUI doesn't call it in combat.
- **Item buttons.** `ContainerFrameItemButtonTemplate` (an `ItemButton`, not
  secure). Its `OnClick` (`ContainerFrameItemButtonMixin:OnClick` →
  `ContainerFrameItemButton_OnClick`) and `OnModifiedClick`, drag handlers
  and `OnEnter` tooltip read only `self:GetID()` and `self:GetBagID()`
  (`self.bagID or self:GetParent():GetID()`; `bagID` comes from the
  `bagid` attribute, which ModeUI never sets). ModeUI parents each button to
  a holder with `SetID(bag)` and gives it `SetID(slot)`, so Blizzard's
  handlers start from Blizzard's code with values from the client.
  `CreateFrame("ItemButton", name, parent, template)` with a name: the
  template names children `$parentCooldown` and `$parentIconQuestTexture`.
- **Equipped bags (Bag Bar).** Blizzard's own bag slot buttons
  (`BaseBagSlotButtonMixin`,
  [Shared/MainMenuBarBagButtons.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua))
  call `PutItemInBag(inventorySlot)` on click and receive-drag,
  `PickupBagFromSlot(inventorySlot)` on drag start, read
  `GetInventoryItemTexture("player", slot)` and show
  `GameTooltip:SetInventoryItem("player", slot)` (else `EQUIP_CONTAINER` /
  `EQUIP_CONTAINER_REAGENT`); a bag ID's slot comes from
  `C_Container.ContainerIDToInventoryID(bag)`. ModeUI's footer bag slots are
  its own plain buttons making the same calls (through Domain), with
  `CursorHasItem()` deciding whether a click puts a bag on, and
  `GetInventoryItemQuality` for the rim. Nothing of Blizzard's bag bar is
  touched.
- **Cooldown text.** `Cooldown:GetCountdownFontString()` (as the Action Bars
  use) gives the countdown FontString; ModeUI sets its font, color and place.
- **Opening and closing.** `OpenAllBags`, `CloseAllBags`, `ToggleAllBags`,
  `ToggleBackpack`, `OpenBag`, `ToggleBag`, `CloseBag` show and hide
  `ContainerFrameCombinedBags` or `ContainerFrame1-N` (`NUM_CONTAINER_FRAMES`)
  through `ContainerFrame_GenerateFrame` (`SetBagID` = `SetID`, then `Show`).
  `IsBagOpen` and `IsAnyBagOpen` use `IsShown()`, which stays true under a
  hidden parent. `FRAME_THAT_OPENED_BAGS` is a file local in Forever, so
  ModeUI calling `CloseAllBags()` writes no global. Esc reaches
  `CloseAllWindows` → `CloseAllBags()`; center panels call
  `securecall("CloseAllBags")`. `ContainerFrame_SetFullScreenFrame` and
  `ContainerFrame_ClearFullScreenFrame` reparent the bag frames
  (`FrameUtil.SetParentMaintainRenderLayering`), so ModeUI post-hooks both.
  The frames aren't protected, so `SetParent` works in combat.
- **Unverified natively:** using items and splitting stacks from ModeUI's
  buttons in combat (expected to work, as Blizzard's handler runs) and the
  bag bar's open highlights while Blizzard's frames are hidden. The junk
  coin uses the atlas Forever's own template names (`bags-junkcoin`).

## Cooldown Manager — November 13, 2026

Checked against the `forever` branch of Gethe/wow-ui-source (head 1.60.1,
70938) and the local mainline 12.1.5 copy. [Details](COOLDOWN_MANAGER.md).

- **Forever has it.** `Blizzard_CooldownViewer.toc` adds `camelot` to
  `AllowLoadGameType` (mainline: `standard` only); not load-on-demand,
  depends on `Blizzard_EditMode`. Its files match mainline except: the
  Essential, Utility and BuffIcon `layoutIndex` (13/14/12 instead of
  10/11/9); category cooldowns (`GetSpellID(optDataSource)`,
  `spellIDForCategory`); viewers listening to `EditMode.RefreshCooldownViewer`.
  None of that touches the item structure ModeUI styles.
- **Frames.** `EssentialCooldownViewer`, `UtilityCooldownViewer`,
  `BuffIconCooldownViewer` (all `BottomManagedFrameTemplate`) and
  `BuffBarCooldownViewer`, each `CooldownViewerTemplate`
  (`EditModeCooldownViewerSystemTemplate, GridLayoutFrame`). No template is
  protected or secure. Items come from `viewer.itemFramePool`
  (`CreateFramePool`, the viewer as parent); `RefreshLayout` releases them
  all, acquires `max(#ids, 2)`, sets `layoutIndex`, calls
  `OnAcquireItemFrame` (scale = Edit Mode Icon Size, tooltips, timer), then
  `RefreshData` and `Layout()`. `GridLayoutFrameMixin:Layout` anchors the
  children, then `ResizeLayoutMixin.Layout` sizes the viewer from them, so a
  post-hook that re-anchors them afterward leaves the viewer's size as
  Blizzard computed it.
- **Item keys.** Essential/Utility: `Icon` (masked by an unnamed
  `MaskTexture`, atlas `UI-HUD-CoolDownManager-Mask`), an unnamed overlay
  (`UI-HUD-CoolDownManager-IconOverlay`), `OutOfRange`, `Cooldown`,
  `ChargeCount.Current`, `CooldownFlash`. BuffIcon: `Icon`, `Cooldown`,
  `DebuffBorder`, `Applications.Applications`. BuffBar: `Icon` (a frame;
  `Icon.Icon`, `Icon.Applications`), `DebuffBorder`, `Bar` (StatusBar with
  `BarBG`, `Pip`, `Name`, `Duration`). `SetBarContent` re-anchors `Bar` to
  `Icon` and shows or hides the icon with plain values.
- **Secret values.** Blizzard's item code does arithmetic and comparisons on
  aura and cooldown values (`expirationTime - GetTime()`), allowed only
  while untainted, so a field written on an item from addon code would
  break it. `hooksecurefunc` post-hooks keep Blizzard's call untainted.
  `C_CooldownViewer.GetCooldownViewerCooldownInfo`, `GetCooldownViewerCategorySet`
  and `SetLayoutData` are `SecretArguments = "AllowedWhenUntainted"` with no
  secret returns; cooldown IDs are plain numbers. `IsShown` has
  `SecretReturnsForAspect = Shown`: an item shown from secret aura data can
  answer secret, which ModeUI treats as shown.
- **Cooldown widget.** `SetSwipeColor`, `SetDrawEdge`, `SetDrawSwipe`,
  `SetDrawBling` and `SetEdgeColor` are `AllowedWhenTainted`;
  `SetSwipeTexture` is `AllowedWhenUntainted` (ModeUI passes a plain path).
  Blizzard sets the swipe color, swipe and edge on every
  `RefreshSpellCooldownInfo` (cooldown items) and `RefreshCooldownInfo`
  (buff icons), so ModeUI sets its own after those. The aura swipe is
  `CooldownViewerConstants.ITEM_AURA_COLOR`, compared by reference
  (`rawequal`).
- **Cooldown state.** `C_Spell.GetSpellCooldown` is
  `SecretWhenCooldownsRestricted`, but `SpellCooldownInfo.isActive` and
  `isOnGCD` are `NeverSecret`; Glow When Ready reads only those, on
  `SPELL_UPDATE_COOLDOWN`. `C_Spell.GetSpellName` and `GetSpellTexture`
  for the preview.
- **Procs.** `CooldownViewerCooldownItemMixin:RefreshOverlayGlow` calls
  `ActionButtonSpellAlertManager:ShowAlert(item)` / `HideAlert(item)`, which
  create `item.SpellActivationAlert` (1.4 times the item's size).
- **Visibility.** `CooldownViewerMixin:ShouldBeShown` hides the viewers when
  the `cooldownViewerEnabled` CVar is off, when
  `C_CooldownViewer.IsCooldownViewerAvailable()` says no, or by the Edit
  Mode Visibility setting (Always, InCombat, Hidden). The checkbox is
  `Settings.SetupCVarCheckbox(category, "cooldownViewerEnabled",
  ENABLE_COOLDOWN_VIEWER)` in the `ADVANCED_OPTIONS_LABEL` category,
  enabled on Forever by `Camelot\InterfaceOverrides.HasCooldownViewer()`
  (`true`). ModeUI reads the CVar (`C_CVar.GetCVarBool`) and never sets it.
  Item alpha is never set by Blizzard; the viewer's is (Edit Mode Opacity).
- **Cooldown Settings.** `CooldownViewerSettings:TogglePanel()` (what the
  slash command and Edit Mode call) opens Blizzard's spell lists through
  `ShowUIPanel`; ModeUI's button calls it outside combat only.
- **Unverified natively:** the whole module (no in-game run yet); whether the
  `AdvancedOptions.lua` checkbox loads for `camelot` (its TOC entry is
  `[AllowLoadGameType mainline]`); hooks and re-anchoring during Blizzard's
  own Edit Mode.

### Cooldown Manager, second pass — November 13, 2026

Own window, custom bars, gray on cooldown, four glows. Checked against the
local mainline 12.1.5 copy and the Forever files from the first pass.

- **Gray on cooldown.** Blizzard sets `cooldownDesaturated = isOnActualCooldown`
  in `CheckCacheCooldownValuesFromSpellCooldown` and applies it in
  `CooldownViewerCooldownItemMixin:RefreshIconDesaturation`, which `RefreshData`
  and `RefreshCooldownOnly` call after `RefreshSpellCooldownInfo`. ModeUI
  post-hooks it and calls `Texture:SetDesaturated` with a public boolean
  (`SecretArguments = "AllowedWhenTainted"`) from `C_Spell.GetSpellCooldown`'s
  never-secret `isActive`/`isOnGCD`.
- **Active state.** `CheckCacheCooldownValuesFromAura` sets
  `cooldownSwipeColor = CooldownViewerConstants.ITEM_AURA_COLOR` (a shared
  table) while a spell's aura or totem is shown; other paths set
  `ITEM_COOLDOWN_COLOR`. A reference comparison (`rawequal`) reads no secret.
- **Buff state.** `CooldownViewerItemMixin:SetIsActive(active)` stores
  `isActive`; for buffs it comes from `IsExpired()`, which compares aura
  times and can be secret in combat. `SimpleRegion:SetAlphaFromBoolean(value,
  alphaIfTrue, alphaIfFalse)` is `AllowedWhenTainted`; ModeUI passes the value
  with the default alphas, and never tests it.
- **Custom bars.** They re-anchor Blizzard's item frames (plain frames) to
  ModeUI holders, exactly as the viewers' own layout does; the item stays the
  viewer's child, so `ShouldBeShown` (the CVar, Edit Mode Visibility) still
  hides it. No new API.
- **Edit Mode return.** ModeUI's own `BeginEditWorkspace`/`FinishEditWorkspace`
  (`Shared/Settings/EditMode.lua`) remember a registered settings window that
  was open; no Blizzard API.
- **Unverified natively:** everything here; `SetAlphaFromBoolean`'s default
  alphas on a texture whose vertex color carries its own alpha (the soft glow).

### Cooldown Manager, border and range — November 13, 2026

- **Out of range.** The item templates show `OutOfRange` (atlas
  `UI-CooldownManager-OORshadow`, vertex alpha 0.5) by default.
  `CooldownViewerCooldownItemMixin:RefreshIconColor` hides or shows it only
  after its `if not spellID then ... return end`, so on an item with no spell
  it stays shown. ModeUI had repainted it as a flat fill, which showed as a
  red block in game (owner's screenshot); it now only fades it (`SetAlpha(0)`)
  and leaves the atlas alone. The same function tints the icon
  `ITEM_NOT_IN_RANGE_COLOR` (0.64, 0.15, 0.15) from `self.spellOutOfRange`;
  Out of Range Tint off resets the vertex color after it when that field is
  public and `true`.
- **Border.** `Kit.ModeBoxBorder` draws on a child frame of the item; its
  masks are ModeUI's own regions and are not applied to Blizzard's
  textures. No new client API.

### Cooldown Manager, custom spells by ID — November 13, 2026

Checked against the `forever` branch's `SpellDocumentation.lua`,
`FrameAPICooldownDocumentation.lua`, `LuaDurationObjectAPIDocumentation.lua`,
`SpellActivationOverlayDocumentation.lua` and `SpellBookDocumentation.lua`
(same as local mainline for these), and the events Forever's own
Cooldown Manager registers.

- **Cooldowns.** `C_Spell.GetSpellCooldownDuration(spell, ignoreGCD)` and
  `GetSpellChargeDuration(spell)` return a `LuaDurationObject`
  (`SecretArguments = "AllowedWhenTainted"`). It goes straight to
  `Cooldown:SetCooldownFromDurationObject(duration)`, never read. The setter
  is documented `IsProtectedFunction`, like every Cooldown setter including
  `SetCooldown`, which addons call on cooldowns they create; ModeUI only
  calls it on its own icons' Cooldown frames, through `pcall`.
- **Charges.** `C_Spell.GetSpellCharges` is `SecretWhenCooldownsRestricted`;
  `maxCharges` and `isActive` are `NeverSecret`, `currentCharges` goes only to
  `FontString:SetText`.
- **State.** `C_Spell.GetSpellCooldown` (`isActive`, `isOnGCD` never secret),
  `C_Spell.IsSpellUsable`, `C_Spell.DoesSpellExist`, `C_Spell.GetOverrideSpell`,
  `C_Spell.GetSpellTexture`, `C_Spell.GetSpellName` and
  `C_SpellBook.IsSpellKnown` (`AllowedWhenUntainted` arguments: ModeUI passes
  plain spell IDs). A secret or failed answer counts as unknown.
- **Events.** `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_USES`, `SPELL_UPDATE_ICON`,
  `SPELL_UPDATE_USABLE` and `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`/`HIDE` (payload
  `spellID`, used only when public), all registered by Forever's own
  `Blizzard_CooldownViewer`; `SPELLS_CHANGED` (`SpellBookDocumentation`).
- **Tooltip.** `GameTooltip:SetSpellByID`.
- **Unverified natively:** all of it, in particular `SetCooldownFromDurationObject`
  from addon code on Forever.
### Cooldown Manager, glows, class spells and items — November 13, 2026

Checked against the `forever` branch's `CooldownViewerDocumentation.lua`,
`ItemDocumentation.lua`, `ContainerDocumentation.lua`,
`SpellBookDocumentation.lua` and `FrameAPICooldownDocumentation.lua` (same
as local mainline 12.1.5 for these).

- **Active swipe.** `Cooldown:SetUseAuraDisplayTime(bool)`
  (`AllowedWhenUntainted`; ModeUI passes a plain boolean) and
  `SetCooldownFromDurationObject` with the spell's own
  `C_Spell.GetSpellCooldownDuration(spell, true)`, after Blizzard's
  `RefreshSpellCooldownInfo`, while the item shows its aura (gold swipe
  color, compared by reference). **Show Aura Time** leaves Blizzard's swipe.
- **Glows.** Pixel glow: plain textures moved by one shared `OnUpdate`
  ticker that runs only while a Pixel, Blizzard or GCD glow shows. Blizzard
  and GCD glows: a FlipBook animation on ModeUI's own texture with the
  atlases `UI-HUD-ActionBar-Proc-Loop-Flipbook` (6 by 5, 30 frames, 1 s) and
  `RotationHelper_Ants_Flipbook`; an atlas the client lacks
  (`C_Texture.GetAtlasInfo` returns nothing) falls back to the proc loop.
- **Class spells.** `C_CooldownViewer.GetCooldownViewerCategorySet(category,
  allowUnlearned)` with `Enum.CooldownViewerCategory` `Essential`, `Utility`,
  `TrackedBuff`, `TrackedBar` and `true`: every cooldown ID for your class
  and spec, learned or not. `GetCooldownViewerCooldownInfo` gives each one's
  `spellID` and `isKnown` (plain fields of `CooldownViewerCooldown`). A spell
  counts as "Not in Blizzard CDM" when no viewer shows an item for its
  cooldown ID now.
- **Spell ID.** Added only when `C_SpellBook.IsSpellKnown` says yes for the
  spell or its override (unknown counts as yes), or when it comes from the
  class list above.
- **Items.** `C_Item.DoesItemExistByID`, `GetItemNameByID`,
  `GetItemIconByID`, `GetItemSpell` (a Use: effect), `GetItemCount(item,
  false, true)` (charges counted, no bank), `IsUsableItem`,
  `RequestLoadItemDataByID`, and `C_Container.GetItemCooldown(itemID)`
  (start, duration and enable as plain numbers; none of these are marked
  secret). The cooldown goes to `Cooldown:SetCooldown` on ModeUI's own
  icon. Bag contents through `Shared/Domain/Containers.lua`
  (`GetContainerNumSlots`, `GetContainerItemInfo`).
- **Events.** `BAG_UPDATE_COOLDOWN`, `BAG_UPDATE_DELAYED`
  (`ContainerDocumentation`) and `ITEM_DATA_LOAD_RESULT`
  (`ItemDocumentation`), all present on Forever.
- **Tooltip.** `GameTooltip:SetItemByID`.
- **Unverified natively:** all of it, in particular whether Forever's
  category sets list every class spell, item cooldowns in combat, and the
  flipbook atlases.

### Cooldown Manager, racial abilities — November 14, 2026

Blizzard's Cooldown Manager doesn't track racials, so ModeUI shows the ones
you know on its own icons (the same as spells added by ID). The spell IDs
come from Blizzard's own table of racial cooldowns
(`Blizzard_CooldownBroadcaster/TrackedCooldowns.lua`, `RacialCooldowns`,
12.1.5 mainline source), including each class's Arcane Torrent and Gift of
the Naaru, plus Blood Fury's class versions (33697, 33702). A racial shows
only when `C_SpellBook.IsSpellKnown(spellID)` returns a public `true` and `C_SpellBook.FindSpellBookSlotForSpell(spellID)` finds a slot (both on the Forever branch; IsSpellKnown alone showed a second, unusable Blood Fury on an orc), one per spell name,
(`Domain.Cooldowns.SurelyKnown`); a missing API, an error or a secret answer
means not shown. `UnitRace` isn't needed. Forever's racial spell IDs and
`IsSpellKnown` answers for them need in-game confirmation.

### Cooldown Manager, resource bars — November 13, 2026

Sources: the local `WoWUI-live` 12.1.5 API documentation
(`UnitDocumentation.lua`, `SimpleStatusBarAPIDocumentation.lua`,
`SimpleStatusBarConstantsDocumentation.lua`) and Forever's own
`Blizzard_UnitFrame` on the `forever` branch of Gethe/wow-ui-source. Also
compared with how Sensei Class Resource Bar, BetterCooldownManager, Ayije
CDM and oUF draw resource bars (their approach, not their code).

- **Values.** `UnitPower`, `UnitPowerPercent`, `UnitPartialPower` and
  `GetComboPoints` are `SecretWhenUnitPowerRestricted`; `UnitPowerMax` is
  `SecretWhenUnitPowerMaxRestricted`; `UnitHealth` is secret on Forever.
  ModeUI passes them only to `StatusBar:SetMinMaxValues`/`SetValue`
  (`AllowedWhenTainted`), `AbbreviateNumbers` and `FontString:SetText`/
  `SetFormattedText`. Percent text comes from `UnitPowerPercent(unit,
  powerType, false, CurveConstants.ScaleTo100)` and `UnitHealthPercent`.
  Nothing compares or does arithmetic on a value; there is no Hide When Full
  for that reason.
- **Smooth.** `StatusBar:SetValue(value, interpolation)` takes
  `Enum.StatusBarInterpolation.ExponentialEaseOut` (`NeverSecret`). A client
  without the enum gets the plain `SetValue`.
- **Combo points.** One `StatusBar` per point spanning `i - 1` to `i`, fed
  `SetValue(count)` (`Kit.FillResourcePoints`), so a secret count lights the
  right boxes without being compared. `Domain.ClassResource` reads
  `GetComboPoints("player", "target")` as Forever's Camelot
  `TargetBoundComboPointBar` does, and `COMBO_TARGET_CHANGED` (registered
  through `pcall`) moves them to a new target.
- **Alternate Mana.** Forever loads the mainline `AlternatePowerBar`, whose
  `ALT_POWER_BAR_PAIR_DISPLAY_INFO` pairs a Druid's mana only with
  `Enum.PowerType.LunarPower`. Camelot Druids show Rage in Bear Form and
  Energy in Cat Form, so the game shows no mana bar then. ModeUI reads
  `UnitPower("player", Enum.PowerType.Mana)` while the class is DRUID and
  `UnitPowerType` isn't `MANA` (`Domain.Power.AlternateManaActive`).
- **Events.** `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_POWER_FREQUENT`,
  `UNIT_MAXPOWER`, `UNIT_DISPLAYPOWER` (unit-filtered to the player on the
  module's own frame), `PLAYER_TARGET_CHANGED`, `PLAYER_ENTERING_WORLD`;
  `UPDATE_SHAPESHIFT_FORM` and `COMBO_TARGET_CHANGED` through `pcall`.
- **Frames.** Plain addon frames, never secure: they update, show, hide and
  fade in combat. Placement goes through ModeUI's Position Manager (moves
  only outside combat), and Match Width reads the anchor's width with
  `PositionManager:GetAnchorWidth` outside combat.
- **Unverified natively:** whether Forever marks player power or combo
  points secret in combat (both paths are handled), and whether
  `UPDATE_SHAPESHIFT_FORM` fires on Forever (`UNIT_DISPLAYPOWER` covers form
  changes either way).

### Cooldown Manager, Mode redesign inventory — November 15, 2026

Checked against the `forever` branch of Gethe/wow-ui-source at 1.60.1 (70938,
commit `bebcb6b`, November 13, 2026), the same build as above; nothing ModeUI
uses is missing or changed.

- **Blizzard_CooldownViewer (30 files):** viewers and items in
  `CooldownViewer.lua`/`.xml`, `CooldownViewerItemData.lua`,
  `CooldownViewerSecure.lua`, `CooldownViewerUtil.lua`; the settings window
  (`CooldownViewerSettings*`, `CooldownViewerDraggedItemBase*`); alerts
  (`CooldownViewerAlert.lua`, `CooldownViewerEditAlertBase*`,
  `CooldownViewerSettingsAlerts*`, `CooldownViewerSoundAlertData.lua`,
  `CooldownViewerVisualAlertTarget.lua`, `PandemicAlertAnimation.xml`);
  `GroupBuffFilter*`; `SlashCommandRegistration.lua`. The TOC has
  `## AllowLoadGameType: standard, camelot` and no `## Interface` line.
- **What the redesign relies on:** the item methods ModeUI post-hooks
  (`UpdateShownState` :314, `SetIsActive` :347, `RefreshSpellCooldownInfo`
  :1137, `RefreshIconDesaturation` :1195, `RefreshIconColor` :1204 (the
  Rosewood out-of-range tint goes on after it), `RefreshCooldownInfo`
  :1412/:1555, `SetBarContent` :1514), the parentKeys `Icon`, `Cooldown`,
  `ChargeCount`, `Applications`, `DebuffBorder`, `CooldownFlash`,
  `OutOfRange`, `Bar`, `BarBG`, `Pip`, and `spellOutOfRange` (:737). The
  Comet spark is a child frame on Blizzard's bar (`Style.Comet`), and the
  Mode edges are child frames on the items: nothing is written to their
  tables.
- **Not used yet, worth knowing:** `Enum.CooldownViewerCategory` also has
  `GroupBuff` (4), `SpecAgnosticEssential` (5), `SpecAgnosticTracked` (6),
  `EquipSlotEssential` (7) and `EquipSlotTracked` (8); the
  `CooldownViewerCooldown` struct has `equipSlot` and `buffSlot` (native
  trinket tracking); `C_CooldownViewer.GetGroupBuffItems`,
  `GetValidAlertTypes`, `GetLayoutData`; the events
  `COOLDOWN_VIEWER_DATA_LOADED`, `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`,
  `COOLDOWN_VIEWER_TABLE_HOTFIXED`. `CooldownViewerSecure.lua` keeps a
  secure aura map (`secretunwrap`, `settablesecurity(...,
  DisallowTaintedAccess)`), one more reason ModeUI never writes to the items.
- **Secret and protection flags:** every `Cooldown` setter is
  `IsProtectedFunction` with `SecretArguments = "AllowedWhenUntainted"`, and
  `SetCooldown` adds `SecretAspect.Cooldown`; ModeUI's own icons get duration
  objects (`GetSpellCooldownDuration` and `GetSpellChargeDuration` accept
  secrets from addon code) and item cooldowns as plain numbers
  (`C_Container.GetItemCooldown`, no secret flags). `C_CVar.GetCVarBool` is
  `SecretArguments = "NotAllowed"`.
- **The AddOn list (`Blizzard_AddOnList/AddonList.lua` :440-521):** an addon
  nests under the addon whose name equals its `Group` metadata (the client
  fills it for similar names and dependencies; `## Group` overrides). Only
  `## Category` headers collapse. `## IconTexture`/`## IconAtlas` give the
  icon. This is how `ModeCDM` sits under ModeUI.

## Party frames — November 13, 2026

Checked against the Forever branch of Gethe/wow-ui-source (1.60.1, build 70938,
November 13, 2026) and the local mainline 12.1.5 copy; the secret flags below
are identical on both. Design: [PARTY_FRAMES.md](PARTY_FRAMES.md). Native
confirmation is pending for everything here.

- **Secure group header.** `SecureGroupHeaderTemplate` ships in
  `Blizzard_RestrictedAddOnEnvironment` (`AllowLoadGameType: classic, standard,
  camelot`; `SecureGroupHeaders.lua` byte-identical to mainline). Attributes
  used: `template` (`SecureUnitButtonTemplate`), `templateType`, `showParty`,
  `showRaid` (off), `showPlayer`, `showSolo`, `point`, `xOffset`, `yOffset`,
  `unitsPerColumn` (5), `maxColumns` (1), `sortMethod` (`INDEX`), `sortDir`,
  `groupBy` (`ASSIGNEDROLE`) with `groupingOrder` (`TANK,HEALER,DAMAGER,NONE`),
  `startingIndex` and `initialConfigFunction`. `configureChildren` creates
  `min(unitsPerColumn × maxColumns, listed)` buttons, so `startingIndex = -4`
  makes all five up front. The header calls `SetPoint` on displayed buttons
  without `ClearAllPoints`, so ModeUI clears them before changing `point`. It
  sizes itself from `child1`, and it updates on `GROUP_ROSTER_UPDATE`, on
  `UNIT_NAME_UPDATE` for any unit and on attribute changes while it is
  visible; each update calls `SetAttribute("unit", ...)` on every button, so
  `OnAttributeChanged` fires with the same unit again and again. Visibility is
  `RegisterAttributeDriver(header, "state-visibility", ...)`. `SetRolesets`
  (`IsProtectedFunction`; `SimpleFrameAPIDocumentation`) gives the header the
  `unitFrames` roleset Blizzard's TargetFrame uses, in `pcall` and outside
  combat. `RegisterForClicks` and `SetParent` are protected; `SetAlpha`,
  `SetAlphaFromBoolean`, `SetScript` and `HookScript` are not.
- **Blizzard's party frames.** `PartyFrame` (`Shared/PartyFrame.lua`, an Edit
  Mode system) holds pooled `PartyMemberFrameTemplate` buttons
  (`SecureUnitButtonTemplate`), and `CompactPartyFrame` is created as its
  child. Members re-register their events in `Setup()` on every show, so
  unregistering doesn't hold, and faded members would still take clicks.
  ModeUI moves `PartyFrame` under a hidden frame (`SetParent`, outside combat)
  and puts it back when turned off. oUF (master, October 2026) uses
  `SetRolesets("alwaysBlocked")`; that roleset name appears nowhere in the
  Forever source, so ModeUI doesn't rely on it. How Blizzard's Edit Mode treats
  the moved system needs an in-game check.
- **Unit data** (`UnitDocumentation.lua`). `UnitInRange`: `SecretReturns`; the
  result goes only to `Frame:SetAlphaFromBoolean(value, 1, outOfRangeAlpha)`
  (`AllowedWhenTainted`; oUF's range element passes 0-1 alphas the same way).
  `UnitGetIncomingHeals`, `UnitGetTotalAbsorbs`, `GetRaidTargetIndex`:
  `SecretReturns`; the amounts go only to StatusBar `SetMinMaxValues`/`SetValue`
  on bars anchored to the health fill's end, and the index to
  `SetSpriteSheetCell` (Domain/RaidIcon.lua). `UnitGroupRolesAssigned`,
  `UnitIsGroupLeader`, `UnitPhaseReason`: `SecretWhenUnitIdentityRestricted`;
  read through `Query.Plain`, and a secret answer hides the icon.
  `UnitIsConnected`, `UnitIsDeadOrGhost` and `C_IncomingSummon` document no
  secret returns. `GetReadyCheckStatus` and `UnitHasIncomingResurrection` are
  undocumented legacy globals that Blizzard still calls from
  `CompactUnitFrame.lua`; they're `pcall`-guarded too. Atlases are Blizzard's own:
  `roleicon-tiny-*` and `UI-HUD-UnitFrame-Player-Group-LeaderIcon`/`GuideIcon`
  (PartyMemberFrame.lua), `UI-LFG-ReadyMark`/`DeclineMark`/`PendingMark`
  (ReadyCheck.lua) and `RaidFrame-Icon-Rez`/`SummonPending`/`SummonAccepted`/
  `SummonDeclined`/`Phasing` (CompactUnitFrame.lua).
- **Events.** `GROUP_ROSTER_UPDATE`, `PLAYER_ROLES_ASSIGNED`,
  `PARTY_LEADER_CHANGED`, `READY_CHECK`, `READY_CHECK_CONFIRM`,
  `READY_CHECK_FINISHED`, `RAID_TARGET_UPDATE`, `PLAYER_TARGET_CHANGED`, and per
  member (`RegisterUnitEvent`, each in `pcall`): `UNIT_HEALTH`,
  `UNIT_MAXHEALTH`, `UNIT_CONNECTION`, `UNIT_FLAGS`, `UNIT_POWER_FREQUENT`,
  `UNIT_MAXPOWER`, `UNIT_DISPLAYPOWER`, `UNIT_NAME_UPDATE`, `UNIT_AURA`,
  `UNIT_HEAL_PREDICTION`, `UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_IN_RANGE_UPDATE`
  (`SecretPayloads`; only re-queried), `UNIT_PHASE`, `UNIT_OTHER_PARTY_CHANGED`,
  `INCOMING_RESURRECT_CHANGED` and `INCOMING_SUMMON_CHANGED`. All are in the
  Forever docs.
- **Auras.** `Blizzard_AuraContainer` loads on Forever (no game-type gate;
  files identical to mainline). Shared helpers moved to
  `Shared/Kit/AuraContainer.lua` (detection with `C_XMLUtil.GetTemplateInfo`,
  the dispel color step curve, the time formatter); Nameplates uses them
  unchanged. Party groups use `AddAuraGroup` per filter,
  `SetFlowLayoutMaximumLineSize` for Per Row, and the dispel highlight
  `AddAuraSlot` (one button, hidden by the game while no aura matches) with
  `AddDispelTypeTexture` on textures created on that button in
  `initializeFrame` (`ValidateInboundScriptObject` requires the button's own
  regions). Every filter token used (`RAID_IN_COMBAT`, `RAID_PLAYER_DISPELLABLE`,
  `EXTERNAL_DEFENSIVE`, `BIG_DEFENSIVE`, `IMPORTANT`, `DISPELLABLE`,
  `CROWD_CONTROL`, `RAID`, `PLAYER`, and the `!` negation) is in Forever's
  `AuraUtil.AuraFilters`. Containers are made in `pcall`, so a refused filter
  leaves a group empty instead of stopping the module. Blizzard's aura buttons
  have their own tooltips (`AuraButtonPrivateMixin:OnEnter_Intrinsic`); Tooltips
  off disables the button's mouse. Private auras (`C_UnitAuras.AddPrivateAuraAnchor`,
  `AllowedWhenUntainted`) are not used yet.

### Party frames, second pass — November 13, 2026

Same source (Forever branch 1.60.1, build 70938). Native confirmation pending.

- **Debuffs by type.** `CustomAuraContainerTemplate` options take
  `candidateFilters` (`Blizzard_CustomAuraContainer.lua` `ValidateCandidateFilters`;
  checked in `AuraContainerUtil.DoesAuraPassCandidateFilters` in the secure
  environment): `includeDispelTypes` / `excludeDispelTypes` are maps of dispel
  type names (`"Magic"` ...). Each debuff type group is one container group with
  `includeDispelTypes = { [type] = true }`; Other Debuffs uses
  `excludeDispelTypes` for all five. Aura slots take the same filters, so the
  debuff effects are one `AddAuraSlot` per type. Regions given to
  `AddDispelTypeTexture` only need to descend from the button
  (`ValidateInboundScriptObject` uses `RegionUtil.IsDescendantOf`), so the
  effect sets live on child frames of the slot button and are rounded by that
  button's own border masks.
- **Heal prediction.** `CreateUnitHealPredictionCalculator` (no flags) and
  `UnitGetDetailedHealPrediction(unit, "player", calculator)`
  (`AllowedWhenUntainted` arguments, which plain unit tokens satisfy). The
  default clamp modes are `MissingHealth` (`UnitHealPredictionCalculatorSharedDocumentation.lua`):
  heals clamp to the missing health, shields to the missing health after heals.
  `GetIncomingHeals`, `GetDamageAbsorbs` (amount, clamped),
  `GetTotalDamageAbsorbs` and `GetMaximumHealth` go to StatusBar
  `SetMinMaxValues`/`SetValue`; the clamped flag goes to
  `SetAlphaFromBoolean` on the overshield bar (as oUF's
  `OverDamageAbsorbIndicator`). No amount is compared, not even with nil.
- **Hatch on a status bar.** A status bar stretches its fill texture to the
  value, so Mode Slate Hatch can't tile there. `Kit.FillTexture` keeps the
  bar's fill invisible and anchors a clipping frame
  (`Frame:SetClipsChildren`) to the fill texture; a full-size hatch texture
  inside it (`SetTexture(path, "REPEAT", "REPEAT", "NEAREST")`, tex coords of
  one texel per screen pixel) shows only where the bar is filled.
- **Power type.** `UnitPowerType` documents no secret returns; Mana Users and
  Healer Mana read its token through `Domain.Power.Read` and re-lay the bars on
  `UNIT_DISPLAYPOWER` and role changes (child frames only, safe in combat).
- **Keeping the group in place.** The stand-in's start corner is read with
  `GetLeft`/`GetBottom`/`GetWidth`/`GetHeight` and effective scales before and
  after a resize; the difference goes to `PositionManager:SetOffsets`, outside
  combat. No client API beyond those.

### Party frames, third pass — November 14, 2026

Same source. Native confirmation pending.

- **Box border corners.** The owner saw solid corner blocks and unrounded
  bars on the party frames' box border. The corners and their masks had used
  a quarter of `Mode/CapLeft`/`CapRight` (and the hole masks) picked with
  `SetTexCoord`; Forever's `SimpleMaskTextureAPIDocumentation.lua` lists no
  functions of its own, so a mask's texture coordinates aren't documented to
  apply, and in game the masks behaved as if they used the whole cap. Every
  corner is now a whole 64×64 texture (`Mode/CornerTopLeft` … and
  `Mode/CornerHole*`, built by `tools/build_shape_textures.lua`), so no mask
  needs texture coordinates. This affects every `Kit.ModeBoxBorder` (chat,
  damage meters, bags, Cooldown Manager, party frames).
- **Tracked Buffs.** `candidateFilters.includeSpellIDs` / `excludeSpellIDs`
  (maps of spell ID → true; `ValidateCandidateFilters`). The game applies spell
  matching to helpful auras on group members
  (`AuraContainerUtil.CanApplyIdentityCandidateFilters`: "Filtering helpful
  spells on the active player / any group members … is always allowed").
  `SetAuraGroupCandidateFilters(groupKey, filters)` updates a group in place.
  The + picker lists the buffs on you and your party from
  `C_UnitAuras.GetUnitAuras(unit, "HELPFUL")` with public `spellId`s (out of
  combat), and checks typed IDs with `C_Spell.GetSpellName`
  (`Domain.Cooldowns.SpellName`).
- **Dispellable by You.** `HARMFUL|RAID` (debuffs the player can dispel) first
  in the debuff row; the type groups default to `HARMFUL|!RAID` so a debuff
  shows once. Both are documented `AuraUtil.AuraFilters` components.

## Minimap — November 14, 2026

Checked against the `forever` branch of Gethe/wow-ui-source and the local
12.1.5 mainline copy. Forever loads `Blizzard_Minimap` as the `camelot` game
type: the mainline `Minimap.lua`/`Minimap.xml` plus Camelot overrides
(`Camelot/Minimap.lua`, tracking, mail, calendar, addon compartment, and
`Diel.lua`, the day and night ring). [Details](MINIMAP.md).

- **Minimap widget.** `SetMaskTexture(asset)`, `SetZoom`/`GetZoom`,
  `PingLocation(x, y)` and the `SetArchBlobRing*`, `SetQuestBlobRing*` and
  `SetTaskBlobRing*` scalar/alpha setters are documented
  (`MinimapFrameAPIDocumentation.lua`), all `SecretArguments =
  "AllowedWhenUntainted"`; ModeUI passes plain values. `SetBlipTexture`,
  `SetPlayerTexture` and the POI arrow setters aren't documented on Forever
  and aren't used. No minimap frame is protected (no `protected="true"` and
  no secure templates in `Blizzard_Minimap`); size and position changes
  still go through `Defer`.
- **Blizzard's round mask.** `MinimapClusterMixin:UpdateMinimapConfig`
  (`Camelot/Minimap.lua`) calls `Minimap:SetMaskTexture("ui-hud-minimap-frame-generic-mask")`
  at load and from the `rotateMinimap` CVar callback; ModeUI post-hooks it
  (`hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", ...)`) and sets its
  mask again. ModeUI never writes the CVar.
- **Square map, rectangular mask.** The engine draws the minimap square
  (every rectangular-minimap addon keeps it square and crops with the mask
  and `SetHitRectInsets`); whether a non-square `SetSize` stretches the map
  isn't documented and isn't relied on.
- **Hybrid minimap.** `Blizzard_HybridMinimap` (load on demand) masks its
  `MapCanvas` with its own `CircleMask` (`TempPortraitAlphaMask`, inset 3
  px); ModeUI swaps the texture with `SetUseMaskTexture(false)` /
  `CircleMask:SetTexture` / `SetUseMaskTexture(true)` on `ADDON_LOADED`.
- **Pings.** `MinimapMixin:OnClick` (`OnMouseUp`) pings only inside
  `sqrt(x² + y²) < width / 2`; ModeUI's `HookScript("OnMouseUp")` pings
  outside that circle.
- **Frames moved.** `MinimapCluster.Tracking`, `MinimapCluster.IndicatorFrame`
  (with `MailFrame`), `GameTimeFrame`, `ExpansionLandingPageMinimapButton`
  (inside `MinimapBackdrop`), `AddonCompartmentFrame` and `QueueStatusButton`
  (`EditModeGroupFinderSystemTemplate`, parented to UIParent; Camelot's
  `QueueStatusButtonMixin:UpdateDefaultAnchor` anchors it to the minimap)
  are reparented and re-placed after Blizzard's `SetPoint`, `SetParent` and
  `SetScale` (post-hooks). `MinimapCluster` is hidden; `MinimapBackdrop`,
  `Minimap.ZoomIn`, `ZoomOut` and `ZoomHitArea` wait under a hidden frame.
  There is no instance-difficulty frame on Forever
  (`Camelot/MinimapInstanceDifficulty.lua`) and no `MinimapCluster.BorderTop`.
- **Zone and position.** `GetMinimapZoneText()` (to `SetText` only),
  `C_PvP.GetZonePVPInfo()` (no global `GetZonePVPInfo` on Forever),
  `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition`
  (both `AllowedWhenUntainted`; nil in many instances), in
  `Domain.Location`. Events: `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`,
  `ZONE_CHANGED_NEW_AREA`, `PLAYER_ENTERING_WORLD`.
- **Mask files.** 32-bit run-length encoded TGAs (type 10), the format
  BasicMinimap ships its `circle.tga` in; white with matching alpha, so the
  mask works whichever channel the client reads. New files need a client
  restart.
