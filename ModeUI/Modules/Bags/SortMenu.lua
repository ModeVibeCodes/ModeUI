local _, addon = ...
local M = addon.Bags
if not M then return end

-- The header's Sort dropdown. The Sort button names the view order, with
-- the Mode chevron; a click opens a menu under it: a fill in Background
-- Color inside ModeUI's border, one row per order (Bag Order, Quality, Type,
-- Name), the chosen one in the Mode cyan. Picking a row sets Sort. The menu
-- closes on a pick, on a click anywhere else and when the window closes.
-- Plain frames (nothing protected), so it works in combat too.
local Kit, L = addon.Kit, addon.L

function M:BuildSortMenu()
    local frame = self.frame
    local sort = frame.header.sort
    sort.chevron = sort:CreateTexture(nil, "ARTWORK")
    addon.Media:ApplyTexture(sort.chevron, "ModeChevron")
    local menu = CreateFrame("Frame", "ModeUIBagsSortMenu", frame)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu.fill = menu:CreateTexture(nil, "BACKGROUND", nil, -8)
    menu.fill:SetTexture(Kit.FLAT)
    menu.border = Kit.ModeBoxBorder(menu)
    Kit.MaskToBoxBorder(menu.border, { menu.fill })
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

-- A row: the order's name, the Mode cyan when chosen or under the mouse,
-- over a faint cyan wash under the mouse.
local function Row(menu)
    local row = CreateFrame("Button", nil, menu)
    row:RegisterForClicks("LeftButtonUp")
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    row.wash:SetTexture(Kit.FLAT)
    row.wash:SetAllPoints()
    row.text = Kit.Text(row)
    function row:Paint()
        local lit = self.hovered or self.chosen
        local c = lit and Kit.palette.accent or Kit.palette.text
        self.text:SetTextColor(c[1], c[2], c[3], 1)
        Kit.Tint(self.wash, Kit.palette.accent, self.hovered and 0.15 or 0)
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
    local radius = Kit.LayoutModeBoxBorder(menu.border, menu, { px = g.px, radius = math.min(db.corner, 6) * g.px,
        color = db.borderColor, level = menu:GetFrameLevel() + 10 })
    local pad = g.border + g.px
    Kit.Inset(menu.fill, menu, math.max(0, g.border - g.px))
    Kit.Tint(menu.fill, db.backgroundColor, 1)
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
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", pad, -(pad + (i - 1) * height))
        row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -pad, -(pad + (i - 1) * height))
        row:SetHeight(height)
        row:Paint()
        widest = math.max(widest, #L[item.label])
    end
    local width = math.floor((widest * size * 0.55 + 2 * g.inset) / g.px + 0.5) * g.px + 2 * pad
    menu:SetSize(math.max(width, sort:GetWidth(), 2 * radius), 2 * pad + #self.choices.sortMode * height)
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
