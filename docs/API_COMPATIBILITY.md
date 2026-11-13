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
pcall-guarded and falls back to percent. Secure unit buttons are created,
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
- **Blizzard's window is left alone.** It is an Edit Mode system frame
  (`EditModeDamageMeterSystemTemplate`). A third-party author (LittleThings)
  reported that writing into its session windows taints their refresh. ModeUI
  neither reparents, hides nor calls into it. Its own Edit Mode Visibility
  setting can hide it.
- **Death Recap.** `OpenDeathRecapUI(deathRecapID)` is what Blizzard's window
  calls. ModeUI calls it only out of combat, guarded.
- **Unverified natively:** whether the game records with its option off,
  which meter types return data on Forever (one author reports Avoidable Damage
  Taken is unavailable there; the window then says "No avoidable damage
  taken."), and the exact client behavior of `AbbreviateNumbers` text.

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
