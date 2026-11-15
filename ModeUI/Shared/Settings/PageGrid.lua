local _, addon = ...
-- Cards side by side (docs/DESIGN_LANGUAGE.md, "Settings window"): a page with
-- cardColumns = n lays its cards n across (four on a sidebar page, two in the
-- split view's settings column), each card in the shortest column, its rows
-- stacked inside. Pages without cardColumns keep one full-width card per row.
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
        local y, placed, content = padding, {}, false
        for _, row in ipairs(page.rows) do
            if row.card == card then
                local show = Visible(page, row)
                row:SetShown(show)
                if show then
                    row:SetWidth(inner)
                    if row.layoutChildren then row:layoutChildren(inner) end
                    placed[#placed + 1] = { row = row, y = y }
                    y = Snap(y + row:GetHeight())
                    content = content or not row.cardTitle
                end
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
                entry.row:ClearAllPoints(); entry.row:SetPoint("TOPLEFT", x + padding, -(cardTop + entry.y))
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
