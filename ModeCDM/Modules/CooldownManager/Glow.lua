local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- How icons react. Every glow starts off on every spell; a spell's menu
-- switches one on, with its own look: style (Mode Glow, Border, Pixel,
-- Blizzard, GCD), color, pulse, and for Pixel its lines and thickness
-- (M:SpellGlow).
--   Proc     the game lights the spell up. On Blizzard's icons that's its
--            spell alert (ActionButtonSpellAlertManager:ShowAlert/HideAlert,
--            hooked as on the action bars), which ModeUI hides while it's on;
--            on custom spells the overlay glow events (Spells.lua).
--   Active   the spell's effect is up: Blizzard swaps the icon's swipe to its
--            gold aura color (compared by reference, never secret).
--   Off Cooldown  on SPELL_UPDATE_COOLDOWN, C_Spell.GetSpellCooldown tells
--            whether a spell is on a real cooldown (isActive and isOnGCD are
--            never secret). Flash lights the icon for its Glow Time when one
--            ends; While Ready keeps it lit while the spell is ready.
--   Buff     a tracked buff is up. Blizzard keeps that as the item's active
--            state, which can be secret in combat, so the glow's textures
--            take it through SetAlphaFromBoolean (allowed with secrets).
-- On a cooldown icon one glow shows at a time: proc, then active, then off
-- cooldown.
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

