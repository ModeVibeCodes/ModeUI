local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- The header menu, in the Mode look: the meters on the left (grouped Damage,
-- Healing, Actions), the fights on the right (Current, Overall and the
-- earlier fights the game still holds), and Reset All Data. Clicking a
-- window's header (or right-clicking a row) opens it; choosing anything, or
-- clicking anywhere else, closes it.
local Kit, L, T = addon.Kit, addon.L, addon.InterfaceTheme
local DM = addon.Domain.DamageMeter
local ITEM_HEIGHT, COLUMN_WIDTH, PAD, HEADING_HEIGHT, MAX_FIGHTS = 20, 176, 8, 22, 10
local GROUPS = { "Damage", "Healing", "Actions" }

local function MenuFont(text, size, color, px)
    Kit.Font(text, { outline = false, shadow = true, slug = true, textColor = color, font = "game", fontMedia = "Expressway" },
        size, Kit.FontPath({ font = "game", fontMedia = "Expressway" }, M.id), px)
end

function M:Menu()
    if self.menu then return self.menu end
    -- Clicking anywhere outside the menu closes it.
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    catcher:SetScript("OnClick", function() self:CloseMenu() end)
    catcher:Hide()
    local menu = CreateFrame("Frame", nil, catcher)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu.fill = menu:CreateTexture(nil, "BACKGROUND")
    menu.fill:SetTexture(Kit.FLAT)
    menu.rim = Kit.Rim(menu, "BORDER")
    menu.catcher, menu.entries = catcher, {}
    self.menu = menu
    return menu
end

-- A pooled entry: a heading (small uppercase accent text) or a choice.
local function Entry(menu, index)
    local entry = menu.entries[index]
    if entry then return entry end
    entry = CreateFrame("Button", nil, menu)
    entry:RegisterForClicks("LeftButtonUp")
    entry.hover = entry:CreateTexture(nil, "BACKGROUND")
    entry.hover:SetAllPoints(); entry.hover:SetTexture(Kit.FLAT); entry.hover:Hide()
    entry.mark = entry:CreateTexture(nil, "ARTWORK")
    entry.mark:SetTexture(Kit.FLAT)
    entry.text = Kit.Text(entry)
    entry:SetScript("OnEnter", function() if entry.choice then entry.hover:Show() end end)
    entry:SetScript("OnLeave", function() entry.hover:Hide() end)
    entry:SetScript("OnClick", function() if entry.choice then local fn = entry.choice; M:CloseMenu(); fn() end end)
    menu.entries[index] = entry
    return entry
end

-- The menu's entries for a window: { column, heading | label, selected, choice }.
function M:MenuItems(window)
    local style, items = self.db[window], {}
    for _, group in ipairs(GROUPS) do
        items[#items + 1] = { column = 1, heading = L[group] }
        for _, info in ipairs(DM.types) do
            if info.group == group then
                items[#items + 1] = { column = 1, label = L[info.label], selected = style.meterType == info.id,
                    choice = function() self:SetOption(window, "meterType", info.id) end }
            end
        end
    end
    local session = self:SessionOf(window)
    items[#items + 1] = { column = 2, heading = L["Fight"] }
    items[#items + 1] = { column = 2, label = L["Current Fight"], selected = session == "current", choice = function() self:SetSession(window, "current") end }
    items[#items + 1] = { column = 2, label = L["Overall"], selected = session == "overall", choice = function() self:SetSession(window, "overall") end }
    local fights = DM.Sessions()
    for i = #fights, math.max(1, #fights - MAX_FIGHTS + 1), -1 do
        local fight = fights[i]
        local label = fight.name or string.format(L["Fight %d"], fight.id)
        if fight.duration then label = label .. "  " .. DM.Clock(fight.duration) end
        items[#items + 1] = { column = 2, label = label, selected = session == fight.id, choice = function() self:SetSession(window, fight.id) end }
    end
    items[#items + 1] = { column = 2, heading = L["Data"] }
    items[#items + 1] = { column = 2, label = L["Reset All Data"], danger = true, choice = function() self:ResetData() end }
    return items
end

function M:OpenMenu(window, anchor)
    local menu = self:Menu()
    menu.window = window
    local px = Kit.PixelSize(menu)
    local heights = { PAD, PAD }
    local items = self:MenuItems(window)
    for index, item in ipairs(items) do
        local entry = Entry(menu, index)
        local column, height = item.column, item.heading and HEADING_HEIGHT or ITEM_HEIGHT
        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD + (column - 1) * (COLUMN_WIDTH + PAD), -heights[column])
        entry:SetSize(COLUMN_WIDTH, height)
        heights[column] = heights[column] + height
        entry.choice = item.choice
        entry:EnableMouse(item.choice ~= nil)
        local color = item.heading and T.primary or item.selected and T.primary or item.danger and T.danger or T.text
        MenuFont(entry.text, item.heading and T.fontSize.group or 12, color, px)
        entry.text:SetText(item.heading and item.heading:upper() or item.label)
        entry.text:ClearAllPoints()
        entry.text:SetPoint(item.heading and "BOTTOMLEFT" or "LEFT", entry, item.heading and "BOTTOMLEFT" or "LEFT", item.heading and 4 or 12, item.heading and 4 or 0)
        Kit.Tint(entry.hover, T.hover, 1)
        entry.mark:ClearAllPoints()
        entry.mark:SetPoint("TOPLEFT", entry, "TOPLEFT", 0, -4 * px); entry.mark:SetPoint("BOTTOMLEFT", entry, "BOTTOMLEFT", 0, 4 * px)
        entry.mark:SetWidth(2 * px); Kit.Tint(entry.mark, T.primary, 1)
        entry.mark:SetShown(item.selected == true)
        entry:Show()
    end
    for index = #items + 1, #menu.entries do menu.entries[index]:Hide() end
    menu:SetSize(2 * COLUMN_WIDTH + 3 * PAD, math.max(heights[1], heights[2]) + PAD)
    Kit.Inset(menu.fill, menu, px); Kit.Tint(menu.fill, T.card, 0.98)
    Kit.PlaceRim(menu.rim, menu, px, px, T.cardBorder)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu.catcher:Show()
end

function M:ToggleMenu(window, anchor)
    if self.menu and self.menu.catcher:IsShown() and self.menu.window == window then self:CloseMenu(); return end
    self:OpenMenu(window, anchor)
end

function M:CloseMenu()
    if self.menu then self.menu.catcher:Hide() end
end
