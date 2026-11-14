local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- When each bar shows, and how see-through it is. Blizzard's viewer
-- frames are never shown, hidden or faded by ModeUI (Blizzard does that
-- from its own Edit Mode Visibility and Opacity, which still apply on top);
-- ModeUI fades the icons in them. Show picks when: Always, In Combat, Out
-- of Combat, In Combat or With a Target, Mouseover (Faded Opacity until the
-- mouse is over the viewer) or Hidden. Edit Mode shows every viewer that's
-- on. Show Viewer off hides it.
local Public = addon.IsPublic
local TICK = 0.1

local function Over(frame)
    if not frame or not frame.IsMouseOver then return false end
    local over = frame:IsMouseOver()
    return Public(over) and over == true
end

-- The alpha a viewer's icons take now.
function M:ViewerAlpha(viewer)
    local style = self.db[viewer]
    if not self.active then return 1 end
    if not style.show then return 0 end
    local full = style.opacity / 100
    if self.editing then return full end
    local mode = style.visibility
    if mode == "hidden" then return 0 end
    local combat = addon.InCombat()
    if mode == "combat" then return combat and full or 0 end
    if mode == "noCombat" then return combat and 0 or full end
    if mode == "target" then return (combat or addon.Domain.Status.Exists("target")) and full or 0 end
    if mode == "mouseover" then
        if Over(self.holders and self.holders[viewer]) then return full end
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
        end)
    end
    if self.fader then self.fader:SetShown(fading and true or false) end
end
