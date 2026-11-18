local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- The settings preview: which bar is being edited (its name and whether it
-- shows), the bar filled with sample auras in its look (the same layout code
-- as Edit Mode) at up to 125% so borders and spacing read, and a caption of
-- what it shows. In the window's preview pane, its Which Auras card fills the
-- room under the bar (owner, November 18, 2026); a narrow window keeps that
-- card on the Bars tab instead.
local W, T, L, Style = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Style
local TITLE, CAPTION, MAX_SCALE, MAX_HEIGHT, MIN_WIDTH = 40, 22, 1.25, 170, 300
local CARD_PAD, BUTTON_HEIGHT, BUTTON_GAP, BUTTON_MIN = 12, 26, 6, 120

local function Shown(bar)
    local parts = {}
    for _, category in ipairs(M.categories[bar.kind]) do
        if bar.cats[category.id] then parts[#parts + 1] = L[category.label] end
    end
    return #parts > 0 and table.concat(parts, ", ") or L["nothing picked"]
end

-- The pane's room (the split layout), or nil when the preview sits on top.
local function Pane()
    local page = M.page
    local area = page and page.previewSplit and page.previewArea
    local width, height = area and area:GetWidth(), area and area:GetHeight()
    if addon.IsNumber(width, 200) and addon.IsNumber(height, 200) then return width - 24, height - 64 end
end

local function Scale(bar, room)
    local width, height = M:BarSize(bar, 1)
    return math.min(MAX_SCALE, (room - 8) / width, MAX_HEIGHT / height), width, height
end

function M:GetPreviewSize()
    local bar = self.db.bars[self:EditingBar()]
    local paneWidth, paneHeight = Pane()
    local room = paneWidth or 420
    local scale, width, height = Scale(bar, room)
    local barHeight = TITLE + height * scale + 12 + CAPTION
    if paneWidth then return math.max(MIN_WIDTH, paneWidth), math.max(barHeight, paneHeight) end
    return math.max(MIN_WIDTH, width * scale), barHeight
end

-- The Which Auras card: a button per kind the bar can show, lit while picked.
local function Card(view)
    local card = CreateFrame("Frame", nil, view.frame)
    local fill = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetAllPoints(); Style.ApplyAsset(fill, "MatteBase"); Style.Paint(fill, T.card)
    card.edge = Style.Edge(card, "card")
    card.title = W.Heading(card, L["Which Auras"]:upper(), T.fontSize.card, CARD_PAD, -CARD_PAD, 300)
    card.title:SetTextColor(unpack(T.primary))
    card.note = W.Label(card, L["Any kind you pick shows, in this order; an aura shows once. All stands alone."],
        nil, CARD_PAD, -CARD_PAD - 22, 300, T.muted)
    card.note:SetWordWrap(true)
    card.buttons = {}
    return card
end

local function LayoutCard(view, bar, top)
    local card = view.card
    local width = view.frame:GetWidth()
    if not addon.IsNumber(width, 100) then width = MIN_WIDTH end
    card:ClearAllPoints(); card:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, -top); card:SetWidth(width)
    local inner = width - 2 * CARD_PAD
    card.note:SetWidth(inner)
    local noteHeight = card.note:GetStringHeight()
    if not addon.IsNumber(noteHeight, 1) then noteHeight = 28 end
    local list = M.categories[bar.kind]
    local perLine = math.max(1, math.min(#list, math.floor((inner + BUTTON_GAP) / (BUTTON_MIN + BUTTON_GAP))))
    local cellWidth = math.floor((inner - BUTTON_GAP * (perLine - 1)) / perLine)
    local first = CARD_PAD + 22 + noteHeight + 10
    for index, category in ipairs(list) do
        local button = card.buttons[index]
        if not button then
            button = W.Button(card, "", BUTTON_MIN, BUTTON_HEIGHT, "choice")
            button:SetScript("OnClick", function(self)
                local id = M:EditingBar()
                M:SetCategory(id, self.category, not M.db.bars[id].cats[self.category])
            end)
            card.buttons[index] = button
        end
        button.category = category.id
        button.label:SetText(L[category.label])
        button:SetSelected(bar.cats[category.id] == true)
        button:SetEnabled(M:CanConfigure())
        local column, line = (index - 1) % perLine, math.floor((index - 1) / perLine)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + column * (cellWidth + BUTTON_GAP), -first - line * (BUTTON_HEIGHT + BUTTON_GAP))
        button:SetWidth(cellWidth)
        button:Show()
    end
    for index = #list + 1, #card.buttons do card.buttons[index]:Hide() end
    local lines = math.ceil(#list / perLine)
    card:SetHeight(first + lines * (BUTTON_HEIGHT + BUTTON_GAP) - BUTTON_GAP + CARD_PAD)
    card:Show()
end

function M:RenderPreview(view)
    local id = self:EditingBar()
    local bar = self.db.bars[id]
    local room = view.frame:GetWidth()
    if not addon.IsNumber(room, 100) then room = Pane() or 420 end
    local scale, width, height = Scale(bar, room)
    view.name:SetText(self:BarLabel(id))
    view.state:SetText(bar.show and L["ON"] or L["OFF"])
    view.state:SetTextColor(unpack(bar.show and Style.Tone.celadon or T.muted))
    local nameWidth = view.name:GetStringWidth()
    view.state:ClearAllPoints()
    view.state:SetPoint("BOTTOMLEFT", view.name, "BOTTOMLEFT", (addon.IsNumber(nameWidth) and nameWidth or 160) + 10, 1)
    local host = view.host
    host:SetScale(scale)
    host:SetSize(width, height)
    host:ClearAllPoints(); host:SetPoint("TOP", view.frame, "TOP", 0, -TITLE / scale)
    host:SetAlpha(bar.show and 1 or 0.4)
    self:PaintSamples(host, view.pool, bar, 1)
    view.caption:SetText(bar.show and Shown(bar) or L["hidden"])
    local below = TITLE + height * scale + 8
    view.caption:ClearAllPoints(); view.caption:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, -below)
    view.caption:SetWidth(math.max(100, room))
    if self.page and self.page.previewSplit then
        view.card = view.card or Card(view)
        LayoutCard(view, bar, below + CAPTION + 8)
    elseif view.card then view.card:Hide() end
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, pool = {} }
    view.eyebrow = W.Label(frame, L["Editing"], nil, 0, 0, 200, T.muted)
    view.name = W.Heading(frame, "", T.fontSize.page, 0, -15, 300)
    view.name:SetTextColor(unpack(T.primary)); view.name:SetWordWrap(false)
    view.state = W.Label(frame, "", nil, 0, -18, 60, T.muted)
    view.host = CreateFrame("Frame", nil, frame)
    view.caption = W.Label(frame, "", nil, 0, 0, 400, T.muted)
    view.caption:SetJustifyH("LEFT"); view.caption:SetWordWrap(false)
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    self.previewViews = self.previewViews or {}
    self.previewViews[#self.previewViews + 1] = view
    return view
end

function M:RefreshPreview()
    for _, view in ipairs(self.previewViews or {}) do view.Refresh() end
    local page = self.page
    if page and page.UpdatePreviewLayout then page:UpdatePreviewLayout() end
end
