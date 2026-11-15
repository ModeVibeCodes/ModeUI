local _, ns = ...
local Kit = ns.Kit
if not Kit.ok then return end
-- Tooltip, Bags and Minimap probes (Phase 7). Tooltips: the `window` look,
-- the name in Gradient SemiBold, a Mode Gradient health bar; item tooltips
-- take the item quality on their rim. Bags: slots 36 x 30 in the `group` edge
-- 1px apart, quality on the rim, read live from your bags. Minimap: the frame
-- around the game's map (200 x 184, the map itself stays the game's).
local S, T, D = Kit.S, Kit.T, Kit.D
local C = D.Containers

local function Line(parent, text, size, weight, color, y, x)
    local line = Kit.Text(parent, size, weight, color)
    line:SetPoint("TOPLEFT", x or 9, y)
    line:SetText(text)
    return line
end

function ns.BuildTooltip(body)
    -- A unit tooltip: you, live where the game allows.
    local unit = ns.Panel(body, nil, 220, 92)
    unit:SetPoint("TOPLEFT", 6, -6)
    local c = D.UnitColor.PlayerClass("player")
    local name = Kit.Text(unit, 14, "semibold")
    name:SetPoint("TOPLEFT", 9, -9)
    S.SetName(name, D.Name.Get("player"), c and { c.r, c.g, c.b } or T.reaction.friendly, "gradient")
    Line(unit, "<Mode>", 11, "medium", T.graphite.secondary, -30)
    local level = D.Level.Text("player")
    local _, class = D.Query.Plain(UnitClass, "player")
    Line(unit, "Level " .. (level ~= "" and level or "60") .. "  " .. (class and class:sub(1, 1) .. class:sub(2):lower() or ""), 11,
        "medium", T.graphite.text, -46)
    local holder = CreateFrame("Frame", nil, unit)
    holder:SetPoint("BOTTOMLEFT", 9, 10); holder:SetPoint("BOTTOMRIGHT", -9, 10); holder:SetHeight(4)
    local bar = S.Bar(holder, { role = "healthClass" })
    bar:SetAllPoints()
    bar:SetFill(c and { c.r, c.g, c.b } or T.reaction.friendly)
    local okMax, max, okValue, value = D.Health.Read("player")
    bar:SetMinMaxValues(0, okMax and max or 1); bar:SetValue(okValue and value or 1)
    Kit.Caption(body, "Unit: window look, Gradient name, Mode Gradient health under the lines.", unit, 0, -10)
    -- An item tooltip: the rim in the item quality.
    local item = ns.Panel(body, nil, 240, 150)
    item:SetPoint("TOPLEFT", unit, "TOPRIGHT", 30, 0)
    item.edge:SetTint(T.quality[4])
    Line(item, "Blade of Hidden Paths", 13, "semibold", T.quality[4], -9)
    Line(item, "Binds when picked up", 11, "medium", T.graphite.text, -30)
    Line(item, "One-Hand", 11, "medium", T.graphite.text, -46)
    Line(item, "Dagger", 11, "medium", T.graphite.text, -46, 180)
    Line(item, "41 - 77 Damage", 11, "medium", T.graphite.text, -62)
    Line(item, "+12 Agility", 11, "medium", T.quality[2], -78)
    Line(item, "+9 Stamina", 11, "medium", T.quality[2], -94)
    Line(item, "Durability 75 / 75", 11, "medium", T.graphite.text, -110)
    Line(item, "Requires Level 58", 11, "medium", T.graphite.secondary, -126)
    Kit.Caption(body, "Item: the rim takes the item quality (epic here).", item, 0, -10)
end

-- Money as text: gold, silver and copper in the game's own coin art when it
-- offers it.
local function Money(copper)
    if GetCoinTextureString then
        local ok, text = pcall(GetCoinTextureString, copper)
        if ok and Kit.IsPublic(text) and type(text) == "string" then return text end
    end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

