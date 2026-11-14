local _, addon = ...
local M = addon.Bags
if not M then return end

-- One slot: Blizzard's own item button (ContainerFrameItemButtonTemplate)
-- on a holder carrying its bag's ID, so its clicks, drags, stack splitting,
-- tooltip and item use stay Blizzard's code, which reads only the button's
-- and its parent's IDs. ModeUI dresses it like an action bar slot: a hollow
-- rim (Slot Border Size, colored by quality, quest or new), a textured fill
-- in Slot Color, the icon one pixel inside the rim, cropped square, and its
-- own count, item level and junk marks. Blizzard's art on the button is
-- faded; its pushed and highlight states become flat Mode overlays. ModeUI's
-- textures and state live in weak tables keyed by the button: nothing is
-- written to Blizzard's button tables, and none of Blizzard's update
-- functions are called.
local Kit, L = addon.Kit, addon.L
local Containers = addon.Domain.Containers
local FLAT = Kit.FLAT
M.art = setmetatable({}, { __mode = "k" })
M.entries = setmetatable({}, { __mode = "k" })

-- Blizzard's regions on the button that ModeUI's look replaces.
local FADED = { "IconBorder", "IconOverlay", "IconOverlay2", "searchOverlay", "ItemContextOverlay", "NewItemTexture",
    "BattlepayItemTexture", "flash", "ExtendedSlot", "BagIndicator", "IconQuestTexture", "UpgradeIcon", "Stock" }

-- The button for a bag's slot, made the first time it's needed. Buttons are
-- named (the template names its children after their parent).
function M:Button(bag, slot)
    self.buttons = self.buttons or {}
    self.slots = self.slots or {}
    local list = self.buttons[bag] or {}
    self.buttons[bag] = list
    if list[slot] then return list[slot] end
    local index = #self.slots + 1
    local button = CreateFrame("ItemButton", "ModeUIBagsItem" .. index, self:Holder(bag), "ContainerFrameItemButtonTemplate")
    button:SetID(slot)
    self:BuildArt(button)
    -- Blizzard's tooltip code clears a new item's mark as the mouse comes in.
    button:HookScript("OnEnter", function() if M.open then M:PaintState(button) end end)
    list[slot], self.slots[index] = button, button
    return button
end

function M:BuildArt(button)
    local art = { edges = {} }
    for i = 1, 4 do art.edges[i] = button:CreateTexture(nil, "BACKGROUND", nil, -8) end
    art.fill = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    art.grain = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    -- ModeUI's texts sit above the cooldown swipe.
    art.layer = CreateFrame("Frame", nil, button)
    art.layer:SetAllPoints()
    art.count, art.level = Kit.Text(art.layer), Kit.Text(art.layer)
    art.junk = art.layer:CreateTexture(nil, "OVERLAY")
    self.art[button] = art
    return art
end

local function Edge(edge, host, point, x1, y1, relative, x2, y2)
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", host, point, x1, y1)
    edge:SetPoint("BOTTOMRIGHT", host, relative, x2, y2)
end
local function Overlay(texture, host, inset, color, alpha)
    if not texture then return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(FLAT)
    texture:SetTexCoord(0, 1, 0, 1)
    Kit.Inset(texture, host, inset)
    texture:SetVertexColor(color[1], color[2], color[3], alpha)
end
local function Region(button, key, getter)
    local region = button[key]
    if region == nil and button[getter] then region = button[getter](button) end
    return region
end

