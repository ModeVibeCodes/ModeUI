local _, addon = ...
local M = addon.Bags
if not M then return end

-- The window: a fill in Background Color inside ModeUI's border (the rounded
-- rectangle form, Kit.ModeBoxBorder), a header bar in Mode Gradient with the
-- title and the Sort, Clean Up and close buttons over a one-pixel divider,
-- the search box, the slots (Layout.lua) and a footer with the free slots and
-- the money. A plain frame (nothing here is protected), hung from a stand-in
-- that Edit Mode moves. Unlocked, dragging the header moves it (out of
-- combat), saved as Edit Mode would.
local Kit, L, Skin = addon.Kit, addon.L, addon.Skin
local Containers, Number = addon.Domain.Containers, addon.IsNumber
local FLAT = Kit.FLAT

local function Tip(owner, title, line)
    if not (GameTooltip and GameTooltip.SetOwner) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 1, 1)
    if line then GameTooltip:AddLine(line, nil, nil, nil, true) end
    GameTooltip:Show()
end
local function HideTip() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end

-- A header button: a word (Sort, Clean Up) or a glyph (close), in the text
-- color, the Mode cyan under the mouse.
local function HeaderButton(parent, glyph)
    local button = CreateFrame("Button", nil, parent)
    button:RegisterForClicks("LeftButtonUp")
    if glyph then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        addon.Media:ApplyTexture(button.icon, glyph)
    else
        button.text = Kit.Text(button)
        button.text:SetPoint("CENTER")
    end
    function button:Paint()
        local c = self.hovered and Kit.palette.accent or Kit.palette.text
        if self.icon then Kit.Tint(self.icon, c, self.hovered and 1 or 0.8) end
        if self.text then self.text:SetTextColor(c[1], c[2], c[3], 1) end
        if self.chevron then Kit.Tint(self.chevron, c, 1) end
    end
    button:SetScript("OnEnter", function()
        button.hovered = true; button:Paint()
        if button.tip then Tip(button, button.tip()) end
    end)
    button:SetScript("OnLeave", function() button.hovered = false; button:Paint(); HideTip() end)
    return button
end

