local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- How icons react, and each spell's own switches.
--
-- Procs: Blizzard shows a spell alert on an Essential or Utility icon when
-- its spell lights up (ActionButtonSpellAlertManager:ShowAlert/HideAlert, as
-- on the action bars). Proc Glow picks the look: Mode Glow, Border,
-- Blizzard (the game's own animation) or None. ModeUI hooks the manager and
-- fades Blizzard's alert while it draws its own.
--
-- Ready: on SPELL_UPDATE_COOLDOWN, C_Spell.GetSpellCooldown tells whether a
-- tracked spell is on a real cooldown (isActive and isOnGCD are never
-- secret). When one ends, Glow When Ready lights its icon for Glow Time.
--
-- Spells: a spell can be hidden in its viewer (the others close up), or have
-- its proc or ready glow switched off.
local Kit, Cooldowns = addon.Kit, addon.Domain.Cooldowns
M.glows = setmetatable({}, { __mode = "k" })
M.procs = setmetatable({}, { __mode = "k" })
M.cooling = setmetatable({}, { __mode = "k" })

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

-- One glow at a time: a soft glow wins over a border one; two of a kind, the
-- proc glow wins. Blizzard's own animation counts as a soft proc glow.
function M:ResolveGlows(item)
    local set = self.glows[item]
    if not set then return end
    local proc, ready = set.proc, set.ready
    local p, r = proc ~= nil and proc.wanted == true, ready ~= nil and ready.wanted == true
    if set.blizzard then p = true end
    local readyWins = p and r and ready.isSoft and not (set.blizzard or (proc and proc.isSoft))
    if proc then proc:SetShown(proc.wanted == true and not readyWins) end
    if ready then ready:SetShown(r and (not p or readyWins)) end
end

-- Procs ------------------------------------------------------------------

function M:ApplyProc(item)
    local viewer = self.viewerOf[item]
    if not viewer or self:IsBar(viewer) then return end
    local style = self.db[viewer]
    local allowed = self:SpellSwitch(viewer, self:SpellKey(item), "proc")
    local on = self.active == true and self.procs[item] == true and allowed
    local alert = item.SpellActivationAlert
    -- Blizzard's alert shows for its own style, and whenever ModeUI is off.
    if alert and alert.SetAlpha then alert:SetAlpha((not self.active or (style.procGlow == "blizzard" and allowed)) and 1 or 0) end
    local own = on and (style.procGlow == "mode" or style.procGlow == "border")
    local set = self.glows[item]
    if set or on then
        set = set or {}
        self.glows[item] = set
        set.blizzard = on and style.procGlow == "blizzard"
    end
    local glow = (own or (set and set.proc)) and self:Glow(item, "proc")
    if glow then
        if own then Paint(item, glow, style.procGlow, style.procColor, style.procPulse) end
        glow.wanted = own
    end
    self:ResolveGlows(item)
end

function M:HookProcs()
    local manager = _G.ActionButtonSpellAlertManager
    if self.procsHooked or type(manager) ~= "table" or not hooksecurefunc then return end
    self.procsHooked = true
    if type(manager.ShowAlert) == "function" then
        hooksecurefunc(manager, "ShowAlert", function(_, item)
            if M.viewerOf[item] then M.Safe(function() M.procs[item] = true; M:ApplyProc(item) end) end
        end)
    end
    if type(manager.HideAlert) == "function" then
        hooksecurefunc(manager, "HideAlert", function(_, item)
            if M.viewerOf[item] then M.Safe(function() M.procs[item] = nil; M:ApplyProc(item) end) end
        end)
    end
end

-- Ready --------------------------------------------------------------------

function M:FlashReady(item, style)
    local glow = self:Glow(item, "ready")
    Paint(item, glow, style.readyStyle, style.readyColor, true)
    glow.token = (glow.token or 0) + 1
    local token = glow.token
    glow.wanted = true
    self:ResolveGlows(item)
    C_Timer.After(style.readyDuration, function()
        if glow.token == token then glow.wanted = false; M:ResolveGlows(item) end
    end)
end

-- Checks every Essential and Utility icon: a real cooldown ending lights
-- the ready glow, where it's on.
function M:UpdateCooldowns()
    if not self.active then return end
    for _, viewer in ipairs(self.viewers) do
        if not self:IsBuff(viewer) then
            local style = self.db[viewer]
            for _, item in ipairs(self:Items(viewer)) do
                local id = Cooldowns.ItemCooldownID(item)
                local cooling = id and Cooldowns.Cooling(Cooldowns.SpellID(id))
                local state = self.cooling[item]
                if state and state.id == id and state.on == true and cooling == false and style.readyGlow
                    and self:SpellSwitch(viewer, self:SpellKey(item), "ready") then self:FlashReady(item, style) end
                state = state or {}
                state.id, state.on = id, cooling
                self.cooling[item] = state
            end
        end
    end
end

-- Spells -------------------------------------------------------------------

-- An item's alpha: its viewer's (Visibility.lua), or nothing while its spell
-- is hidden here. A hidden spell takes no mouse (no tooltip). Switched off,
-- every icon is back at full.
function M:ApplySpell(viewer, item)
    local hidden = self.active and self:SpellSwitch(viewer, self:SpellKey(item), "hide")
    local alpha = hidden and 0 or self:ViewerAlpha(viewer)
    item:SetAlpha(alpha)
    if item.SetMouseMotionEnabled then
        local frame = self:Frame(viewer)
        local tooltips = not frame or frame.tooltipsShown ~= false
        item:SetMouseMotionEnabled(alpha > 0 and tooltips)
    end
    self:ApplyProc(item)
end

-- After a settings change: every glow in step with the settings; switched
-- off, no ModeUI glows and Blizzard's alerts back.
function M:RefreshGlows()
    for item in pairs(self.viewerOf) do self:ApplyProc(item) end
    if self.active then return end
    for item, set in pairs(self.glows) do
        if set.ready then set.ready.wanted = false end
        self:ResolveGlows(item)
    end
end
