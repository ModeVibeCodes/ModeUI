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
- **Not used.** `SetShown` and `SetTimerDuration` reject secret arguments from
  addon code (`AllowedWhenUntainted`). Blizzard notes that tainted callers must
  use `SetAlphaFromBoolean` instead (`Blizzard_UnitFrame/Shared/UnitFrameUtil.lua`).
  Its alpha range (`SingleColorValue`, default 255) is undocumented, so ModeUI
  avoids it.
