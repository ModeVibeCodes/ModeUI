local _, addon = ...
local M = addon.Bags
if not M then return end

-- One slot: Blizzard's own item button (ContainerFrameItemButtonTemplate)
-- on a holder carrying its bag's ID, so its clicks, drags, stack splitting,
-- tooltip and item use stay Blizzard's code, which reads only the button's
-- and its parent's IDs. ModeUI dresses it as a Mode slot (the approved
-- probe): a face in Slot Color, the icon filling it (cropped to the slot,
-- which is wider than tall), the `group` edge just outside it (its rim in
-- the quality, quest or new-item color), and its own count, item level and
-- junk marks. Blizzard's art on the button is
-- faded; its pushed and highlight states become flat Mode overlays. ModeUI's
-- textures and state live in weak tables keyed by the button: nothing is
-- written to Blizzard's button tables, and none of Blizzard's update
-- functions are called.
local Kit, L, Skin, Style = addon.Kit, addon.L, addon.Skin, addon.Style
local Tone = Style.Tone
local Containers = addon.Domain.Containers
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
    local art = { box = Skin.Box(button, "group") }
    -- ModeUI's texts sit above the cooldown swipe.
    art.layer = CreateFrame("Frame", nil, button)
    art.layer:SetAllPoints()
    art.count, art.level = Kit.Text(art.layer), Kit.Text(art.layer)
    art.junk = art.layer:CreateTexture(nil, "OVERLAY")
    -- The quest mark: the Quest glyph in Quest Color on a dark disc.
    art.questBack = art.layer:CreateTexture(nil, "OVERLAY", nil, 1)
    art.quest = art.layer:CreateTexture(nil, "OVERLAY", nil, 2)
    Style.ApplyAsset(art.questBack, "Circle"); Style.ApplyAsset(art.quest, "IconQuest")
    self.art[button] = art
    return art
end

local function Overlay(texture, host, color, alpha)
    if not texture then return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    Style.ApplyAsset(texture, "Solid")
    texture:SetTexCoord(0, 1, 0, 1)
    Kit.Inset(texture, host, 0)
    Style.Paint(texture, color, alpha)
end
local function Region(button, key, getter)
    local region = button[key]
    if region == nil and button[getter] then region = button[getter](button) end
    return region
end

-- The slot's size and fixed look at the window's geometry `g`.
function M:PaintSlot(button, g)
    local art, db = self.art[button], self.db
    button:SetSize(g.slot, g.slotH)
    -- The face in Slot Color (it shows in empty slots); the edge's rim is
    -- painted with the item (PaintState).
    Skin.PaintBox(art.box, button, "Solid", db.slotColor, db.slotOpacity / 100, true)
    local icon = button.icon
    if icon then
        Kit.Inset(icon, button, 0)
        Style.CropIcon(icon, g.slot, g.slotH)
    end
    if button.Cooldown then Kit.Inset(button.Cooldown, button, 0) end
    for _, key in ipairs(FADED) do
        local region = button[key]
        if region and region.SetAlpha then region:SetAlpha(0) end
    end
    local normal = Region(button, "NormalTexture", "GetNormalTexture")
    if normal and normal.SetAlpha then normal:SetAlpha(0) end
    if button.Count and button.Count.SetAlpha then button.Count:SetAlpha(0) end
    Overlay(Region(button, "PushedTexture", "GetPushedTexture"), button, Tone.shadow, 0.45)
    Overlay(Region(button, "HighlightTexture", "GetHighlightTexture"), button, Tone.mono.white, 0.16)
    art.layer:SetFrameLevel(button:GetFrameLevel() + 4)
    -- Counts and item levels in the Mode typeface's Bold, Text bright.
    local path = Style.Weighted(Kit.FontPath(db, self.id), "bold")
    local look = { font = db.font, fontMedia = db.fontMedia, outline = db.outline, shadow = true, textColor = Tone.textBright }
    local inset = 0
    Kit.Font(art.count, look, db.countSize, path, g.px)
    art.count:ClearAllPoints(); art.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset - g.px, inset + g.px)
    Kit.Font(art.level, look, db.levelSize, path, g.px)
    art.level:ClearAllPoints(); art.level:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset + g.px, inset + g.px)
    local coin = math.max(g.px, math.floor(g.slot * 0.38 / g.px + 0.5) * g.px)
    art.junk:ClearAllPoints(); art.junk:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    art.junk:SetSize(coin, coin)
    if art.junk.SetAtlas then art.junk:SetAtlas("bags-junkcoin") end
    local mark = math.max(g.px, math.floor(g.slotH * 0.4 / g.px + 0.5) * g.px)
    art.quest:ClearAllPoints(); art.quest:SetPoint("TOPRIGHT", button, "TOPRIGHT", -g.px, -g.px)
    art.quest:SetSize(mark, mark)
    art.questBack:ClearAllPoints(); art.questBack:SetPoint("CENTER", art.quest, "CENTER")
    art.questBack:SetSize(mark + 2 * g.px, mark + 2 * g.px)
    Style.Paint(art.questBack, Tone.shadow, 0.85)
    self:PaintCooldownText(button, g)
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

