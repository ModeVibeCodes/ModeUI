local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- How buttons react: proc glows and cooldown states.
--
-- Procs: Blizzard shows a spell alert on a button when its spell lights up
-- (ActionButtonSpellAlertManager:ShowAlert/HideAlert). Proc Glow picks the
-- look: Mode Glow (a soft glow around the button), Border (a colored frame on
-- it), Blizzard (the game's own animation) or None. ModeUI hooks the manager
-- and fades Blizzard's alert frame when it draws its own.
--
-- Cooldowns: on SPELL_UPDATE_COOLDOWN, C_ActionBar.GetActionCooldown tells
-- whether each action is on a cooldown; its isActive and isOnGCD fields are
-- never secret, so the global cooldown can be told apart in combat. When a
-- real cooldown ends, Glow When Ready lights the button for Glow Time
-- seconds; Icon Opacity fades the icon while the cooldown runs.
local Kit, Public = addon.Kit, addon.IsPublic
local OUTSET = 7 -- how far the soft glow reaches past the button
M.glows = setmetatable({}, { __mode = "k" })
M.procs = setmetatable({}, { __mode = "k" })
M.cooling = setmetatable({}, { __mode = "k" })

-- One glow (kind "proc" or "ready") on a button: a soft glow texture and a
-- border of four edges; the style picks which shows.
local function Build(button)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button)
    frame.soft = frame:CreateTexture(nil, "OVERLAY")
    frame.edges = {}
    for i = 1, 4 do frame.edges[i] = frame:CreateTexture(nil, "OVERLAY", nil, 1) end
    if frame.CreateAnimationGroup then
        local pulse = frame:CreateAnimationGroup()
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1); fade:SetToAlpha(0.35); fade:SetDuration(0.6)
        pulse:SetLooping("BOUNCE")
        frame.pulse = pulse
    end
    frame:Hide()
    return frame
end

function M:Glow(button, kind)
    local set = self.glows[button] or {}
    self.glows[button] = set
    set[kind] = set[kind] or Build(button)
    return set[kind]
end

local function Paint(frame, button, style, color, pulse)
    local state = M.skinState[button]
    local px = state and state.g.px or 1
    frame:SetFrameLevel(button:GetFrameLevel() + 6)
    local soft = style == "glow" or style == "mode"
    frame.isSoft = soft
    frame.soft:SetShown(soft)
    if soft then
        frame.soft:ClearAllPoints()
        frame.soft:SetPoint("TOPLEFT", button, "TOPLEFT", -OUTSET, OUTSET)
        frame.soft:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", OUTSET, -OUTSET)
        if not addon.Media:ApplyTexture(frame.soft, "NameplateGlow") then frame.soft:SetTexture(Kit.FLAT) end
        Kit.Tint(frame.soft, color, 0.9)
    end
    local t = 2 * px
    local top, bottom, left, right = frame.edges[1], frame.edges[2], frame.edges[3], frame.edges[4]
    local function Edge(edge, a, x1, y1, b, x2, y2)
        edge:ClearAllPoints(); edge:SetPoint("TOPLEFT", button, a, x1, y1); edge:SetPoint("BOTTOMRIGHT", button, b, x2, y2)
        edge:SetTexture(Kit.FLAT); Kit.Tint(edge, color, 1); edge:SetShown(not soft)
    end
    Edge(top, "TOPLEFT", 0, 0, "TOPRIGHT", 0, -t); Edge(bottom, "BOTTOMLEFT", 0, t, "BOTTOMRIGHT", 0, 0)
    Edge(left, "TOPLEFT", 0, -t, "BOTTOMLEFT", t, t); Edge(right, "TOPRIGHT", -t, -t, "BOTTOMRIGHT", 0, t)
    if frame.pulse then
        if pulse and not frame.pulse:IsPlaying() then frame.pulse:Play() elseif not pulse then frame.pulse:Stop(); frame:SetAlpha(1) end
    end
end

M.PaintGlow = Paint

-- One glow at a time: when a button wants both its proc glow and its ready
-- glow, a soft glow wins over a border one; two of a kind, the proc glow wins.
-- Each glow keeps whether it's wanted, so the other comes back when one ends.
function M:ResolveGlows(button)
    local set = self.glows[button]
    if not set then return end
    local proc, ready = set.proc, set.ready
    local p, r = proc ~= nil and proc.wanted == true, ready ~= nil and ready.wanted == true
    -- Blizzard's own proc animation counts as a soft proc glow.
    if set.blizzard then p = true end
    local readyWins = p and r and ready.isSoft and not (set.blizzard or proc.isSoft)
    if proc then proc:SetShown(proc.wanted == true and not readyWins) end
    if ready then ready:SetShown(r and (not p or readyWins)) end
end