function M:BuildWindow()
    if self.frame then return end
    local frame = CreateFrame("Frame", "ModeUIBagsFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetSize(400, 300)
    frame.fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.fill:SetTexture(FLAT)
    frame.border = Kit.ModeBoxBorder(frame)
    local header = CreateFrame("Button", nil, frame)
    header:RegisterForDrag("LeftButton")
    header.bar = Kit.Bar(header)
    header.bar:SetAllPoints(); header.bar:SetMinMaxValues(0, 1); header.bar:SetValue(1)
    header.bar.bg:Hide()
    header.layer = CreateFrame("Frame", nil, header)
    header.layer:SetAllPoints(); header.layer:SetFrameLevel(header.bar:GetFrameLevel() + 2)
    header.title = Kit.Text(header.layer)
    header.sort, header.clean, header.close = HeaderButton(header.layer), HeaderButton(header.layer), HeaderButton(header.layer, "ModeClose")
    frame.header = header
    frame.divider = frame:CreateTexture(nil, "BORDER")
    frame.divider:SetTexture(FLAT)
    Kit.MaskToBoxBorder(frame.border, { frame.fill, header.bar:GetStatusBarTexture(), header.bar.sheen, frame.divider })
    self:BuildSearch(frame)
    frame.freeText, frame.moneyText = Kit.Text(frame), Kit.Text(frame)
    frame.labels = {}
    -- One holder per bag, carrying the bag's ID: Blizzard's item buttons
    -- find their bag through their parent (ContainerFrameItemButtonMixin
    -- GetBagID), so nothing is written to them.
    frame.holders = {}
    frame:Hide()
    self.frame = frame
    self:BuildSortMenu()
    self:BindHeader()
    self:BuildMover()
    frame:SetPoint(self.db.growFrom, self.mover, self.db.growFrom, 0, 0)
end

function M:Holder(bag)
    local holders = self.frame.holders
    if not holders[bag] then
        local holder = CreateFrame("Frame", nil, self.frame)
        holder:SetAllPoints(self.frame)
        holder:SetID(bag)
        holders[bag] = holder
    end
    return holders[bag]
end

-- The search box: the game's own bag search, so names, types and tooltip
-- text all match. Without it on the client, names are matched here.
function M:BuildSearch(frame)
    local box = CreateFrame("EditBox", nil, frame)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    box:SetFontObject(GameFontHighlight)
    box.parts = Skin.Panel(box, "BACKGROUND", -8)
    box.hint = Kit.Text(box)
    box.hint:SetPoint("LEFT", box, "LEFT", 6, 0)
    box:SetScript("OnEscapePressed", function() box:SetText(""); box:ClearFocus() end)
    box:SetScript("OnEnterPressed", function() box:ClearFocus() end)
    box:SetScript("OnTextChanged", function() M:SearchChanged(box:GetText() or "") end)
    frame.search = box
end

function M:SearchChanged(text)
    local box = self.frame and self.frame.search
    if box then box.hint:SetShown(text == "") end
    self.searchText = text
    if Containers.HasSearch() then Containers.SetSearch(text) end
    self:UpdateStates()
end

function M:ClearSearch()
    local box = self.frame and self.frame.search
    if box then box:ClearFocus() end
    if box and box:GetText() ~= "" then box:SetText("") end
    if (self.searchText or "") ~= "" then self:SearchChanged("") end
end

-- What the header buttons do, and moving the window by its header.
function M:BindHeader()
    local header = self.frame.header
    header.sort:SetScript("OnClick", function() self:ToggleSortMenu() end)
    header.sort.tip = function() return L["Sort"], L["Choose the order items show in: Bag Order, Quality, Type or Name."] end
    header.clean:SetScript("OnClick", function() self:CleanUp() end)
    header.clean.tip = function() return L["Clean Up"], L["The game sorts the items in your bags."] end
    header.close:SetScript("OnClick", function() self:CloseBags() end)
    header.close.tip = function() return L["Close"] end
    header:SetScript("OnDragStart", function() self:StartMove() end)
    header:SetScript("OnDragStop", function() self:StopMove() end)
end

-- Look: colors, fonts and the header, at the geometry `g` (Layout.lua).
function M:PaintWindow()
    local frame, db = self.frame, self.db
    frame:SetScale(db.scale / 100)
    local g = self:Geometry()
    Kit.Inset(frame.fill, frame, math.max(0, g.border - g.px))
    Kit.Tint(frame.fill, db.backgroundColor, db.backgroundOpacity / 100)
    Kit.LayoutModeBoxBorder(frame.border, frame, { px = g.px, radius = db.corner * g.px, color = db.borderColor,
        level = frame:GetFrameLevel() + 30 })
    local header, path = frame.header, Kit.FontPath(db, self.id)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", g.border, -g.border)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -g.border)
    header:SetHeight(math.max(g.px, g.header))
    Kit.ModeGradient(header.bar, math.max(g.px, g.header), g.px)
    header.bar:SetStatusBarColor(db.headerColor[1], db.headerColor[2], db.headerColor[3], 1)
    local divider = frame.divider
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", g.border, -(g.border + g.header))
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -(g.border + g.header))
    divider:SetHeight(g.px)
    Kit.Tint(divider, Kit.onyx.inner, 1)
    local look = { font = db.font, fontMedia = db.fontMedia, outline = false, shadow = true, textColor = { 1, 1, 1 } }
    Kit.Font(header.title, look, db.titleSize, path, g.px)
    header.title:ClearAllPoints(); header.title:SetPoint("LEFT", header, "LEFT", g.inset, 0)
    header.title:SetText(L["Bags"])
    header.title:SetShown(db.showTitle)
    -- Buttons right to left: close, Clean Up, Sort.
    local glyph = math.max(8, math.min(16, math.floor(g.header / g.px + 0.5) - 6)) * g.px
    header.close:ClearAllPoints(); header.close:SetPoint("RIGHT", header, "RIGHT", -g.inset, 0)
    header.close:SetSize(glyph, glyph)
    local small = math.max(8, db.titleSize - 2)
    local prior = header.close
    for _, key in ipairs({ "clean", "sort" }) do
        local button = header[key]
        Kit.Font(button.text, look, small, path, g.px)
        button.text:SetText(key == "clean" and L["Clean Up"] or self:SortLabel())
        -- Sized from the setting, never measured: a word's width is about
        -- 0.55 of its font size per letter, plus room either side (and
        -- Sort's chevron, a font size square).
        local chevron = key == "sort" and small + 2 or 0
        button:SetSize(math.floor((#button.text:GetText() * small * 0.55 + 12 + chevron) / g.px + 0.5) * g.px, math.max(g.px, g.header))
        button:ClearAllPoints(); button:SetPoint("RIGHT", prior, "LEFT", -g.inset, 0)
        prior = button
    end
    self:PaintSortMenu(g, look, path, small)
    header.clean:SetShown(Containers.CanCleanUp())
    for _, key in ipairs({ "sort", "clean", "close" }) do header[key]:Paint() end
    self:PaintSearch(g, look, path)
    for _, text in ipairs({ frame.freeText, frame.moneyText }) do
        Kit.Font(text, look, math.max(8, db.titleSize - 1), path, g.px)
        text:SetTextColor(Kit.palette.text[1], Kit.palette.text[2], Kit.palette.text[3], 1)
    end
    frame:ClearAllPoints()
    frame:SetPoint(db.growFrom, self.mover, db.growFrom, 0, 0)
    self.g = g
end

function M:SortLabel()
    for _, item in ipairs(self.choices.sortMode) do
        if item.id == self.db.sortMode then return L[item.label] end
    end
    return L["Sort"]
end

function M:PaintSearch(g, look, path)
    local box, db = self.frame.search, self.db
    box:SetShown(db.showSearch)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", self.frame, "TOPLEFT", g.left, -g.searchTop)
    box:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -g.left, -g.searchTop)
    box:SetHeight(g.search)
    box:SetTextInsets(6, 6, 0, 0)
    Skin.PaintPanel(box.parts, box, Skin.colors.field, 1, Skin.colors.fieldRim, g.px)
    Skin.Font(box, path, math.max(8, db.titleSize - 1), false, true, g.px)
    box:SetTextColor(1, 1, 1, 1)
    Kit.Font(box.hint, look, math.max(8, db.titleSize - 1), path, g.px)
    box.hint:SetText(L["Search"])
    local m = Kit.palette.muted
    box.hint:SetTextColor(m[1], m[2], m[3], 0.8)
    box.hint:SetShown((box:GetText() or "") == "")
end

-- Size, and the footer's free slots and money.
function M:SizeWindow(width, height)
    self.frame:SetSize(width, height)
    self:PlaceMover()
    self:UpdateFooter()
end

-- Gold, silver and copper with the game's coin icons; copper alone below a silver.
local COINS = { { 10000, "Interface\\MoneyFrame\\UI-GoldIcon" }, { 100, "Interface\\MoneyFrame\\UI-SilverIcon" },
    { 1, "Interface\\MoneyFrame\\UI-CopperIcon" } }
function M.MoneyText(money, size)
    local parts, rest = {}, money
    for i, coin in ipairs(COINS) do
        local amount = math.floor(rest / coin[1])
        rest = rest - amount * coin[1]
        if amount > 0 or (i == #COINS and #parts == 0) then
            parts[#parts + 1] = string.format("%d|T%s:%d:%d:2:0|t", amount, coin[2], size, size)
        end
    end
    return table.concat(parts, " ")
end

function M:UpdateFooter()
    local frame, g, db = self.frame, self.g, self.db
    if not frame or not g then return end
    local y = g.border + g.pad
    frame.freeText:ClearAllPoints(); frame.freeText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", g.left, y)
    frame.moneyText:ClearAllPoints(); frame.moneyText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -g.left, y)
    frame.freeText:SetShown(db.showFreeSlots and g.footer > 0)
    frame.moneyText:SetShown(db.showMoney and g.footer > 0)
    if db.showFreeSlots then
        local used, total = self:SlotCounts()
        frame.freeText:SetText(string.format(L["%d/%d Free"], total - used, total))
    end
    if db.showMoney then frame.moneyText:SetText(self.MoneyText(Containers.Money(), math.max(8, db.titleSize - 1))) end
end

-- Edit Mode stand-in ------------------------------------------------------------

function M:BuildMover()
    local mover = CreateFrame("Frame", "ModeUIBagsMover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(400, 300)
    mover.parts = Skin.Panel(mover, "BACKGROUND", -8)
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("CENTER")
    local d = self.DEFAULT_POSITION
    mover:SetPoint(d.point, UIParent, d.relativePoint, d.x, d.y)
    self.mover = mover
    local ok, reason = addon.PositionManager:RegisterElement(self.ELEMENT_ID, mover, { moduleId = self.id,
        defaultPosition = d, label = L["Bags"], anyTarget = true, canDrag = function() return self.active == true end })
    assert(ok, "ModeUI: bags position registration failed: " .. tostring(reason))
    mover:Hide()
end

-- The stand-in covers the window (its size times Scale) and shows its name.
function M:PlaceMover()
    local mover, frame = self.mover, self.frame
    if not mover or not frame then return end
    local scale = self.db.scale / 100
    mover:SetSize(frame:GetWidth() * scale, frame:GetHeight() * scale)
    local px = Kit.PixelSize(mover)
    Skin.PaintPanel(mover.parts, mover, self.db.backgroundColor, 0.85, Kit.palette.accent, px)
    Skin.Font(mover.label, Kit.FontPath(self.db, self.id), self.db.titleSize, false, true, px)
    mover.label:SetText(L["Bags"])
    mover.label:SetTextColor(1, 1, 1, 1)
end

-- Moving by the header: unlocked, out of combat and not in Edit Mode.
function M:CanMove() return self.active == true and not self.db.locked and not self.editing and not addon.InCombat() end

function M:StartMove()
    if not self:CanMove() then return end
    self.moving = true
    self.frame:StartMoving()
end

-- Saves where the window was dropped: its Grow From corner as an offset
-- from the same corner of the screen, in whole pixels, as Edit Mode does.
local SIDES = { LEFT = -1, RIGHT = 1, TOP = 1, BOTTOM = -1 }
function M:StopMove()
    if not self.moving then return end
    self.moving = nil
    local frame, point = self.frame, self.db.growFrom
    frame:StopMovingOrSizing()
    if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local vertical, horizontal = point:match("^(TOP)") or point:match("^(BOTTOM)"), point:match("(LEFT)$") or point:match("(RIGHT)$")
    local x = (horizontal == "LEFT" and frame:GetLeft() or frame:GetRight())
    local y = (vertical == "TOP" and frame:GetTop() or frame:GetBottom())
    local ux = horizontal == "LEFT" and UIParent:GetLeft() or UIParent:GetRight()
    local uy = vertical == "TOP" and UIParent:GetTop() or UIParent:GetBottom()
    if Number(x) and Number(y) and Number(ux) and Number(uy) and Number(ratio) and SIDES[vertical] then
        local px = Kit.PixelSize(self.mover)
        local function Snap(v) return math.floor(v / px + 0.5) * px end
        addon.PositionManager:SetPosition(self.ELEMENT_ID, { target = "screen", placement = "center", point = point, relativePoint = point,
            x = Snap(x * ratio - ux), y = Snap(y * ratio - uy) })
    end
    frame:ClearAllPoints()
    frame:SetPoint(point, self.mover, point, 0, 0)
end
