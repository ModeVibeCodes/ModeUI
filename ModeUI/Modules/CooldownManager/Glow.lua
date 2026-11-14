local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- How icons react, and each spell's own switches. Each glow has a style
-- (Mode Glow, Border or None; procs also Blizzard), a color and a pulse.
--   Proc     Blizzard shows a spell alert on a cooldown icon when its spell
--            lights up (ActionButtonSpellAlertManager:ShowAlert/HideAlert,
--            as on the action bars); ModeUI hooks the manager and fades
--            Blizzard's alert while it draws its own.
--   Active   the spell's effect is up: Blizzard swaps the icon's swipe to its
--            gold aura color (compared by reference, never secret).
--   Off Cooldown  on SPELL_UPDATE_COOLDOWN, C_Spell.GetSpellCooldown tells
--            whether a spell is on a real cooldown (isActive and isOnGCD are
--            never secret). Flash lights the icon for Glow Time when one
--            ends; While Ready keeps it lit while the spell is ready.
--   Buff     a tracked buff is up. Blizzard keeps that as the item's active
--            state, which can be secret in combat, so the glow's textures
--            take it through SetAlphaFromBoolean (allowed with secrets).
-- On a cooldown icon one glow shows at a time: proc, then active, then off
-- cooldown. A spell can have each glow switched off, or be hidden.
local Kit, Cooldowns, Public = addon.Kit, addon.Domain.Cooldowns, addon.IsPublic
M.glows = setmetatable({}, { __mode = "k" })
M.procs = setmetatable({}, { __mode = "k" })
M.cooling = setmetatable({}, { __mode = "k" })
M.flashing = setmetatable({}, { __mode = "k" })
local ORDER = { "proc", "active", "ready" }

function M:Glow(item, kind)
    local set = self.glows[item] or {}
    self.glows[item] = set
    set[kind] = set[kind] or Kit.SlotGlow(item)
    return set[kind]
end

local function Paint(item, frame, style, color, pulse)
    local state = M.dress[item]
    Kit.PaintSlotGlow(frame, item, style, color, pulse, state and state.g and state.g.px or 1)
end
M.PaintGlow = Paint

-- Wants (or not) one kind of glow on an item, painted in the bar's style.
function M:WantGlow(item, kind, on, style)
    local set = self.glows[item]
    if not on and not (set and set[kind]) then return end
    local glow = self:Glow(item, kind)
    if on then Paint(item, glow, style[kind .. "Glow"], style[kind .. "Color"], style[kind .. "Pulse"]) end
    glow.wanted = on
end

-- Proc, then active, then off cooldown; Blizzard's own proc animation
-- counts as a proc.
function M:ResolveGlows(item)
    local set = self.glows[item]
    if not set then return end
    local winner = set.blizzard and "blizzard" or nil
    for _, kind in ipairs(ORDER) do
        local glow = set[kind]
        if not winner and glow and glow.wanted then winner = kind end
    end
    for _, kind in ipairs(ORDER) do if set[kind] then set[kind]:SetShown(winner == kind) end end
end

-- Every glow on one item, from its bar's settings and its state now.
function M:ApplyGlows(item)
    local owner = self:Owner(item)
    local style = owner and self.db[owner]
    if not style or self:IsBar(owner) then return end
    local key, on, buff = self:SpellKey(item), self.active == true, self:IsBuff(owner)
    local function Allowed(kind) return on and style[kind .. "Glow"] ~= "none" and self:SpellSwitch(owner, key, kind) end
    -- Proc: Blizzard's alert shows for its own style, and whenever ModeUI is off.
    local proc = not buff and Allowed("proc") and self.procs[item] == true
    local alert = item.SpellActivationAlert
    if alert and alert.SetAlpha then alert:SetAlpha((not on or (proc and style.procGlow == "blizzard")) and 1 or 0) end
    if proc or self.glows[item] then
        local set = self.glows[item] or {}
        self.glows[item] = set
        set.blizzard = proc and style.procGlow == "blizzard"
    end
    self:WantGlow(item, "proc", proc and style.procGlow ~= "blizzard", style)
    self:WantGlow(item, "active", not buff and Allowed("active") and self.AuraUp(item), style)
    local cooling = self.cooling[item]
    local ready = not buff and Allowed("ready") and ((style.readyMode == "always" and cooling ~= nil and cooling.on == false)
        or (style.readyMode == "flash" and self.flashing[item] ~= nil))
    self:WantGlow(item, "ready", ready, style)
    self:ResolveGlows(item)
    self:ApplyBuffGlow(item, buff and Allowed("buff"), style)
