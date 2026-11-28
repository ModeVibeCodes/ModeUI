local _, addon = ...
-- Cards side by side (docs/DESIGN_LANGUAGE.md, "Settings window"): a page with
-- cardColumns = n packs its cards n across in bands. In page order, each card
-- goes to the shortest column while that column is at least FILL_MIN short of
-- the tallest (a long card on one side takes several short ones on the
-- other); once the columns are nearly level, the band closes and the last card
-- in each column stretches so every column ends level. Rows stack inside a card; on a card wide enough,
-- two pairable rows (sliders, dropdowns) share a line. Notes wrap to the card.
-- Pages without cardColumns keep one full-width card per row.
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local PAIR_GAP, PAIR_MIN, FILL_MIN = 24, 150, 48

local function Visible(page, row)
    local show = not row.sectionHeader
    if page.sectionTabs and row.section and row.section ~= page.selectedSection then show = false end
    if row.section and row.section.expanded == false then show = false end
    if row.visibleWhen then show = show and row.visibleWhen() end
    if row.settingsQuiet then show = false end
    return show and true or false
end

local function Measured(value, fallback)
    if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return fallback end
    return value
end

-- A footer note (page:FooterNote) inside a card: its title, then the note
-- wrapped to the card's width.
local function FitNote(row, width)
    local note, title = row.settingsFooterNote, row.settingsLabel
    if note:GetParent() ~= row then note:SetParent(row) end
    local titled = title and row.settingsTitle and row.settingsTitle ~= ""
    if titled then
        title:Show(); title:ClearAllPoints(); title:SetPoint("TOPLEFT", 0, 0); title:SetWidth(width)
        title:SetTextColor(unpack(T.secondary))
    end
    note:ClearAllPoints(); note:SetPoint("TOPLEFT", 0, titled and -20 or 0)
    note:SetWidth(math.max(1, width)); note:SetWordWrap(true); note:SetTextColor(unpack(T.muted))
    row:SetHeight(math.max(14, Measured(note:GetStringHeight(), 32)) + (titled and 20 or 0) + 8)
    row.settingsFooterMoved = true
end

-- Fitting a row to its tile. Controls and text a module sized for one wide
-- column are brought inside: text wraps (a row grows for text anchored from
-- its top), a fixed-width control shrinks to its room, and frames that fill
-- their parent pass the room on. Each layout starts again from the natural
-- sizes, so a later, wider layout undoes a narrow one. Toggles keep their
-- size; segmented choices are given their room and fit themselves.
local CONTAINERS = { Frame = true, Button = true }

-- Left edge of a region inside `host`, following LEFT-to-RIGHT chains of siblings.
local function LeftOf(region, host, depth)
    local point, relative, relativePoint, x = region:GetPoint(1)
    if type(point) ~= "string" or not point:find("LEFT") then return nil end
    if relative == nil or relative == host then
        if type(relativePoint) == "string" and relativePoint:find("RIGHT") then return nil end
        return Measured(x, 0)
    end
    if depth < 6 and type(relative) == "table" and relative.GetPoint and type(relativePoint) == "string" and relativePoint:find("RIGHT") then
        local left = LeftOf(relative, host, depth + 1)
        if left then return left + Measured(relative:GetWidth(), 0) + Measured(x, 0) end
    end
end

-- The room a child anchored to both of its parent's sides gets, and its top offset.
local function Filled(child, available)
    if child:GetNumPoints() ~= 2 then return nil end
    local p1, r1, _, x1, y1 = child:GetPoint(1)
    local p2, r2, _, x2 = child:GetPoint(2)
    local parent = child:GetParent()
    if (r1 ~= nil and r1 ~= parent) or (r2 ~= nil and r2 ~= parent) then return nil end
    if type(p1) ~= "string" or type(p2) ~= "string" or not (p1:find("LEFT") and p2:find("RIGHT")) then return nil end
    return available - Measured(x1, 0) + (type(x2) == "number" and x2 or 0), -(type(y1) == "number" and y1 or 0)
