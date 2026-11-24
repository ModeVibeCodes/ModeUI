local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- When each bar shows, and how see-through it is. Blizzard's viewer
-- frames are never shown, hidden or faded by ModeUI (Blizzard does that
-- from its own Edit Mode Visibility and Opacity, which still apply on top);
-- ModeUI fades the icons in them. Show picks when: Always, In Combat, Out
-- of Combat, In Combat or With a Target, Mouseover (Faded Opacity until the
-- mouse is over the viewer) or Hidden. Edit Mode shows every viewer that's
-- on. Show Bar off hides it. The show rules (owner, November 24, 2026) hide
-- a bar while mounted or in a vehicle, or outside a group or an instance;
-- Dim Instead of Hide fades it to Faded Opacity instead (alpha only).
local Public = addon.IsPublic
local TICK = 0.1
M.SHOW_RULE_EVENTS = { "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA" }

-- A game answer that is a public true (nil, false or secret count as no).
local function Yes(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    return ok and Public(value) and value == true
end
local function RuleHides(style)
    if style.hideMounted and Yes(_G.IsMounted) then return true end
    if style.hideVehicle and Yes(_G.UnitInVehicle, "player") then return true end
    if style.onlyInGroup and not Yes(_G.IsInGroup) then return true end
    if style.onlyInInstance and not Yes(_G.IsInInstance) then return true end
    return false
end

local function Over(frame)
    if not frame or not frame.IsMouseOver then return false end
    local over = frame:IsMouseOver()
    return Public(over) and over == true
end

-- The alpha a viewer's icons take now.
function M:ViewerAlpha(viewer) return self:StyleAlpha(self.db[viewer], self.holders and self.holders[viewer]) end

-- The alpha for a bar's settings (a viewer, a custom bar or a resource bar);
-- `hover` is the frame Mouseover watches.
function M:StyleAlpha(style, hover)
    if not self.active then return 1 end
    if not style.show then return 0 end
    local full = style.opacity / 100
    if self.editing then return full end
    local mode = style.visibility
    if mode == "hidden" then return 0 end
    -- What "not now" means: none, or Faded Opacity with Dim Instead of Hide.
    local off = style.dim and math.min(style.fadeOpacity, style.opacity) / 100 or 0
    if RuleHides(style) then return off end
    local combat = addon.InCombat()
    if mode == "combat" then return combat and full or off end
    if mode == "noCombat" then return combat and off or full end
    if mode == "target" then return (combat or addon.Domain.Status.Exists("target")) and full or off end
    if mode == "mouseover" then
        if Over(hover) then return full end
        return math.min(style.fadeOpacity, style.opacity) / 100
    end
    return full
end

-- The items that show on a bar (a viewer or a custom bar).
function M:BarItems(id)
    local list = {}
    for _, viewer in ipairs(self:Sources(id)) do
        for _, item in ipairs(self:Items(viewer)) do if self:Owner(item) == id then list[#list + 1] = item end end
    end
    for _, icon in pairs(self.spellIcons[id] or {}) do list[#list + 1] = icon end
    return list
end

-- Every icon on a bar at its alpha (a spell hidden here stays at none).
function M:UpdateAlpha(id)
    for _, item in ipairs(self:BarItems(id)) do self:ApplySpell(id, item) end
end

-- Applies every viewer's alpha; the mouseover check runs only while a viewer
-- that's on uses Mouseover. Combat and target changes re-apply it.
function M:UpdateFade()
    local fading = false
    for _, id in ipairs(self:BarIds()) do
        self:UpdateAlpha(id)
        fading = fading or (self.active and self.db[id].show and self.db[id].visibility == "mouseover")
    end
    -- Resource bars (ResourceUpdate.lua) fade the same way.
    if self:UpdateResourceAlpha() then fading = true end
    if fading and not self.fader then
        self.fader = CreateFrame("Frame")
        local elapsed, last = 0, {}
        self.fader:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < TICK then return end
            elapsed = 0
            for _, id in ipairs(self:BarIds()) do
                if self.db[id].visibility == "mouseover" then
                    local alpha = self:ViewerAlpha(id)
                    if alpha ~= last[id] then last[id] = alpha; self:UpdateAlpha(id) end
                end
            end
            for _, id in ipairs(self.resources) do
                local style, frame = self.db.resources[id], self.resourceFrames and self.resourceFrames[id]
                if frame and style.visibility == "mouseover" then frame:SetAlpha(self:StyleAlpha(style, frame)) end
            end
        end)
    end
    if self.fader then self.fader:SetShown(fading and true or false) end
end
