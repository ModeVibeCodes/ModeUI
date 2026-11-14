local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- The sample fight and the settings preview. Edit Mode, Test on Screen and
-- the preview show a made-up group of Forever's classes (one of them marked
-- as you, for Always Show Me), so a window can be laid out without a fight.
-- Animated plays the fight out over 20 seconds. The preview is the window
-- being edited, drawn by the same code as the real one; clicking its header,
-- bars or frame jumps to those settings.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local DM = addon.Domain.DamageMeter
local SAMPLE_SECONDS, PLAY_SECONDS, MAX_WIDTH, MAX_HEIGHT, CAPTION_HEIGHT = 94, 20, 440, 160, 18
-- The preview is a sample: at most five rows, drawn at most at 80% size, so
-- it stays small however many Rows the window has.
M.PREVIEW_ROWS, M.PREVIEW_SCALE = 5, 0.8

-- Name, class and share of the top amount, best first. Healing meters rank
-- the healers first. An empty class is something without one (a creature).
local DAMAGE = {
    { "Valeria", "MAGE", 1 }, { "Thorgrim", "WARRIOR", 0.93 }, { "Sylwen", "HUNTER", 0.81 },
    { "Mode", "ROGUE", 0.78, true }, { "Ashka", "WARLOCK", 0.68 }, { "Brannoc", "PALADIN", 0.5 },
    { "Tavi", "SHAMAN", 0.41 }, { "Kaelin", "DRUID", 0.29 }, { "Ysolde", "PRIEST", 0.22 }, { "Ember Hound", "", 0.08 },
}
local HEALING = {
    { "Ysolde", "PRIEST", 1 }, { "Kaelin", "DRUID", 0.86 }, { "Tavi", "SHAMAN", 0.74 }, { "Brannoc", "PALADIN", 0.69 },
    { "Mode", "ROGUE", 0.12, true }, { "Thorgrim", "WARRIOR", 0.09 }, { "Valeria", "MAGE", 0.05 }, { "Sylwen", "HUNTER", 0.04 },
}
local TOP = { amount = 1284000, count = 9 }

-- A session shaped like the game's: { sources, max, total, duration, sample }.
-- phase (seconds into the Animated preview) grows the fight; nil is static.
function M:SampleData(meterType, phase)
    local info = DM.typeById[meterType] or DM.types[1]
    local grown = phase and math.min(1, 0.05 + (phase % PLAY_SECONDS) / PLAY_SECONDS) or 1
    local seconds = math.max(1, math.floor(SAMPLE_SECONDS * grown + 0.5))
    local list = info.group == "Healing" and HEALING or DAMAGE
    local top = info.count and TOP.count or TOP.amount
    local sources, total = {}, 0
    for index, item in ipairs(list) do
        if not info.deaths or index <= 3 then
            local amount = math.floor(top * item[3] * grown + 0.5)
            if info.count then amount = math.max(1, math.floor(top * item[3] + 0.5)) end
            sources[#sources + 1] = { name = item[1], classFilename = item[2], totalAmount = amount,
                amountPerSecond = math.floor(amount / seconds + 0.5), isLocalPlayer = item[4] == true,
                deathRecapID = 0, deathTimeSeconds = info.deaths and 41 + index * 13 or 0 }
            total = total + amount
        end
    end
    return { sources = sources, max = sources[1] and sources[1].totalAmount or 0, total = total, duration = seconds, sample = true }
end

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})
-- Test on Screen draws on the real windows; Preview States redraws them.
function M:IsSimulationVisible() return self.testing == true and self.active == true end
function M:Render() self:RenderAll() end

-- The window the settings page is editing, else Window 1.
function M:PreviewWindow()
    local page = self.page
    return page and page.windowEditing and page.windowEditing() or "window1"
end

local function Scale(style)
    local g = M.Geometry(style, 1)
    return math.min(M.PREVIEW_SCALE, MAX_WIDTH / g.width, MAX_HEIGHT / g.height), g
end