-- The rim: a new item in Ivory, then quest items, then the item's quality
-- from Minimum Quality up, else nil (the edge's own Gunmetal).
function M:RimColor(button, item)
    local db, entry = self.db, self.entries[button]
    if not item then return nil end
    if db.newItems and Containers.IsNew(entry.bag, entry.slot) then return Tone.ivory end
    if db.questBorders then
        local questItem, questID = Containers.Quest(entry.bag, entry.slot)
        if questItem or questID then return db.questColor end
    end
    if db.qualityBorders and type(item.quality) == "number" and item.quality >= self.QUALITY[db.qualityMinimum] then
        return Containers.QualityColor(item.quality)
    end
    return nil
end

-- Search matches, a locked item (being moved), faded junk and the rim.
function M:PaintState(button)
    local entry, art = self.entries[button], self.art[button]
    if not entry or not art then return end
    local item = Containers.Item(entry.bag, entry.slot)
    entry.item = item
    art.box.modeEdge:SetTint(self:RimColor(button, item))
    local icon = button.icon
    local junk = item ~= nil and item.quality == 0 and not item.noValue and self.db.fadeJunk
    if icon then icon:SetDesaturated((item ~= nil and item.locked == true) or junk == true) end
    if icon then icon:SetAlpha(junk and 0.7 or 1) end
    local quest = false
    if item and self.db.questIcon then
        local questItem, questID = Containers.Quest(entry.bag, entry.slot)
        quest = questItem or questID ~= nil
    end
    Style.Paint(art.quest, self.db.questColor)
    art.quest:SetShown(quest); art.questBack:SetShown(quest)
    -- Pointing at a bag in the Bag Bar fades the other bags' slots.
    local focus = self.focusBag == nil or entry.bag == self.focusBag
    button:SetAlpha((self:Matches(item) and focus) and 1 or 0.25)
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

-- The countdown numbers on a slot's cooldown: the Mode typeface's Bold at
-- Count Size, in the cooldown color, centered (Blizzard's own are larger
-- than a slot holds).
function M:PaintCooldownText(button, g)
    local cooldown = button.Cooldown
    if not (cooldown and cooldown.GetCountdownFontString) then return end
    local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
    if not ok or not text or not text.SetFont then return end
    local db = self.db
    local look = { font = db.font, fontMedia = db.fontMedia, outline = true, shadow = true, textColor = Tone.cooldown }
    Kit.Font(text, look, db.countSize, Style.Weighted(Kit.FontPath(db, self.id), "bold"), g.px)
    Skin.Ink(text, Tone.cooldown)
    text:ClearAllPoints(); text:SetPoint("CENTER", button, "CENTER", 0, 0)
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