function ns.BuildBags(body)
    local PER_ROW, SIZE = 12, 36
    local bags = ns.Panel(body, "Bags", 12 + PER_ROW * (SIZE + 3), 380)
    bags:SetPoint("TOPLEFT", 6, -6)
    local search = ns.Field(bags, 150, "Search")
    search:SetPoint("TOPLEFT", 8, -30)
    local money = Kit.Text(bags, 11, "semibold", T.graphite.text)
    money:SetPoint("TOPRIGHT", -10, -35)
    local px = S.Pixel(bags)
    local step = SIZE + 3 * px -- 1px between the rims
    local slots = {}
    local function Slot(i)
        if slots[i] then return slots[i] end
        local slot = Kit.Icon(bags, SIZE, "group")
        slot.back:ClearAllPoints(); slot.back:SetAllPoints()
        S.Paint(slot.back, T.mono.panel)
        local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
        slot:SetPoint("TOPLEFT", bags, "TOPLEFT", 8 + col * step, -64 - row * (S.IconHeight(SIZE) + 3 * px))
        slot:EnableMouse(true)
        slot:SetScript("OnEnter", function(self)
            if self.bag and GameTooltip and GameTooltip.SetBagItem then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetBagItem(self.bag, self.slotIndex); GameTooltip:Show()
            end
        end)
        slot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        slots[i] = slot
        return slot
    end
    local empty = Kit.Caption(bags, "", search, 0, -10)
    local function Refresh()
        money:SetText(Money(C.Money()))
        local n, maxSlots = 0, PER_ROW * 9
        for _, bag in ipairs(C.HeldBags()) do
            for index = 1, C.NumSlots(bag) do
                if n >= maxSlots then break end
                n = n + 1
                local slot, item = Slot(n), C.Item(bag, index)
                slot.bag, slot.slotIndex = bag, index
                slot.icon:SetTexture(item and item.icon or nil)
                slot.count:SetText(item and item.count and item.count > 1 and item.count or "")
                local quality = item and item.quality
                slot.edge:SetTint((Kit.IsNumber(quality) and quality >= 2) and (C.QualityColor(quality) or T.quality[quality]) or nil)
                slot.icon:SetDesaturated(item and item.locked == true or false)
                slot:Show()
            end
        end
        for i = n + 1, #slots do slots[i]:Hide() end
        empty:SetText(n == 0 and "No bags to read." or "")
    end
    Refresh()
    Kit.Every(bags, 1, Refresh)
    Kit.Caption(body, "Your bags (live): 36 x 30 slots, group edge 1px apart, uncommon and better on the rim. Hover for the game's tooltip; clicks do nothing.", bags, 0, -10):SetWidth(700)
end

function ns.BuildMinimap(body)
    local map = CreateFrame("Frame", nil, body)
    map:SetSize(200, 184)
    map:SetPoint("TOPLEFT", 10, -10)
    Kit.Fill(map, "Matte", T.mono.track)
    S.Edge(map, "frame")
    local hint = Kit.Text(map, 10, "medium", T.graphite.muted)
    hint:SetPoint("CENTER", 0, 14)
    hint:SetText("the game's map")
    local clock = Kit.Text(map, 12, "bold", T.textBright)
    clock:SetPoint("BOTTOM", 0, 22)
    local zone = Kit.Text(map, 11, "semibold", T.graphite.text)
    zone:SetPoint("BOTTOM", 0, 8)
    zone:SetWidth(186); zone:SetWordWrap(false)
    -- The button container under the map: tiles in the `group` edge, 1px apart.
    local tray = CreateFrame("Frame", nil, body)
    tray:SetSize(200, 26)
    tray:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 0, -8)
    local px = S.Pixel(tray)
    for i, name in ipairs({ "Bags", "Chat", "Tooltip", "Windows", "Profiles" }) do
        local tile = CreateFrame("Frame", nil, tray)
        tile:SetSize(26, S.IconHeight(26))
        tile:SetPoint("LEFT", tray, "LEFT", (i - 1) * (26 + 3 * px), 0)
        Kit.Fill(tile, "Button", T.mono.raised)
        S.Edge(tile, "group")
        local glyph = tile:CreateTexture(nil, "ARTWORK")
        S.ApplyAsset(glyph, "Icon" .. name); S.Paint(glyph, T.graphite.secondary)
        glyph:SetSize(14, 14); glyph:SetPoint("CENTER")
    end
    local function Refresh()
        local hour, minute = D.Query.Plain(GetGameTime)
        clock:SetText((Kit.IsNumber(hour) and Kit.IsNumber(minute)) and string.format("%02d:%02d", hour, minute)
            or (date and date("%H:%M")) or "")
        -- The zone name may be secret: straight to SetText.
        local ok, text = D.Location.ZoneText()
        if not (ok and pcall(zone.SetText, zone, text)) then zone:SetText("") end
    end
    Refresh()
    Kit.Every(map, 1, Refresh)
    Kit.Caption(body, "Frame: 200 x 184, frame edge; clock above zone at the bottom (live); addon buttons in a tray under the map. A layout preview: your real minimap is not moved.", tray, 0, -12):SetWidth(600)
end
