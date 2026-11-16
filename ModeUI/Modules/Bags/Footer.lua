local _, addon = ...
local M = addon.Bags
if not M then return end

-- The window's footer, left to right (owner, November 15, 2026):
--   Bag Bar   one small Mode slot per equipped bag slot (the four bags, then
--             the reagent bag when the client has one): the bag's icon (a
--             faint bag glyph when the slot is empty), its free slots, and
--             the `group` edge in the bag's quality. Drop a bag on a slot,
--             or click it with a bag on the cursor, to equip it there; drag
--             a bag off to pick it up (the game's PutItemInBag and
--             PickupBagFromSlot, as Blizzard's bag bar does). Pointing at
--             one shows the game's tooltip for it and fades every slot of
--             the other bags.
--   Free      the free slots in the held bags in Bold, Celadon with room,
--             Ivory when a tenth or less is left, Rosewood when full; "free"
--             beside it in Graphite muted, and a thin capacity bar under
--             them that fills as the bags fill, in the same color.
--   Money     gold, silver and copper with the game's coin icons, at the right.
-- Plain frames: nothing here is protected.
local Kit, L, Skin, Style = addon.Kit, addon.L, addon.Skin, addon.Style
local Tone = Style.Tone
local C = Skin.mode
local Containers = addon.Domain.Containers
local BAG_WIDTH, METER_WIDTH, METER_HEIGHT = 26, 64, 3

function M:BuildFooter(frame)
    frame.freeCount, frame.freeLabel, frame.moneyText = Kit.Text(frame), Kit.Text(frame), Kit.Text(frame)
    frame.freeMeter = Style.Bar(frame, { role = "status", endLine = false })
    frame.bagButtons = {}
end

-- The equipped bag slots' bag IDs: 1-4, then the reagent bags.
function M:EquippedBags()
    local list = {}
    for bag = 1, Containers.BagCount() + Containers.ReagentCount() do list[#list + 1] = bag end
    return list
end

local function Tip(button)
    if not (GameTooltip and GameTooltip.SetOwner) then return end
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    if not Containers.BagTooltip(GameTooltip, button.bag) then
        local title = Containers.IsReagent(button.bag) and _G.EQUIP_CONTAINER_REAGENT or _G.EQUIP_CONTAINER
        GameTooltip:SetText(type(title) == "string" and title or L["Bag Slot"], 1, 1, 1)
    end
    GameTooltip:Show()
end

function M:BagButton(bag)
    local buttons = self.frame.bagButtons
    if buttons[bag] then return buttons[bag] end
    local button = CreateFrame("Button", nil, self.frame)
    button.bag = bag
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button.box = Skin.Box(button, "group")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.empty = button:CreateTexture(nil, "ARTWORK")
    Style.ApplyAsset(button.empty, "IconBags")
    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    Style.ApplyAsset(button.hover, "Solid")
    button.hover:SetAllPoints()
    Style.Paint(button.hover, Tone.mono.white, 0.16)
    button.free = Kit.Text(button)
    button:SetScript("OnClick", function() if Containers.CursorHasItem() then Containers.EquipBag(bag) end end)
    button:SetScript("OnReceiveDrag", function() Containers.EquipBag(bag) end)
    button:SetScript("OnDragStart", function() Containers.PickupBag(bag) end)
    button:SetScript("OnEnter", function()
        M.focusBag = bag; M:UpdateStates(); Tip(button)
    end)
    button:SetScript("OnLeave", function()
        M.focusBag = nil; M:UpdateStates()
        if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    end)
    buttons[bag] = button
    return button
end

-- The footer's height: the bag slots' when the bar shows, else a text line.
function M.FooterHeight(db, g)
    if not (db.showMoney or db.showFreeSlots or db.showBagBar) then return 0 end
    local px = g.px
    local text = math.max(16, db.titleSize + 4) + (db.showFreeSlots and (METER_HEIGHT + 2) * px or 0)
    local bag = db.showBagBar and Style.IconHeight(BAG_WIDTH) * px or 0
    return math.floor(math.max(text, bag) / px + 0.5) * px
end

-- How full the bags are, as a color: Celadon, Ivory near full, Rosewood full.
function M.FullnessColor(free, total)
    if free <= 0 then return Tone.rosewood end
    if free <= math.max(1, math.floor(total / 10)) then return Tone.ivory end
    return Tone.celadon
end

function M:PaintBagButton(button, g, x, bottom, look, path)
    local px = g.px
    local width, height = BAG_WIDTH * px, Style.IconHeight(BAG_WIDTH) * px
    button:SetSize(width, height)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, bottom)
    Skin.PaintBox(button.box, button, "Solid", self.db.slotColor, self.db.slotOpacity / 100, true)
    local icon = Containers.BagIcon(button.bag)
    button.icon:SetAllPoints()
    button.icon:SetTexture(icon)
    Style.CropIcon(button.icon, width, height)
    button.icon:SetShown(icon ~= nil)
    local glyph = math.floor(height * 0.6 / px + 0.5) * px
    button.empty:ClearAllPoints(); button.empty:SetPoint("CENTER")
    button.empty:SetSize(glyph, glyph)
    Style.Paint(button.empty, C.muted, 0.6)
    button.empty:SetShown(icon == nil)
    local quality = icon and Containers.BagQuality(button.bag)
    button.box.modeEdge:SetTint(quality and quality >= 2 and Containers.QualityColor(quality) or nil)
    Kit.Font(button.free, look, math.max(8, self.db.countSize - 2), path, px)
    button.free:ClearAllPoints(); button.free:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -px, px)
    button.free:SetText(icon and tostring(Containers.FreeSlots(button.bag)) or "")
    button:Show()
    return x + width
