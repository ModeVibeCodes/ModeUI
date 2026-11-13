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

## Unit frame cast bars — November 13, 2026

Same cast API use as the nameplates (`UnitCastingInfo`, `UnitChannelInfo`,
duration objects, the `UNIT_SPELLCAST_*` events, unit-filtered). Blizzard's
bars are named in the Forever source: `PlayerCastingBarFrame`
(`Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml`) and
`<frame>SpellBar` from `TargetFrameMixin:CreateSpellbar`
(`Blizzard_UnitFrame/Mainline/TargetFrame.lua`). They are faded with the alpha
hook, never hidden or reparented. The ModeUI cast bar is a plain child of the
secure unit button, shown and hidden in combat. Unverified in game.

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
  and `UpdateAllAuras`. `initializeFrame` builds the Mode icon on each button and
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
