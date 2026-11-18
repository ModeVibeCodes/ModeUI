local _, addon = ...
local Kit = addon.Kit

-- Blizzard's own frames that a ModeUI frame replaces: faded, never hidden,
-- reparented or unregistered, so they keep running. Moved here from Unit
-- Frames (November 18, 2026) so more than one module can fade the same frame:
-- Unit Frames and ModeCDM's Cast Bar both hide Blizzard's Player cast bar. A
-- region stays faded while any owner holds it. Native frames are protected,
-- so owners sync outside combat.
local Number = addon.IsNumber
local Fade = { holders = {}, alpha = {}, hooked = {}, anims = {} }
Kit.NativeFade = Fade

-- An Alpha animation's from and to alpha replace a region's own alpha while it
-- plays, so the SetAlpha(0) fade can't hide it. Blizzard's cast bars play one
-- on every interrupt (CastingBarFrameAnimsTemplate HoldFadeOutAnim: alpha 1
-- for 1s, then a fade), which showed a faded cast bar. While a region is
-- faded, the Alpha animations that act on the region itself run from 0 to 0;
-- they still play and finish (the cast bar hides itself when its animation
-- ends), unseen. Animations on its children need nothing: a child never shows
-- through a parent at alpha 0.
local function MuteAnimations(region, muted)
    if not muted then
        for _, entry in ipairs(Fade.anims[region] or {}) do
            entry.anim:SetFromAlpha(entry.from); entry.anim:SetToAlpha(entry.to)
        end
        Fade.anims[region] = nil
        return
    end
    if Fade.anims[region] or not region.GetAnimationGroups then return end
    local entries = {}
    for _, group in ipairs({ region:GetAnimationGroups() }) do
        for _, anim in ipairs({ group:GetAnimations() }) do
            if anim:GetObjectType() == "Alpha" and anim:GetTarget() == region then
                local from, to = anim:GetFromAlpha(), anim:GetToAlpha()
                if Number(from, 0, 1) and Number(to, 0, 1) then
                    entries[#entries + 1] = { anim = anim, from = from, to = to }
                    anim:SetFromAlpha(0); anim:SetToAlpha(0)
                end
            end
        end
    end
    Fade.anims[region] = entries
end

local function Apply(region, hidden)
    MuteAnimations(region, hidden)
    if hidden then
        local alpha = region:GetAlpha()
        if Fade.alpha[region] == nil then Fade.alpha[region] = Number(alpha, 0, 1) and alpha or 1 end
        if not Fade.hooked[region] and hooksecurefunc then
            Fade.hooked[region] = true
            -- Blizzard may restore alpha later; keep the region faded while held.
            hooksecurefunc(region, "SetAlpha", function(r)
                if Fade.holders[r] and not Fade.busy then
                    Fade.busy = true; r:SetAlpha(0); Fade.busy = false
                end
            end)
        end
        Fade.busy = true; region:SetAlpha(0); Fade.busy = false
    else
        region:SetAlpha(Fade.alpha[region] or 1); Fade.alpha[region] = nil
    end
end

-- Whether a value is a region that can be faded.
function Fade.Fadable(region) return type(region) == "table" and region.SetAlpha ~= nil and region.GetAlpha ~= nil end

-- What `owner` (a module id) hides now: a set { [region] = true }. Regions it
-- held before and no longer lists are let go; each fades back in once no
-- owner holds it.
function Fade:Sync(owner, regions)
    for region, holders in pairs(self.holders) do
        if holders[owner] and not regions[region] then
            holders[owner] = nil
            if next(holders) == nil then self.holders[region] = nil; Apply(region, false) end
        end
    end
    for region in pairs(regions) do
        local holders = self.holders[region]
        if not holders then
            holders = {}
            self.holders[region] = holders
            Apply(region, true)
        end
        holders[owner] = true
    end
end

function Fade:IsHeld(region, owner)
    local holders = self.holders[region]
    if owner then return holders ~= nil and holders[owner] == true end
    return holders ~= nil
end

-- The player's cast bar: a module that draws it on its own claims it
-- (ModeCDM's Cast Bar); Unit Frames' Player cast bar steps aside while
-- another module holds the claim. Claims are announced with
-- Messages.PLAYER_CAST_CLAIMED.
local claims = {}
Kit.PlayerCast = {}
function Kit.PlayerCast.Claim(owner, on)
    on = on and true or nil
    if claims[owner] == on then return end
    claims[owner] = on
    addon:SendMessage(addon.Messages.PLAYER_CAST_CLAIMED)
end
-- The module drawing the player's cast bar now, other than `except`, or nil.
function Kit.PlayerCast.ClaimedBy(except)
    for owner in pairs(claims) do if owner ~= except then return owner end end
end
