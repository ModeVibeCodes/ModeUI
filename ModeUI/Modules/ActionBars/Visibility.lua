local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- When each bar shows, and how see-through it is. Showing and hiding is done
-- by the game from macro conditions (a state driver), so it keeps working in
-- combat. Opacity is plain alpha, which may change in combat: a bar shown on
-- Mouseover sits at its faded opacity until the mouse is over it (or a spell
-- flyout from it), a spell is being dragged, or Edit Mode or Keybind Mode is
-- on. Hidden keeps a bar off screen except in those two modes.
local Public = addon.IsPublic
local PRESETS = { always = "show", mouseover = "show", hidden = "hide", combat = "[combat] show; hide", noCombat = "[combat] hide; show",
    target = "[combat][@target,exists] show; hide" }
-- Every bar steps aside for pet battles; the pet and stance bars also for
-- vehicles and possession, as Blizzard's own do.
local PET_BATTLE = "[petbattle] hide; "
local CONTROLLED = "[vehicleui][overridebar][possessbar] hide; "
local TICK = 0.1

-- Custom conditions the game can't read fall back to always showing.
function M.ParseConditions(text)
    if type(SecureCmdOptionParse) ~= "function" then return true end
    local ok = pcall(SecureCmdOptionParse, text)
    return ok
end

function M:Conditions(bar, count)
    local style, spec = self.db[bar], self.barSpecs[bar]
    if not style.show or (count or 1) < 1 then return "hide" end
    -- Edit Mode and Keybind Mode show every bar that's switched on.
    if self.editing or self.binding then return "show" end
    local rule = PRESETS[style.visibility]
    if style.visibility == "custom" then
        rule = self.ParseConditions(style.customVisibility) and style.customVisibility or "show"
    end
    local prefix = PET_BATTLE
    if spec.pet then prefix = prefix .. CONTROLLED .. "[nopet] hide; "
    elseif spec.stance then prefix = prefix .. CONTROLLED end
    return prefix .. rule
end

local function Over(frame)
    if not frame or not frame.IsMouseOver or not frame:IsShown() then return false end
    local over = frame:IsMouseOver()
    return Public(over) and over == true
end

function M:FadedAlpha(bar)
    local style, header = self.db[bar], self.headers[bar]
    local full = style.opacity / 100
    if style.visibility ~= "mouseover" or self.gridShown or self.editing or self.binding then return full end
    if Over(header) then return full end
    -- A spell flyout opened from this bar (or from a button ModeUI can't place).
    local flyout = _G.SpellFlyout
    if Over(flyout) then
        local from = flyout.GetParent and self.barOf[flyout:GetParent()]
        if from == nil or from == bar then return full end
    end
    return math.min(style.fadeOpacity, style.opacity) / 100
end

-- Applies every bar's opacity and runs the mouseover check only while a
-- shown bar fades.
function M:UpdateFade()
    local fading = false
    for _, bar in ipairs(self.bars) do
        local header = self.headers[bar]
        if header then
            header:SetAlpha(self:FadedAlpha(bar))
            fading = fading or (self.active and self.db[bar].show and self.db[bar].visibility == "mouseover")
        end
    end
    if fading and not self.fader then
        self.fader = CreateFrame("Frame")
        local elapsed = 0
        self.fader:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < TICK then return end
            elapsed = 0
            for _, bar in ipairs(self.bars) do
                if self.db[bar].visibility == "mouseover" then self.headers[bar]:SetAlpha(self:FadedAlpha(bar)) end
            end
        end)
    end
    if self.fader then self.fader:SetShown(fading and true or false) end
end

-- Dragging a spell brings faded bars back so it can be dropped on them.
function M:SetGridShown(shown)
    self.gridShown = shown
    self:UpdateFade()
end

-- Paging: the state driver for a bar's page, or nil when its buttons follow
-- their Blizzard bar. Action Bar 1 with Page Switching on and no Page
-- Conditions follows the game's own paging (stances, forms, stealth,
-- vehicles, page keys); off, it stays on page 1. Other bars page only with
-- Page Switching on. Conditions end in "none": when none match, a bar shows
-- its own page. Conditions the game can't read leave the bar on its own page.
function M:PageConditions(bar)
    if not self.pages[bar] then return nil end
    local style = self.db[bar]
    if not style.paging then return bar == "bar1" and "1" or nil end
    local text = style.pageConditions:gsub("[%s;]+$", "")
    if text:match("^%s*$") or not self.ParseConditions(text) then return nil end
    return text .. "; none"
end