-- Paints a glow from a look ({ style, color, pulse, lines, thickness }), at
-- the item's own size (never measured). Border is the Mode rim swap
-- (docs/DESIGN_LANGUAGE.md, "Cooldown icons"): a Mode Empty rim in the glow
-- color laid exactly over the icon's `frameThin` edge, so the icon keeps its
-- size. It lives on the glow's frame, so it shows, hides, pulses and takes a
-- buff's (possibly secret) active state with the glow.
local function Paint(item, frame, look)
    local state = M.dress[item]
    local g = state and state.g
    local border = look.style == "border"
    Kit.PaintSlotGlow(frame, item, border and "none" or look.style, look.color, look.pulse and not border, g and g.px or 1,
        { width = g and g.w, height = g and g.h, lines = look.lines, thickness = look.thickness })
    if border and not frame.ring then
        frame.ring = addon.Style.Edge(frame, "empty", { rim = 1, level = 1 })
        for _, region in ipairs(frame.ring:Regions()) do frame.parts[#frame.parts + 1] = region end
    end
    if frame.ring then
        frame.ring:SetShown(border)
        if border then frame.ring:Layout(); frame.ring:SetTint(look.color) end
    end
    if border and look.pulse and frame.pulse and not frame.pulse:IsPlaying() then frame.pulse:Play() end
end
M.PaintGlow = Paint

-- Wants (look) or not (nil) one kind of glow on an item.
function M:WantGlow(item, kind, look)
    local set = self.glows[item]
    if not look and not (set and set[kind]) then return end
    local glow = self:Glow(item, kind)
    if look then Paint(item, glow, look) end
    glow.wanted = look ~= nil
end

-- Proc, then active, then off cooldown.
function M:ResolveGlows(item)
    local set = self.glows[item]
    if not set then return end
    local winner
    for _, kind in ipairs(ORDER) do
        local glow = set[kind]
        if not winner and glow and glow.wanted then winner = kind end
    end
    for _, kind in ipairs(ORDER) do if set[kind] then set[kind]:SetShown(winner == kind) end end
end

-- Every glow on one item, from its spell's glows and its state now.
function M:ApplyGlows(item)
    local owner = self:Owner(item)
    local style = owner and self.db[owner]
    if not style or self:IsBar(owner) then return end
    local key, on, buff = self:SpellKey(item), self.active == true, self:IsBuff(owner)
    local function Look(kind) return on and self:SpellGlow(owner, key, kind) or nil end
    -- Blizzard's own alert hides while ModeUI is on: ModeUI draws the procs.
    local alert = item.SpellActivationAlert
    if alert and alert.SetAlpha then alert:SetAlpha(on and 0 or 1) end
    local proc = not buff and self.procs[item] == true and Look("proc") or nil
    self:WantGlow(item, "proc", proc)
    self:WantGlow(item, "active", not buff and self.AuraUp(item) and Look("active") or nil)
    local ready, cooling = not buff and Look("ready") or nil, self.cooling[item]
    if ready and not ((ready.mode == "always" and cooling ~= nil and cooling.on == false)
        or (ready.mode == "flash" and self.flashing[item] ~= nil)) then ready = nil end
    self:WantGlow(item, "ready", ready)
    self:ResolveGlows(item)
    self:ApplyBuffGlow(item, buff and Look("buff") or nil)
end

-- The buff glow: shown while the buff's glow is on, its textures as opaque
-- as the buff is up (the item's active state, passed to the client as it is).
function M:ApplyBuffGlow(item, look)
    local set = self.glows[item]
    if not look then
        if set and set.buff then set.buff:Hide() end
        return
    end
    local glow = self:Glow(item, "buff")
    Paint(item, glow, look)
    glow:Show()
    local up = item.isActive
    for _, region in ipairs(glow.parts) do
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

-- Checks every cooldown icon (Blizzard's, and custom spells' own): a real
-- cooldown ending flashes, the gray and the While Ready glow follow whether
-- one runs.
function M:UpdateCooldowns()
    if not self.active then return end
    local items = {}
    for _, viewer in ipairs({ "essential", "utility" }) do
        for _, item in ipairs(self:Items(viewer)) do items[#items + 1] = item end
    end
    for _, icons in pairs(self.spellIcons) do for _, icon in pairs(icons) do items[#items + 1] = icon end end
    for _, item in ipairs(items) do
        local owner = self:Owner(item)
        local style = owner and self.db[owner]
        local id = style and self:SpellKey(item)
        local cooling = id and self:EntryCooling(id)
        local state = self.cooling[item]
        local ended = state and state.id == id and state.on == true and cooling == false
        state = state or {}
        state.id, state.on = id, cooling
        self.cooling[item] = state
        self:WatchCooling(item, cooling == true)
        if style then
            local ready = ended and self:SpellGlow(owner, id, "ready")
            if ready and ready.mode == "flash" then self:FlashReady(item, ready.duration)
            else self:ApplyGlows(item) end
            if self:IsOwnIcon(item) then self:UpdateSpellIcon(item) else self:StyleDesaturation(item, style) end
        end
    end
end

-- Cooldowns running out. The game sends no event when one ends, and
-- Blizzard's own refresh at that moment (its cooldown frame's
-- OnCooldownDone, timed by itself) can still find the spell cooling in
-- C_Spell.GetSpellCooldown, which would leave the icon gray and the
-- off-cooldown glow unlit. So each icon on a real cooldown is watched: a
-- shared ticker asks again every WATCH_EVERY seconds, only while one is
-- watched, and brings every icon up to date once one has ended.
local WATCH_EVERY = 0.2
M.watching = setmetatable({}, { __mode = "k" })
function M:WatchCooling(item, on)
    if not on then self.watching[item] = nil; return end
    self.watching[item] = true
    local ticker = self.coolingTicker
    if ticker and ticker:IsShown() then return end
    if not ticker then
        ticker = CreateFrame("Frame")
        ticker.elapsed = 0
        ticker:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = frame.elapsed + (elapsed or 0)
            if frame.elapsed < WATCH_EVERY then return end
            frame.elapsed = 0
            M.Safe(function() M:CheckCooling() end)
        end)
        self.coolingTicker = ticker
    end
    ticker.elapsed = 0
    ticker:Show()
end

-- One tick: stops with nothing to watch (or the module off); otherwise any
-- watched icon whose cooldown ended (or that shows another spell now)
-- brings every icon up to date, which watches those still cooling again.
function M:CheckCooling()
    if not self.active or next(self.watching) == nil then
        for item in pairs(self.watching) do self.watching[item] = nil end
        self.coolingTicker:Hide()
        return
    end
    for item in pairs(self.watching) do
        local key = self:SpellKey(item)
        local state = self.cooling[item]
        if not key or not state or state.id ~= key or self:EntryCooling(key) ~= true then
            self:UpdateCooldowns()
            return
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
    if self:IsLive(item) then self:ApplyGlows(item) end
end

-- After a settings change: every glow in step with the settings; switched
-- off, no ModeUI glows and Blizzard's alerts back.
function M:RefreshGlows()
    for item in pairs(self.sourceOf) do self:ApplyGlows(item) end
    for item in pairs(self.iconKey) do self:ApplyGlows(item) end
    if self.active then return end
    for item, set in pairs(self.glows) do
        for _, kind in ipairs(ORDER) do if set[kind] then set[kind].wanted = false end end
        self:ResolveGlows(item)
        if set.buff then set.buff:Hide() end
    end
end