-- The slot's size and fixed look at the window's geometry `g`.
function M:PaintSlot(button, g)
    local art, db = self.art[button], self.db
    button:SetSize(g.slot, g.slot)
    local t = g.slotBorder
    local top, bottom, left, right = art.edges[1], art.edges[2], art.edges[3], art.edges[4]
    Edge(top, button, "TOPLEFT", 0, 0, "TOPRIGHT", 0, -t)
    Edge(bottom, button, "BOTTOMLEFT", 0, t, "BOTTOMRIGHT", 0, 0)
    Edge(left, button, "TOPLEFT", 0, -t, "BOTTOMLEFT", t, t)
    Edge(right, button, "TOPRIGHT", -t, -t, "BOTTOMRIGHT", 0, t)
    for _, edge in ipairs(art.edges) do edge:SetTexture(FLAT); edge:SetShown(t > 0) end
    local alpha = db.slotOpacity / 100
    Kit.Inset(art.fill, button, t)
    art.fill:SetTexture(FLAT); Kit.Tint(art.fill, db.slotColor, alpha)
    Kit.Inset(art.grain, button, t)
    if not addon.Media:ApplyTexture(art.grain, "ActionBarSlot") then art.grain:SetTexture(FLAT) end
    if art.grain.SetBlendMode then art.grain:SetBlendMode("ADD") end
    art.grain:SetVertexColor(1, 1, 1, alpha)
    local inset = g.iconInset
    local icon = button.icon
    if icon then
        Kit.Inset(icon, button, inset)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if button.Cooldown then Kit.Inset(button.Cooldown, button, inset) end
    for _, key in ipairs(FADED) do
        local region = button[key]
        if region and region.SetAlpha then region:SetAlpha(0) end
    end
    local normal = Region(button, "NormalTexture", "GetNormalTexture")
    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    if button.Count and button.Count.SetAlpha then button.Count:SetAlpha(0) end
    Overlay(Region(button, "PushedTexture", "GetPushedTexture"), button, inset, Kit.onyx.inner, 0.45)
    Overlay(Region(button, "HighlightTexture", "GetHighlightTexture"), button, inset, { 1, 1, 1 }, 0.16)
    art.layer:SetFrameLevel(button:GetFrameLevel() + 4)
    local path = Kit.FontPath(db, self.id)
    local look = { font = db.font, fontMedia = db.fontMedia, outline = db.outline, shadow = true, textColor = { 1, 1, 1 } }
    Kit.Font(art.count, look, db.countSize, path, g.px)
    art.count:ClearAllPoints(); art.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset - g.px, inset + g.px)
    Kit.Font(art.level, look, db.levelSize, path, g.px)
    art.level:ClearAllPoints(); art.level:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset + g.px, inset + g.px)
    local coin = math.max(g.px, math.floor(g.slot * 0.38 / g.px + 0.5) * g.px)
    art.junk:ClearAllPoints(); art.junk:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    art.junk:SetSize(coin, coin)
    if art.junk.SetAtlas then art.junk:SetAtlas("bags-junkcoin") end
end

-- What the slot holds: icon, count, item level, junk and the rim's color.
function M:PaintItem(button, item)
    local art, db = self.art[button], self.db
    local icon = button.icon
    if icon then
        icon:SetTexture(item and item.icon or nil)
        icon:SetShown(item ~= nil)
    end
    art.count:SetText(item and item.count > 1 and tostring(item.count) or "")
    local level = item and db.itemLevel and Containers.ItemLevel(item.link)
    art.level:SetShown(level ~= nil)
    if level then
        art.level:SetText(tostring(level))
        local c = db.itemLevelColor == "quality" and Containers.QualityColor(item.quality) or { 1, 1, 1 }
        art.level:SetTextColor(c[1], c[2], c[3], 1)
    end
    local junk = item ~= nil and item.quality == 0 and not item.noValue
    art.junk:SetShown(junk and db.junkCoin)
    self:PaintState(button)
    self:PaintCooldown(button)
end

-- The rim: a new item in the Mode cyan, then quest items, then the item's
-- quality from Minimum Quality up, else Slot Border Color.
function M:RimColor(button, item)
    local db, entry = self.db, self.entries[button]
    if not item then return db.slotBorderColor end
    if db.newItems and Containers.IsNew(entry.bag, entry.slot) then return Kit.palette.accent end
    if db.questBorders then
        local questItem, questID = Containers.Quest(entry.bag, entry.slot)
        if questItem or questID then return db.questColor end
    end
    if db.qualityBorders and type(item.quality) == "number" and item.quality >= self.QUALITY[db.qualityMinimum] then
        return Containers.QualityColor(item.quality) or db.slotBorderColor
    end
    return db.slotBorderColor
end

-- Search matches, a locked item (being moved), faded junk and the rim.
function M:PaintState(button)
    local entry, art = self.entries[button], self.art[button]
    if not entry or not art then return end
    local item = Containers.Item(entry.bag, entry.slot)
    entry.item = item
    local color = self:RimColor(button, item)
    for _, edge in ipairs(art.edges) do Kit.Tint(edge, color, 1) end
    local icon = button.icon
    local junk = item ~= nil and item.quality == 0 and not item.noValue and self.db.fadeJunk
    if icon then icon:SetDesaturated((item ~= nil and item.locked == true) or junk == true) end
    if icon then icon:SetAlpha(junk and 0.7 or 1) end
    button:SetAlpha(self:Matches(item) and 1 or 0.25)
end

-- Whether an item matches the search: the game's own search when the client
-- has it (isFiltered), else its name containing the text.
function M:Matches(item)
    local text = self.searchText or ""
    if text == "" then return true end
    if not item then return false end
    if Containers.HasSearch() then return item.filtered ~= true end
    local name = type(item.name) == "string" and item.name:lower() or ""
    return name:find(text:lower(), 1, true) ~= nil
end

function M:PaintCooldown(button)
    local entry, cooldown = self.entries[button], button.Cooldown
    if not entry or not cooldown then return end
    local start, duration, enabled
    if entry.item then start, duration, enabled = Containers.Cooldown(entry.bag, entry.slot) end
    if enabled and duration and duration > 0 and start then
        cooldown:SetCooldown(start, duration)
        cooldown:Show()
    elseif cooldown.Clear then
        cooldown:Clear()
    end
end
