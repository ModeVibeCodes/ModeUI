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
