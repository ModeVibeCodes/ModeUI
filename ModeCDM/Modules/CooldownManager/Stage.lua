local _, ns = ...
local addon = ns.ModeUI or {}
local M, W, T, L = addon.CooldownManager, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The preview's Layout view (owner, November 24, 2026: "Stage"): every bar
-- that shows, where it sits on screen and to scale, read from the bars'
-- Edit Mode stand-ins; the bar being edited is outlined, and clicking
-- another bar edits that one. The Bar view (Preview.lua) shows the bar alone
-- to click and drag its spells. Icons show your spells' pictures; the
-- player bars a plain fill. It draws only while the module is on (the
-- stand-ins exist then); otherwise the Bar view shows.
local Style, Number = addon.Style, addon.IsNumber
local Tone = Style.Tone
local PAD, CAPTION = 6, 18
M.previewMode = "layout"

local function Rect(frame)
    if not frame then return end
    local l, b, w, h = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight()
    if Number(l) and Number(b) and Number(w, 2) and Number(h, 2) then return l, b, w, h end
end

-- What the stage draws: { id, kind ("bar", "resource", "cast"), frame }.
function M:StageItems()
    local list = {}
    if not self.built then return list end
    for _, id in ipairs(self:BarIds()) do
        if self.db[id].show and self.movers and self.movers[id] then list[#list + 1] = { id = id, kind = "bar", frame = self.movers[id] } end
    end
    for _, id in ipairs(self.resources) do
        local style = self.db.resources[id]
        if style.show and self:ResourceActive(id) and self.resourceMovers and self.resourceMovers[id] then
            list[#list + 1] = { id = id, kind = "resource", frame = self.resourceMovers[id] }
        end
    end
    if self.db.castBar.show and self.castMover then list[#list + 1] = { id = "cast", kind = "cast", frame = self.castMover } end
    return list
end

local function RimColor(style)
    if style.border == "none" then return nil end
    if Style.IsFlatStyle(style.edgeStyle) then return style.edgeColor end
    local metal = Tone.metal[style.edgeMetal == "default" and "obsidian" or style.edgeMetal]
    return metal and (metal.mid or metal.light) or Tone.emptyRim
end
local FILLS = { power = Tone.celadon, combo = Tone.reaction.hostile, mana = Tone.celadon, health = Tone.reaction.friendly }

local function Pooled(stage, kind, index, parent)
    stage.pools[kind] = stage.pools[kind] or {}
    local frame = stage.pools[kind][index]
    if not frame then
        frame = CreateFrame("Frame", nil, parent)
        frame.rim = frame:CreateTexture(nil, "BACKGROUND")
        frame.rim:SetPoint("TOPLEFT", -1, 1); frame.rim:SetPoint("BOTTOMRIGHT", 1, -1)
        frame.face = frame:CreateTexture(nil, "ARTWORK")
        frame.face:SetAllPoints()
        stage.pools[kind][index] = frame
    end
    frame:SetParent(parent)
    return frame
end

-- One bar's drawing: its icons by the real geometry (holder scaled to the
-- stage), or a plain box for a player bar.
local function DrawBar(self, stage, item, holder, count)
    if item.kind ~= "bar" then
        local tile = Pooled(stage, "box", count, holder)
        tile:ClearAllPoints(); tile:SetAllPoints(holder)
        local style = item.kind == "cast" and self.db.castBar or self.db.resources[item.id]
        local rim = RimColor(style)
        tile.rim:SetShown(rim ~= nil); if rim then Style.Paint(tile.rim, rim) end
        tile.face:SetTexture(nil); Style.Paint(tile.face, item.kind == "cast" and Tone.cast.casting or FILLS[item.id] or Tone.ivory)
        tile:Show()
        return count
    end
    local style = self.db[item.id]
    local entries = self:PreviewEntries(item.id)
    local shown = {}
    for _, entry in ipairs(entries) do if not entry.faded then shown[#shown + 1] = entry end end
    local g = self.Geometry(style, #shown, 1)
    local rim = RimColor(style)
    for index, entry in ipairs(shown) do
        count = count + 1
        local tile = Pooled(stage, "icon", count, holder)
        self.Place(tile, holder, g, index)
        tile.rim:SetShown(rim ~= nil); if rim then Style.Paint(tile.rim, rim) end
        tile.face:SetTexture(entry.icon)
        tile.face:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tile:Show()
    end
    return count
end

-- Draws the stage into the preview `view`; false when the Bar view should
-- show instead (Bar chosen, or nothing to draw).
function M:RenderStage(view, selected)
    local stage = view.stage
    if self.previewMode ~= "layout" or (stage and stage.forceBar) then
        if stage then stage:Hide() end
        return false
    end
    local items = self:StageItems()
    local rects, left, bottom, right, top = {}, math.huge, math.huge, -math.huge, -math.huge
    for _, item in ipairs(items) do
        local l, b, w, h = Rect(item.frame)
        if l then
            rects[#rects + 1] = { item = item, l = l, b = b, w = w, h = h }
            left, bottom = math.min(left, l), math.min(bottom, b)
            right, top = math.max(right, l + w), math.max(top, b + h)
        end
    end
    if #rects == 0 then
        if stage then stage:Hide() end
        return false
    end
    if not stage then
        stage = CreateFrame("Frame", nil, view.frame)
        stage:SetAllPoints()
        stage.pools, stage.holders, stage.hits = {}, {}, {}
        stage.outline = {}
        for i = 1, 4 do stage.outline[i] = stage:CreateTexture(nil, "OVERLAY") end
        view.stage = stage
    end
    view.area:Hide(); if view.hint then view.hint:Hide() end
    stage:Show()
    for _, pool in pairs(stage.pools) do for _, frame in ipairs(pool) do frame:Hide() end end
    for _, frame in ipairs(stage.holders) do frame:Hide() end
    for _, hit in ipairs(stage.hits) do hit:Hide() end
    local width, height = math.max(1, view.frame:GetWidth() - 2 * PAD), math.max(1, view.frame:GetHeight() - CAPTION - 2 * PAD)
    local scale = math.min(width / (right - left), height / (top - bottom), 2)
    local ox = PAD + (width - (right - left) * scale) / 2
    local oy = PAD + (height - (top - bottom) * scale) / 2
    local count, current = 0, nil
    for index, rect in ipairs(rects) do
        local holder = stage.holders[index]
        if not holder then holder = CreateFrame("Frame", nil, stage); stage.holders[index] = holder end
        holder:SetScale(scale)
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", stage, "TOPLEFT", (ox + (rect.l - left) * scale) / scale, -(oy + (top - rect.b - rect.h) * scale) / scale)
        holder:SetSize(rect.w, rect.h)
        holder:Show()
        count = DrawBar(self, stage, rect.item, holder, count)
        -- Click a bar to edit it; point at it for its name.
        local hit = stage.hits[index]
        if not hit then
            hit = CreateFrame("Button", nil, stage)
            hit:SetScript("OnClick", function(button)
                local target = button.item
                if target.kind == "cast" then M:SelectCast()
                elseif target.kind == "resource" then M:SelectResource(target.id) else M:SelectBar(target.id) end
            end)
            hit:SetScript("OnEnter", function(button)
                if not GameTooltip then return end
                GameTooltip:SetOwner(button, "ANCHOR_TOP")
                GameTooltip:SetText(button.label or "")
                GameTooltip:Show()
            end)
            hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            stage.hits[index] = hit
        end
        local item = rect.item
        hit.item = item
        hit.label = (item.kind == "cast" and L[self.CAST_LABEL]) or (item.kind == "resource" and self:ResourceLabel(item.id)) or self:Label(item.id)
        hit:ClearAllPoints(); hit:SetAllPoints(holder); hit:SetScale(scale); hit:Show()
        if item.id == selected then current = holder end
    end
    -- The bar being edited, outlined 3px outside.
    local o = stage.outline
    for _, line in ipairs(o) do Style.Paint(line, Tone.brand); line:SetShown(current ~= nil); line:ClearAllPoints() end
    if current then
        o[1]:SetPoint("BOTTOMLEFT", current, "TOPLEFT", -3, 2); o[1]:SetPoint("BOTTOMRIGHT", current, "TOPRIGHT", 3, 2); o[1]:SetHeight(1)
        o[2]:SetPoint("TOPLEFT", current, "BOTTOMLEFT", -3, -2); o[2]:SetPoint("TOPRIGHT", current, "BOTTOMRIGHT", 3, -2); o[2]:SetHeight(1)
        o[3]:SetPoint("TOPRIGHT", current, "TOPLEFT", -2, 3); o[3]:SetPoint("BOTTOMRIGHT", current, "BOTTOMLEFT", -2, -3); o[3]:SetWidth(1)
        o[4]:SetPoint("TOPLEFT", current, "TOPRIGHT", 2, 3); o[4]:SetPoint("BOTTOMLEFT", current, "BOTTOMRIGHT", 2, -3); o[4]:SetWidth(1)
    end
    stage.count, stage.bars = count, #rects
    view.caption:SetText(L["Layout · click a bar to edit it · Bar shows this bar alone, to click and drag its spells"])
    return true
end

-- The preview's corner: Layout and Bar (the cooldown pages), and Use Bar
-- Style while any of this bar's groups is its own. `opts.custom()` counts
-- them; `opts.useStyle()` follows the Bar Style again.
function M:AddPreviewCorner(page, opts)
    opts = opts or {}
    if not page.previewArea then return end
    local corner = CreateFrame("Frame", nil, page.previewArea)
    corner:SetPoint("TOPRIGHT", page.previewArea, "TOPRIGHT", 0, -4); corner:SetSize(340, 28)
    local use = W.Button(corner, "", 150, 24, "secondary")
    use:SetPoint("RIGHT", 0, 0)
    use:SetScript("OnClick", function() if opts.useStyle then opts.useStyle() end end)
    page.useStyleButton = use
    page.refreshers[#page.refreshers + 1] = function()
        local custom = opts.custom and opts.custom() or 0
        use:SetShown(custom > 0)
        use.label:SetText(string.format(L["Use Bar Style (%d)"], custom))
    end
    if opts.views then
        local function View(mode)
            M.previewMode = mode
            if M.previewView then M.previewView.Refresh() end
            page:Refresh()
        end
        local layout = W.Button(corner, L["Layout"], 70, 24, "choice")
        local bar = W.Button(corner, L["Bar"], 54, 24, "choice")
        bar:SetPoint("RIGHT", use, "LEFT", -12, 0)
        layout:SetPoint("RIGHT", bar, "LEFT", -4, 0)
        layout:SetScript("OnClick", function() View("layout") end)
        bar:SetScript("OnClick", function() View("bar") end)
        page.layoutViewButton, page.barViewButton = layout, bar
        page.refreshers[#page.refreshers + 1] = function()
            layout:SetSelected(M.previewMode == "layout"); bar:SetSelected(M.previewMode ~= "layout")
        end
    end
    page.previewReserveRight = 352
    page:UpdatePreviewLayout()
end
