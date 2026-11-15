local _, addon = ...
-- Cards side by side (docs/DESIGN_LANGUAGE.md, "Settings window"): a page with
-- cardColumns = n lays its cards n across (four on a sidebar page, two in the
-- split view's settings column), each card in the shortest column, its rows
-- stacked inside; on a card wide enough, two pairable rows (sliders,
-- dropdowns) share a line. Pages without cardColumns keep one full-width card
-- per row.
local PAIR_GAP, PAIR_MIN = 24, 150
local W = addon.ConfigWidgets

local function Visible(page, row)
    local show = not row.sectionHeader
    if page.sectionTabs and row.section and row.section ~= page.selectedSection then show = false end
    if row.section and row.section.expanded == false then show = false end
    if row.visibleWhen then show = show and row.visibleWhen() end
    return show and true or false
end

-- Places every card and row; returns the height used below `top`.
function W.LayoutCardGrid(page, width, left, padding, gap, top)
    local columns = math.max(1, page.cardColumns)
    local px = addon.Kit.PixelSize(page.content)
    local function Snap(value) return math.floor(value / px + 0.5) * px end
    local cardWidth = Snap((width - gap * (columns - 1)) / columns)
    local inner = cardWidth - 2 * padding
    local heights = {}
    for i = 1, columns do heights[i] = top or 0 end
    for _, row in ipairs(page.rows) do if not row.card then row:SetShown(false) end end
    for _, card in ipairs(page.cards) do
        local y, placed, content, visible = padding, {}, false, {}
        for _, row in ipairs(page.rows) do
            if row.card == card then
                local show = Visible(page, row)
                row:SetShown(show)
                if show then visible[#visible + 1] = row; content = content or not row.cardTitle end
            end
        end
        local half = Snap((inner - PAIR_GAP) / 2)
        local function Fit(row, rowWidth)
            row:SetWidth(rowWidth)
            if row.layoutChildren then row:layoutChildren(rowWidth) end
        end
        local index = 1
        while index <= #visible do
            local row, partner = visible[index], visible[index + 1]
            if half >= PAIR_MIN and row.stacked and row.pairable and partner and partner.stacked and partner.pairable then
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
        card.frame:SetShown(content)
        if content then
            local column = 1
            for i = 2, columns do if heights[i] < heights[column] then column = i end end
            local x, cardTop = left + (column - 1) * (cardWidth + gap), heights[column]
            card.frame:ClearAllPoints(); card.frame:SetPoint("TOPLEFT", x, -cardTop)
            card.frame:SetSize(cardWidth, y + padding)
            card.top, card.bottom = cardTop, cardTop + y + padding
            for _, entry in ipairs(placed) do
                entry.row:ClearAllPoints(); entry.row:SetPoint("TOPLEFT", x + padding + entry.x, -(cardTop + entry.y))
                entry.row.offset = cardTop + entry.y
            end
            heights[column] = Snap(cardTop + y + padding + gap)
        else
            for _, entry in ipairs(placed) do entry.row:Hide() end
        end
    end
    local bottom = 0
    for i = 1, columns do bottom = math.max(bottom, heights[i]) end
    return bottom
end
