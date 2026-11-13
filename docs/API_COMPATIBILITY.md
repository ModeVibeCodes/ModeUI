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
copies outside combat. Native player/target art is faded (alpha only) rather
than reparented, keeping pet, class resource, aura and cast-bar children
working. Runtime secrecy and taint behavior remain unverified in the client.
The Blizzard-style redesign adds `SetPortraitTexture(texture, unit)`
(documented; plain unit tokens), `UnitPowerPercent` with the same curve, and
the documented `UNIT_PORTRAIT_UPDATE`, `UNIT_MODEL_CHANGED` and
`PORTRAITS_UPDATED` events. Class icons use `GetClassAtlas` only when present
and confirmed by `C_Texture.GetAtlasInfo`; it is not confirmed in the Forever
source. [Details](UNIT_FRAMES.md).


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