-- The window's settings with at most PREVIEW_ROWS rows.
function M:PreviewStyle(window)
    local style = self:Style(window)
    if style.rows <= self.PREVIEW_ROWS then return style end
    local short = {}
    for key, value in pairs(style) do short[key] = value end
    short.rows = self.PREVIEW_ROWS
    return short
end

function M:GetPreviewSize()
    local scale, g = Scale(self:PreviewStyle(self:PreviewWindow()))
    return math.max(300, g.width * scale), g.height * scale + 8 + CAPTION_HEIGHT
end

-- A part that jumps to its settings when clicked and lights up under the
-- mouse; `part` picks the text on the Text tab.
local function Clickable(hit, target, part)
    hit:EnableMouse(true)
    hit.jumpHighlight = W.Fill(hit, T.primary, "OVERLAY", 0, 0.16)
    hit.jumpHighlight:Hide()
    hit:SetScript("OnEnter", function() hit.jumpHighlight:Show() end)
    hit:SetScript("OnLeave", function() hit.jumpHighlight:Hide() end)
    hit:SetScript("OnMouseUp", function(_, button) if button == nil or button == "LeftButton" then M:JumpTo(target, part) end end)
    hit.jump = target
    return hit
end

function M:RenderPreview(view)
    local window = self:PreviewWindow()
    local style = self:PreviewStyle(window)
    local scale = Scale(style)
    local shell = view.window
    shell:SetScale(scale)
    self:PaintShell(shell, style)
    shell:ClearAllPoints(); shell:SetPoint("TOP", view.frame, "TOP", 0, -2 / scale)
    shell:SetAlpha(style.show and style.opacity / 100 or 0.4)
    for _, row in ipairs(shell.rows) do
        if not row.jump then
            row:SetScript("OnClick", nil)
            Clickable(row, "bars")
            row.textHit = Clickable(CreateFrame("Frame", nil, row.textLayer), "text", "name")
            row.valueHit = Clickable(CreateFrame("Frame", nil, row.textLayer), "text", "value")
        end
        row.textHit:ClearAllPoints()
        row.textHit:SetPoint("TOPLEFT", row.bar, "TOPLEFT", 0, 0)
        row.textHit:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOM", 0, 0)
        row.valueHit:ClearAllPoints()
        row.valueHit:SetPoint("TOPLEFT", row.bar, "TOP", 0, 0)
        row.valueHit:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 0, 0)
    end
    local info = DM.typeById[style.meterType]
    local data = self:SampleData(style.meterType, addon.PreviewStates:Sample(self.id))
    self:RenderHeader(shell, style, info, style.session, data)
    self:FillRows(shell, style, info, data)
    view.background:SetAllPoints(shell)
    local caption = L[self.windowLabels[window]] .. " · " .. L["sample fight"]
    if not style.show then caption = L[self.windowLabels[window]] .. " · " .. L["hidden"] end
    view.caption:SetText(caption)
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame }
    view.window = self:BuildShell(frame, nil)
    -- The frame (rim and background) sits under the header and rows.
    view.background = Clickable(CreateFrame("Frame", nil, view.window), "frame")
    view.background:SetFrameLevel(view.window:GetFrameLevel())
    view.window.header:SetFrameLevel(view.window:GetFrameLevel() + 2)
    view.window.header:SetScript("OnClick", nil)
    Clickable(view.window.header, "header")
    -- The title (the left half of the header) opens its text settings.
    local title = Clickable(CreateFrame("Frame", nil, view.window.header.text), "text", "title")
    title:SetPoint("TOPLEFT", view.window.header, "TOPLEFT", 0, 0)
    title:SetPoint("BOTTOMRIGHT", view.window.header, "BOTTOM", 0, 0)
    view.titleHit = title
    -- The header buttons, as on the real window; here they open Header.
    self:BuildControls(view.window)
    for _, button in pairs(view.window.buttons) do button:SetScript("OnClick", function() M:JumpTo("header") end) end
    view.caption = W.Label(frame, "", nil, 0, 0, 260, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a part to open its settings"], nil, 0, 0, 220, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end
