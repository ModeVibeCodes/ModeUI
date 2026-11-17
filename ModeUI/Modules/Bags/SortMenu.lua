local _, addon = ...
local M = addon.Bags
if not M then return end

-- The header's Sort dropdown. The Sort button names the view order, with
-- the Mode chevron; a click opens a menu under it: a Mode window (Mode Panel
-- in Graphite panel, the `window` edge inside it), one row per order (Bag
-- Order, Quality, Type, Name), the chosen one in Ivory. Picking a row sets Sort. The menu
-- closes on a pick, on a click anywhere else and when the window closes.
-- Plain frames (nothing protected), so it works in combat too.
local Kit, L, Skin, Style = addon.Kit, addon.L, addon.Skin, addon.Style
local C = Skin.mode
local REACH = Style.EdgeReach("window")

function M:BuildSortMenu()
    local frame = self.frame
    local sort = frame.header.sort
    sort.chevron = sort:CreateTexture(nil, "ARTWORK")
    addon.Media:ApplyTexture(sort.chevron, "ModeChevron")
    local menu = CreateFrame("Frame", "ModeUIBagsSortMenu", frame)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu.parts = Skin.Box(menu, "window", { inset = REACH, level = 10 })
    menu.rows = {}
    -- A click outside the menu and its button closes it (a click on the
    -- button is its own toggle).
    menu:SetScript("OnEvent", function()
        local over = menu:IsMouseOver() or sort:IsMouseOver()
        if not (addon.IsPublic(over) and over) then menu:Hide() end
    end)
    menu:SetScript("OnShow", function() menu:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnHide", function() menu:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:Hide()
    frame.sortMenu = menu
end

-- A row: the order's name, Ivory when chosen or under the mouse, over the
-- chosen tone (Graphite track) under the mouse.
local function Row(menu)
    local row = CreateFrame("Button", nil, menu)
    row:RegisterForClicks("LeftButtonUp")
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    Style.ApplyAsset(row.wash, "Solid")
    row.wash:SetAllPoints()
    row.text = Kit.Text(row)
    function row:Paint()
        local lit = self.hovered or self.chosen
        local c = lit and C.accent or C.text
        self.text:SetTextColor(c[1], c[2], c[3], 1)
        Style.Paint(self.wash, C.chosen, self.hovered and 1 or 0)
    end
    row:SetScript("OnEnter", function() row.hovered = true; row:Paint() end)
    row:SetScript("OnLeave", function() row.hovered = false; row:Paint() end)
    row:SetScript("OnClick", function() M:ChooseSort(row.id) end)
    return row
end

-- The Sort button's chevron and the menu, at the geometry `g`, in the
-- header's font at `size`. Sizes come from the settings, never measured.
function M:PaintSortMenu(g, look, path, size)
    local frame, db = self.frame, self.db
    local sort, menu = frame.header.sort, frame.sortMenu
    local chevron = math.floor(size / g.px + 0.5) * g.px
    sort.chevron:ClearAllPoints(); sort.chevron:SetPoint("RIGHT", sort, "RIGHT", -g.inset, 0)
    sort.chevron:SetSize(chevron, chevron)
    sort.text:ClearAllPoints(); sort.text:SetPoint("RIGHT", sort.chevron, "LEFT", -g.px, 0)
    -- The rows sit inside the edge, clear of its round corners.
    local pad = (REACH + 1) * g.px
    local top, radius = pad, pad
    local height = math.floor(math.max(18, size + 8) / g.px + 0.5) * g.px
    local widest = 0
    for i, item in ipairs(self.choices.sortMode) do
        local row = menu.rows[i] or Row(menu)
        menu.rows[i] = row
        row.id, row.chosen = item.id, item.id == db.sortMode
        Kit.Font(row.text, look, size, path, g.px)
        row.text:SetText(L[item.label])
        row.text:ClearAllPoints(); row.text:SetPoint("LEFT", row, "LEFT", g.inset, 0)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", pad, -(top + (i - 1) * height))
        row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -pad, -(top + (i - 1) * height))
        row:SetHeight(height)
        row:Paint()
        widest = math.max(widest, #L[item.label])
    end
    local width = math.floor((widest * size * 0.55 + 2 * g.inset) / g.px + 0.5) * g.px + 2 * pad
    menu:SetSize(math.max(width, sort:GetWidth(), 2 * radius), 2 * top + #self.choices.sortMode * height)
    Skin.PaintBox(menu.parts, menu, "Panel", C.panel, 1, true)
    menu.parts.modeEdge:SetStyle(db.edgeStyle, db.edgeMetal)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", sort, "BOTTOMRIGHT", 0, -g.px)
end

function M:ToggleSortMenu()
    local menu = self.frame and self.frame.sortMenu
    if not menu then return end
    menu:SetShown(not menu:IsShown())
end

function M:CloseSortMenu()
    local menu = self.frame and self.frame.sortMenu
    if menu then menu:Hide() end
end

-- A row picked: Sort set, menu closed.
function M:ChooseSort(id)
    self:CloseSortMenu()
    return self:SetOption("sortMode", id)
end