end

-- Places and fills the footer (Layout and money changes call this).
function M:UpdateFooter()
    local frame, g, db = self.frame, self.g, self.db
    if not frame or not g then return end
    local px, bottom = g.px, g.border + g.pad
    local height = g.footer
    local path = Kit.FontPath(db, self.id)
    local bold = Style.Weighted(path, "bold")
    local look = { font = db.font, fontMedia = db.fontMedia, outline = true, shadow = true, textColor = Tone.textBright }
    local size = math.max(8, db.titleSize - 1)
    local x = g.left
    local shown = {}
    if db.showBagBar and height > 0 then
        local gap = math.max(g.gap, 3 * px)
        local top = bottom + math.floor((height - Style.IconHeight(BAG_WIDTH) * px) / 2 / px + 0.5) * px
        for _, bag in ipairs(self:EquippedBags()) do
            local button = self:BagButton(bag)
            x = self:PaintBagButton(button, g, x, top, look, bold) + gap
            shown[button] = true
        end
        x = x - gap + g.inset * 2
    end
    for _, button in pairs(frame.bagButtons) do if not shown[button] then button:Hide() end end
    -- Free slots: the count over the capacity bar, centered in the footer.
    local free = db.showFreeSlots and height > 0
    for _, part in ipairs({ frame.freeCount, frame.freeLabel, frame.freeMeter }) do part:SetShown(free) end
    if free then
        local used, total = self:SlotCounts()
        local left = math.max(0, total - used)
        local color = self.FullnessColor(left, total)
        -- The count (its font size tall), 2px, then the bar: centered.
        local block = size + 1 + (2 + METER_HEIGHT) * px
        local base = bottom + math.max(0, math.floor((height - block) / 2 / px + 0.5) * px)
        Kit.Font(frame.freeCount, { font = db.font, fontMedia = db.fontMedia, outline = false, shadow = true, textColor = color }, size + 1, bold, px)
        frame.freeCount:SetText(tostring(left))
        Skin.Ink(frame.freeCount, color)
        Kit.Font(frame.freeLabel, { font = db.font, fontMedia = db.fontMedia, outline = false, shadow = true, textColor = C.muted }, size, path, px)
        frame.freeLabel:SetText(L["free"])
        Skin.Ink(frame.freeLabel, C.muted)
        local meter = frame.freeMeter
        meter:ClearAllPoints()
        meter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, base)
        meter:SetSize(METER_WIDTH * px, METER_HEIGHT * px)
        meter:SetMinMaxValues(0, math.max(1, total))
        meter:SetValue(used)
        meter:SetFill(color)
        frame.freeCount:ClearAllPoints()
        frame.freeCount:SetPoint("BOTTOMLEFT", meter, "TOPLEFT", 0, 2 * px)
        frame.freeLabel:ClearAllPoints()
        frame.freeLabel:SetPoint("BOTTOMLEFT", frame.freeCount, "BOTTOMRIGHT", 3 * px, 0)
    end
    local money = frame.moneyText
    money:SetShown(db.showMoney and height > 0)
    if db.showMoney then
        Kit.Font(money, { font = db.font, fontMedia = db.fontMedia, outline = false, shadow = true, textColor = C.text }, size, path, px)
        Skin.Ink(money, C.text)
        money:ClearAllPoints()
        money:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -g.left, bottom + height / 2)
        money:SetText(self.MoneyText(Containers.Money(), size))
    end
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