end

-- A region's natural width: what it had before this pass first fitted it, or
-- whatever its owner (a row's layoutChildren) set since the pass last did.
local function Natural(region)
    local current = Measured(region:GetWidth(), 0)
    if region.gridFitWidth == nil or math.abs(current - region.gridFitWidth) > 0.01 then region.gridNaturalWidth = current end
    return region.gridNaturalWidth
end
local function FitWidth(region, width)
    region:SetWidth(width)
    region.gridFitWidth = width
end

-- A row whose label sits beside its control (page:Row with its own height: a
-- note, a picker) on a tile too narrow for both stacks like a standard row:
-- label above, control below across the row. Too narrow: the room beside the
-- label is under SIDE_MIN, or under what the host's controls need (their
-- natural widths; text its own width, at most SIDE_TEXT, as it wraps). A wider layout puts them
-- back. Rows whose module re-anchored the host (full-width notes, grids) are
-- left alone.
local SIDE_X, SIDE_RIGHT, SIDE_MIN, SIDE_TEXT, STACK_LABEL, ROW_INSET = 184, 14, 120, 160, 22, 4
local function Needs(host)
    local need = 0
    for _, region in ipairs({ host:GetRegions() }) do
        if region:IsShown() and region:GetObjectType() == "FontString" and region:GetNumPoints() == 1 then
            local left = LeftOf(region, host, 0)
            local used = math.min(Natural(region), SIDE_TEXT, Measured(region:GetStringWidth(), SIDE_TEXT))
            if left then need = math.max(need, left + used) end
        end
    end
    for _, child in ipairs({ host:GetChildren() }) do
        if child:IsShown() and child:GetNumPoints() == 1 then
            local left = LeftOf(child, host, 0)
            if left then need = math.max(need, left + Natural(child)) end
        end
    end
    return need
end
local function Restack(row, width)
    local host, label = row.settingsHost, row.settingsLabel
    if not (row.sideLabel and host and label) then return end
    local room = width - SIDE_X - SIDE_RIGHT
    local stack = room < SIDE_MIN or room < Needs(host)
    if not row.gridStacked then
        local point, relative, _, x = host:GetPoint(1)
        if not stack or host:GetNumPoints() ~= 2 or point ~= "TOPLEFT" or (relative ~= nil and relative ~= row) or x ~= SIDE_X then return end
    end
    if stack then
        local titled = label:IsShown() and row.settingsTitle and row.settingsTitle ~= ""
        local top = ROW_INSET
        if titled then
            label:ClearAllPoints(); label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2); label:SetWidth(width)
            label:SetTextColor(unpack(T.secondary))
            top = math.max(STACK_LABEL, Measured(label:GetStringHeight(), 14) + 8)
        end
        host:ClearAllPoints(); host:SetPoint("TOPLEFT", 0, -top); host:SetPoint("BOTTOMRIGHT", 0, ROW_INSET)
        row:SetHeight(row:GetHeight() + top - ROW_INSET)
        row.gridStacked = true
    else
        label:ClearAllPoints(); label:SetPoint("LEFT", row, "LEFT", 0, 0); label:SetWidth(172)
        label:SetTextColor(unpack(T.text))
        host:ClearAllPoints(); host:SetPoint("TOPLEFT", SIDE_X, -ROW_INSET); host:SetPoint("BOTTOMRIGHT", -SIDE_RIGHT, ROW_INSET)
        row.gridStacked = nil
    end
end

