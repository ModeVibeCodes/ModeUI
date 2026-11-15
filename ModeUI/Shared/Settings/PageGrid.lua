local _, addon = ...
-- Cards side by side (docs/DESIGN_LANGUAGE.md, "Settings window"): a page with
-- cardColumns = n lays its cards n across in grid rows, left to right; every
-- card in a grid row takes that row's height, as in the artifact. Rows stack
-- inside a card; on a card wide enough, two pairable rows (sliders, dropdowns)
-- share a line. Notes wrap to the card. Pages without cardColumns keep one
-- full-width card per row.
local W, T = addon.ConfigWidgets, addon.InterfaceTheme
local PAIR_GAP, PAIR_MIN = 24, 150

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

-- Text a module sized for one wide column wraps inside a narrower card; a row
-- grows to fit text anchored from its top. Each layout starts again from the
-- text's own width and the row's own height, so a later, wider layout undoes a
-- narrow one. host: the row or its control host; hostTop: how far the host
-- sits below the row's top.
local function ClampText(row, host, width, hostTop)
    if not (host and host.GetRegions) then return end
    for _, region in ipairs({ host:GetRegions() }) do
        -- The row sizes its own label (layoutChildren); leave it alone.
        if region ~= row.settingsLabel and region:GetObjectType() == "FontString" and region:IsShown() then
            local point, _, _, x, y = region:GetPoint(1)
            local room = width - Measured(x, 0)
            region.gridNaturalWidth = region.gridNaturalWidth or Measured(region:GetWidth(), 0)
            local natural = region.gridNaturalWidth
            -- A wrapping note that starts at the left edge uses the whole width.
            local note = Measured(x, 0) <= 1 and region.CanWordWrap and region:CanWordWrap()
            if room > 20 then
                region:SetWidth(note and room or math.min(natural, room))
                if natural > room then
                    region:SetWordWrap(true)
                    if type(point) == "string" and point:find("^TOP") then
                        local bottom = hostTop - Measured(y, 0) + Measured(region:GetStringHeight(), 0) + 6
                        if bottom > row:GetHeight() then row:SetHeight(bottom) end
                    end
                end
            end
        end
    end
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
    local function Fit(row, rowWidth)
        row.gridNaturalHeight = row.gridNaturalHeight or row:GetHeight()
        row:SetHeight(row.gridNaturalHeight)
        row:SetWidth(rowWidth)
        if row.layoutChildren then row:layoutChildren(rowWidth) end
        if row.settingsFooterNote and page.modeFooterLayout then FitNote(row, rowWidth)
        else
            ClampText(row, row, rowWidth, 0)
            -- The control host's own offset in the row (notes fill the row; stacked
            -- controls sit under the label; others beside it).
            local host = row.settingsHost
            if host and host ~= row then
                local _, _, _, hostLeft, hostTop = host:GetPoint(1)
                hostLeft, hostTop = Measured(hostLeft, 0), -(type(hostTop) == "number" and hostTop or 0)
                ClampText(row, host, rowWidth - hostLeft, hostTop)
            end
        end
    end
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
    laid = tiles
    for first = 1, #laid, columns do
        local rowHeight = 0
        for i = first, math.min(#laid, first + columns - 1) do rowHeight = math.max(rowHeight, laid[i].height) end
        for i = first, math.min(#laid, first + columns - 1) do
            local entry = laid[i]
            local x = left + (i - first) * (cardWidth + gap)
            entry.card.frame:ClearAllPoints(); entry.card.frame:SetPoint("TOPLEFT", x, -cursor)
            entry.card.frame:SetSize(cardWidth, rowHeight)
            entry.card.top, entry.card.bottom = cursor, cursor + rowHeight
            for _, item in ipairs(entry.placed) do
                item.row:ClearAllPoints(); item.row:SetPoint("TOPLEFT", x + padding + item.x, -(cursor + item.y))
                item.row.offset = cursor + item.y
            end
        end
        cursor = Snap(cursor + rowHeight + gap)
    end
    return cursor
end