-- Whether a glow kind ("proc" or "ready") is on for the button at `index`
-- (per-button switches, set from the preview's glow menu).
function M.GlowOn(style, index, kind)
    local glows = index and style.buttonGlows[tostring(index)]
    return not (glows and glows[kind] == false)
end

-- Procs ------------------------------------------------------------------

function M:ApplyProc(button)
    local bar = self.barOf[button]
    if not bar then return end
    local style = self.db[bar]
    local allowed = self.GlowOn(style, self.indexOf[button], "proc")
    local on = self.active == true and self.procs[button] == true and allowed
    local alert = button.SpellActivationAlert
    -- Blizzard's alert shows for its own style, and whenever ModeUI is off.
    if alert and alert.SetAlpha then alert:SetAlpha((not self.active or (style.procGlow == "blizzard" and allowed)) and 1 or 0) end
    local own = on and (style.procGlow == "mode" or style.procGlow == "border")
    local blizzard = on and style.procGlow == "blizzard"
    if blizzard or self.glows[button] then
        self.glows[button] = self.glows[button] or {}
        self.glows[button].blizzard = blizzard
    end
    local glow = (own or (self.glows[button] and self.glows[button].proc)) and self:Glow(button, "proc")
    if not glow then self:ResolveGlows(button); return end
    if own then Paint(glow, button, style.procGlow, style.procColor, style.procPulse) end
    glow.wanted = own
    self:ResolveGlows(button)
end

function M:HookProcs()
    local manager = _G.ActionButtonSpellAlertManager
    if self.procsHooked or type(manager) ~= "table" or not hooksecurefunc then return end
    self.procsHooked = true
    if type(manager.ShowAlert) == "function" then
        hooksecurefunc(manager, "ShowAlert", function(_, button) if M.barOf[button] then M.procs[button] = true; M:ApplyProc(button) end end)
    end
    if type(manager.HideAlert) == "function" then
        hooksecurefunc(manager, "HideAlert", function(_, button) if M.barOf[button] then M.procs[button] = nil; M:ApplyProc(button) end end)
    end
end

-- Cooldowns --------------------------------------------------------------

local function Cooling(action)
    local api = C_ActionBar and C_ActionBar.GetActionCooldown
    if type(api) ~= "function" then return false end
    local ok, info = pcall(api, action)
    return ok and type(info) == "table" and info.isActive == true and info.isOnGCD ~= true
end

function M:FlashReady(button, style)
    local glow = self:Glow(button, "ready")
    Paint(glow, button, style.readyStyle, style.readyColor, true)
    glow.token = (glow.token or 0) + 1
    local token = glow.token
    glow.wanted = true
    self:ResolveGlows(button)
    C_Timer.After(style.readyDuration, function()
        if glow.token == token then glow.wanted = false; M:ResolveGlows(button) end
    end)
end

-- Desaturate Icon: the icon is gray while a real cooldown runs. Blizzard
-- clears desaturation when a button's action changes; a hook puts it back
-- while the cooldown still runs. Only ModeUI's own desaturation is undone,
-- so Blizzard's (a level-locked action) stays.
local guard = false
local function KeepGray(icon, value)
    if guard or value ~= false then return end
    local state = M.cooling[M.iconOf[icon]]
    if state and state.gray then guard = true; icon:SetDesaturated(true); guard = false end
end
local function Gray(button, state, on)
    local icon = button.icon
    if not icon or not icon.SetDesaturated or state.gray == on then return end
    if not M.iconOf[icon] then
        M.iconOf[icon] = button
        if hooksecurefunc then hooksecurefunc(icon, "SetDesaturated", KeepGray) end
    end
    state.gray = on
    guard = true; icon:SetDesaturated(on); guard = false
end
M.iconOf = setmetatable({}, { __mode = "k" })

-- Checks every action button on bars 1-8: a real cooldown ending lights the
-- ready glow; Icon Opacity and Desaturate Icon follow whether one runs.
function M:UpdateCooldowns()
    if not self.active then return end
    for bar in pairs(self.pages) do
        local style = self.db[bar]
        for index, button in pairs(self.buttons[bar] or {}) do
            local action = button.action
            if Public(action) and type(action) == "number" then
                local cooling, state = Cooling(action), self.cooling[button]
                if state and state.action == action and state.on and not cooling and style.readyGlow
                    and self.GlowOn(style, index, "ready") then self:FlashReady(button, style) end
                state = state or {}
                state.action, state.on = action, cooling
                self.cooling[button] = state
                if button.icon then button.icon:SetAlpha(cooling and style.cooldownOpacity / 100 or 1) end
                Gray(button, state, cooling and style.cooldownDesaturate and self.GlowOn(style, index, "gray"))
            end
        end
    end
end

-- After a settings change: every glow and icon in step with the settings.
function M:RefreshGlows()
    for button in pairs(self.barOf) do self:ApplyProc(button) end
    if self.active then self:UpdateCooldowns(); return end
    -- Switched off: no ready glows, and full, colored icons.
    for button, set in pairs(self.glows) do
        if set.ready then set.ready.wanted = false; self:ResolveGlows(button) end
    end
    for button, state in pairs(self.cooling) do
        if button.icon then button.icon:SetAlpha(1) end
        Gray(button, state, false)
        self.cooling[button] = nil
    end
end