end

-- The buff glow: shown while wanted, its textures as opaque as the buff is
-- up (the item's active state, passed to the client as it is).
function M:ApplyBuffGlow(item, wanted, style)
    local set = self.glows[item]
    if not wanted then
        if set and set.buff then set.buff:Hide() end
        return
    end
    local glow = self:Glow(item, "buff")
    Paint(item, glow, style.buffGlow, style.buffColor, style.buffPulse)
    glow:Show()
    local up = item.isActive
    for _, region in ipairs({ glow.soft, unpack(glow.edges) }) do
        if Public(up) then region:SetAlpha(up == true and 1 or 0)
        elseif region.SetAlphaFromBoolean then region:SetAlphaFromBoolean(up) end
    end
end

function M:HookProcs()
    local manager = _G.ActionButtonSpellAlertManager
    if self.procsHooked or type(manager) ~= "table" or not hooksecurefunc then return end
    self.procsHooked = true
    if type(manager.ShowAlert) == "function" then
        hooksecurefunc(manager, "ShowAlert", function(_, item)
            if M.sourceOf[item] then M.Safe(function() M.procs[item] = true; M:ApplyGlows(item) end) end
        end)
    end
    if type(manager.HideAlert) == "function" then
        hooksecurefunc(manager, "HideAlert", function(_, item)
            if M.sourceOf[item] then M.Safe(function() M.procs[item] = nil; M:ApplyGlows(item) end) end
        end)
    end
end

-- Off cooldown: a flash for Glow Time.
function M:FlashReady(item, seconds)
    local token = (self.flashing[item] or 0) + 1
    self.flashing[item] = token
    self:ApplyGlows(item)
    C_Timer.After(seconds, function()
        if M.flashing[item] == token then M.flashing[item] = nil; M:ApplyGlows(item) end
    end)
end

-- Checks every cooldown icon: a real cooldown ending flashes, the gray and
-- the While Ready glow follow whether one runs.
function M:UpdateCooldowns()
    if not self.active then return end
    for _, viewer in ipairs({ "essential", "utility" }) do
        for _, item in ipairs(self:Items(viewer)) do
            local owner = self:Owner(item)
            local style = self.db[owner]
            local id = Cooldowns.ItemCooldownID(item)
            local cooling = id and Cooldowns.Cooling(Cooldowns.SpellID(id))
            local state = self.cooling[item]
            local ended = state and state.id == id and state.on == true and cooling == false
            state = state or {}
            state.id, state.on = id, cooling
            self.cooling[item] = state
            if ended and style.readyGlow ~= "none" and style.readyMode == "flash" then self:FlashReady(item, style.readyDuration)
            else self:ApplyGlows(item) end
            self:StyleDesaturation(item, style)
        end
    end
end

-- An item's alpha: its bar's (Visibility.lua), or nothing while its spell
-- is hidden there. A hidden spell takes no mouse (no tooltip). Switched off,
-- every icon is back at full.
function M:ApplySpell(viewer, item)
    local hidden = self.active and self:SpellSwitch(viewer, self:SpellKey(item), "hide")
    local alpha = hidden and 0 or self:ViewerAlpha(viewer)
    item:SetAlpha(alpha)
    if item.SetMouseMotionEnabled then
        local frame = self:Frame(self.sourceOf[item] or viewer)
        local tooltips = not frame or frame.tooltipsShown ~= false
        item:SetMouseMotionEnabled(alpha > 0 and tooltips)
    end
    if self.sourceOf[item] then self:ApplyGlows(item) end
end

-- After a settings change: every glow in step with the settings; switched
-- off, no ModeUI glows and Blizzard's alerts back.
function M:RefreshGlows()
    for item in pairs(self.sourceOf) do self:ApplyGlows(item) end
    if self.active then return end
    for item, set in pairs(self.glows) do
        for _, kind in ipairs(ORDER) do if set[kind] then set[kind].wanted = false end end
        set.blizzard = nil
        self:ResolveGlows(item)
        if set.buff then set.buff:Hide() end
    end
end