local function FitText(row, region, host, available, hostTop)
    -- Text anchored on two sides already spans its host.
    if region:GetNumPoints() ~= 1 then return end
    local left = LeftOf(region, host, 0)
    if not left then return end
    local room = available - left
    if room <= 20 then return end
    local natural = Natural(region)
    -- A wrapping note that starts at the left edge uses the whole width.
    local wraps = region.CanWordWrap and region:CanWordWrap()
    local note = left <= 1 and wraps
    FitWidth(region, note and room or math.min(natural, room))
    if natural > room then region:SetWordWrap(true); wraps = true end
    -- Wrapped text anchored from its top grows the row to its last line.
    local point, _, _, _, y = region:GetPoint(1)
    if wraps and type(point) == "string" and point:find("^TOP") then
        local below = -(type(y) == "number" and y or 0)
        local bottom = hostTop + below + Measured(region:GetStringHeight(), 0) + 6
        if bottom > row:GetHeight() then row:SetHeight(bottom) end
        -- Text a refresher sets after this layout lays the page out again
        -- (W.SettingsTextChanged), so the row follows the new text.
        local text = region:GetText()
        if not (issecretvalue and issecretvalue(text)) then
            row.gridTexts = row.gridTexts or {}
            row.gridTexts[region] = text or ""
        end
    end
end

local function FitFrame(row, frame, available, hostTop, depth)
    if depth > 4 or not frame.GetChildren then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= row.settingsLabel and region:GetObjectType() == "FontString" and region:IsShown() then
            FitText(row, region, frame, available, hostTop)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.FitSegments then
            local left = LeftOf(child, frame, 0)
            if left then child.FitSegments(available - left) end
        elseif child:IsShown() and not child.switchFrame then
            local container = CONTAINERS[child:GetObjectType()]
            if child:GetNumPoints() == 1 then
                local left = LeftOf(child, frame, 0)
                if left then
                    local natural, room = Natural(child), available - left
                    if room >= 40 then FitWidth(child, math.min(natural, room)) end
                end
                if container then FitFrame(row, child, Measured(child:GetWidth(), 0), hostTop, depth + 1) end
            elseif container then
                local room, top = Filled(child, available)
                if room then FitFrame(row, child, room, hostTop + top, depth + 1) end
            end
        end
    end
end

-- Fits one row to `width` from its natural size. footerNotes: a footer note
-- (page:FooterNote) wraps inside the row, as on a tile.
function W.FitSettingsRow(row, width, footerNotes)
    row.gridNaturalHeight = row.gridNaturalHeight or row:GetHeight()
    row:SetHeight(row.gridNaturalHeight)
    row:SetWidth(width)
    row.gridTexts = nil
    if row.layoutChildren then row:layoutChildren(width) end
    if row.settingsFooterNote and footerNotes then FitNote(row, width)
    else Restack(row, width); FitFrame(row, row, width, 0, 0) end
end

-- Whether a refresher changed text the last layout wrapped (a row on show).
function W.SettingsTextChanged(page)
    for _, row in ipairs(page.rows) do
        if row.gridTexts and row:IsShown() then
            for region, text in pairs(row.gridTexts) do
                local now = region:IsShown() and region:GetText() or text
                if not (issecretvalue and issecretvalue(now)) and (now or "") ~= text then return true end
            end
        end
    end
    return false
end

-- Lays out one card's rows from `padding` down; returns { row, y, x } entries and the height.
local function CardRows(page, card, inner, padding, Snap)
    local visible, content = {}, false
    for _, row in ipairs(page.rows) do
        if row.card == card then
            local show = Visible(page, row)
            row:SetShown(show)
            if show then visible[#visible + 1] = row; content = content or not row.cardTitle end
        end
    end
    local function Fit(row, rowWidth) W.FitSettingsRow(row, rowWidth, page.modeFooterLayout) end
    local half, placed, y, index = Snap((inner - PAIR_GAP) / 2), {}, padding, 1
    while index <= #visible do
        local row, partner = visible[index], visible[index + 1]
        if half >= PAIR_MIN and row.stacked and row.pairable and partner and partner.stacked and partner.pairable
 then
            Fit(row, half); Fit(partner, half)
            placed[#placed + 1] = { row = row, y = y, x = 0 }
            placed[#placed + 1] = { row = partner, y = y, x = half + PAIR_GAP }
            y = Snap(y + math.max(row:GetHeight(), partner:GetHeight()))
            index = index + 2
        else
            Fit(row, inner)
            placed[#placed + 1] = { row = row, y = y, x = 0 }
            y = Snap(y + row:GetHeight())
            index = index + 1
        end
    end
    return placed, y + padding, content
end

-- Places every card and row; returns the bottom of the last grid row.
function W.LayoutCardGrid(page, width, left, padding, gap, top)
    local columns = math.max(1, page.cardColumns)
    local px = addon.Kit.PixelSize(page.content)
    local function Snap(value) return math.floor(value / px + 0.5) * px end
    local cardWidth = Snap((width - gap * (columns - 1)) / columns)
    local inner = cardWidth - 2 * padding
    for _, row in ipairs(page.rows) do if not row.card then row:SetShown(false) end end
    local laid = {}
    for _, card in ipairs(page.cards) do
        local placed, height, content = CardRows(page, card, inner, padding, Snap)
        card.frame:SetShown(content)
        if content then laid[#laid + 1] = { card = card, placed = placed, height = height }
        else for _, entry in ipairs(placed) do entry.row:Hide() end end
    end
    local cursor = top or 0
    -- Untitled cards (a page's status and quick actions) are a frameless strip
    -- across every column, above the tiles.
    local tiles = {}
    for _, entry in ipairs(laid) do
        local card = entry.card
        local strip = not card.title
        if card.fill then card.fill:SetShown(not strip) end
        if card.edge then card.edge:SetShown(not strip) end
        if strip then
            local placed, height = CardRows(page, card, width - 2 * padding, padding, Snap)
            card.frame:ClearAllPoints(); card.frame:SetPoint("TOPLEFT", left, -cursor); card.frame:SetSize(width, height)
            card.top, card.bottom = cursor, cursor + height
            for _, item in ipairs(placed) do
                item.row:ClearAllPoints(); item.row:SetPoint("TOPLEFT", left + padding + item.x, -(cursor + item.y))
                item.row.offset = cursor + item.y
            end
            cursor = Snap(cursor + height - padding + gap)
        else tiles[#tiles + 1] = entry end
    end
    local heights, last, band = {}, {}, {}
    local function Reset()
        for i = 1, columns do heights[i], last[i] = 0, nil end
        band = {}
    end
    local function Close()
        local tall = 0
        for i = 1, columns do tall = math.max(tall, heights[i]) end
        if tall == 0 then return end
        -- The last card in each column stretches to the band's bottom.
        for i = 1, columns do if last[i] then last[i].height = last[i].height + tall - heights[i] end end
        for _, entry in ipairs(band) do
            local x, y = left + (entry.column - 1) * (cardWidth + gap), cursor + entry.y
            entry.card.frame:ClearAllPoints(); entry.card.frame:SetPoint("TOPLEFT", x, -y)
            entry.card.frame:SetSize(cardWidth, entry.height)
            entry.card.top, entry.card.bottom = y, y + entry.height
            for _, item in ipairs(entry.placed) do
                item.row:ClearAllPoints(); item.row:SetPoint("TOPLEFT", x + padding + item.x, -(y + item.y))
                item.row.offset = y + item.y
            end
        end
        cursor = Snap(cursor + tall + gap)
        Reset()
    end
    Reset()
    for _, entry in ipairs(tiles) do
        local shortest, tallest, filled = 1, 0, true
        for i = 1, columns do
            if heights[i] < heights[shortest] then shortest = i end
            tallest = math.max(tallest, heights[i])
            filled = filled and heights[i] > 0
        end
        -- Columns nearly level: nothing worth filling, so the band closes.
        if filled and tallest - heights[shortest] < FILL_MIN then Close(); shortest = 1 end
        entry.column = shortest
        entry.y = heights[shortest] > 0 and heights[shortest] + gap or 0
        heights[shortest] = entry.y + entry.height
        last[shortest] = entry
        band[#band + 1] = entry
    end
    Close()
    return cursor
end
