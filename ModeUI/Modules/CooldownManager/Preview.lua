local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The settings preview: the viewer being edited, drawn by the same layout,
-- skin and text code as the real one, with your own tracked spells (their
-- icons and names come from the game's spell data, by cooldown ID). Spells
-- hidden here show faded, so they can be brought back. With nothing tracked
-- yet, sample icons stand in. Clicking an icon opens its spell menu
-- (SpellMenu.lua); while you edit the Cooldown text a sample cooldown runs on
-- the first icon.
local Kit, W, T, L = addon.Kit, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local Cooldowns = addon.Domain.Cooldowns
local SAMPLE_COOLDOWN, STATIC_ELAPSED, HINT_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 8, 3, 18, 560, 200
local SAMPLE_ICON, SAMPLE_COUNT = 134400, 6 -- the question mark icon
local HIDDEN_ALPHA = 0.3

addon.PreviewStates:Register(M.id, {
    states = { { id = "static", label = "Static" }, { id = "animated", label = "Animated" } },
    animated = { animated = true }, previewAnimated = "animated",
    sample = function(_, phase) return phase end,
})

-- The viewer the page is editing, else Essential.
function M:PreviewViewer()
    local page = self.page
    return page and page.viewerEditing and page.viewerEditing() or "essential"
end

-- What the preview shows: { key, icon, name, hidden } per tracked spell, in
-- Blizzard's order, or samples when nothing is tracked.
function M:PreviewEntries(viewer)
    local entries = {}
    for _, item in ipairs(self:Items(viewer)) do
        local key = self:SpellKey(item)
        if key then
            local spell = Cooldowns.SpellID(tonumber(key))
            entries[#entries + 1] = { key = key, icon = spell and Cooldowns.SpellIcon(spell) or SAMPLE_ICON,
                name = self:SpellLabel(key), hidden = self:SpellSwitch(viewer, key, "hide") }
        end
    end
    if #entries > 0 then return entries, true end
    for i = 1, SAMPLE_COUNT do entries[i] = { icon = SAMPLE_ICON, name = string.format(L["Sample %d"], i) } end
    return entries, false
end

local function Scale(style, count)
    local g = M.Geometry(style, count, 1)
    return math.min(1, MAX_WIDTH / g.width, MAX_HEIGHT / g.height), g
end

function M:GetPreviewSize()
    local viewer = self:PreviewViewer()
    local entries = self:PreviewEntries(viewer)
    local scale, g = Scale(self.db[viewer], #entries)
    return math.max(320, g.width * scale), g.height * scale + 8 + HINT_HEIGHT
end

-- A sample that lights up under the mouse and opens its spell menu.
local function Sample(view, index, bar)
    local list = bar and view.bars or view.icons
    local sample = list[index]
    if sample then return sample end
    sample = M:BuildSample(view.holder, bar)
    sample:EnableMouse(true)
    sample.highlight = W.Fill(sample, T.primary, "OVERLAY", 0, 0.16)
    sample.highlight:Hide()
    sample:SetScript("OnEnter", function() sample.highlight:Show() end)
    sample:SetScript("OnLeave", function() sample.highlight:Hide() end)
    sample:SetScript("OnMouseUp", function(_, mouse)
        if mouse ~= nil and mouse ~= "LeftButton" then return end
        M:JumpTo("spells")
        if sample.key then M:OpenSpellMenu(view, sample.key, sample) end
    end)
    list[index] = sample
    return sample
end

-- Fills one sample: icon, texts, a sample cooldown or bar fill.
local function Fill(sample, entry, index, viewer, style, demo, phase)
    local bar = M:IsBar(viewer)
    local icon = bar and sample.Icon.Icon or sample.Icon
    icon:SetTexture(entry.icon)
    sample.key = entry.key
    if bar then
        sample.Bar:SetValue(index == 1 and 0.65 or math.max(0.15, 1 - index * 0.17))
        sample.Bar.Name:SetText(entry.name)
        sample.Bar.Duration:SetText(string.format("%d", 4 + index * 3))
        sample.Icon.Applications:SetText(index == 1 and "2" or "")
        return
    end
    sample.ChargeCount.Current:SetText(index == 1 and "2" or "")
    local cooldown = sample.Cooldown
    if demo and index == 1 then
        local elapsed = phase and phase % SAMPLE_COOLDOWN or STATIC_ELAPSED
        cooldown:SetCooldown(GetTime() - elapsed, SAMPLE_COOLDOWN); cooldown:Show()
        sample.cooldownText:SetText(string.format("%d", math.ceil(SAMPLE_COOLDOWN - elapsed)))
    else
        cooldown:Hide(); sample.cooldownText:SetText("")
    end
end

-- The glow on the icon whose menu is open, as it would show on screen.
local function PreviewGlow(view, sample, viewer, style)
    local chosen = view.menuKey ~= nil and sample.key == view.menuKey and not M:IsBuff(viewer)
    local proc = chosen and M:SpellSwitch(viewer, sample.key, "proc") and (style.procGlow == "mode" or style.procGlow == "border")
    local set = M.glows[sample]
    if proc or (set and set.proc) then
        local glow = M:Glow(sample, "proc")
        if proc then M.PaintGlow(sample, glow, style.procGlow, style.procColor, style.procPulse) end
        glow.wanted = proc
        M:ResolveGlows(sample)
    end
end

function M:RenderPreview(view)
    local viewer = self:PreviewViewer()
    local style, bar = self.db[viewer], self:IsBar(viewer)
    local entries, real = self:PreviewEntries(viewer)
    local scale = Scale(style, #entries)
    view.holder:SetScale(scale)
    local g = self.Geometry(style, #entries, self.PixelSize(view.holder))
    view.holder:SetSize(g.width, g.height)
    view.holder:ClearAllPoints(); view.holder:SetPoint("TOP", view.frame, "TOP", 0, -2 / scale)
    view.holder:SetAlpha(style.show and style.opacity / 100 or 0.4)
    local demo = not bar and self.page ~= nil and self.page.textPart ~= nil and self.page.textPart() == "cooldown"
    local phase = addon.PreviewStates:Sample(self.id)
    for index, entry in ipairs(entries) do
        local sample = Sample(view, index, bar)
        local state = self:Dress(sample)
        state.viewer, state.g = viewer, g
        self.Place(sample, view.holder, g, index)
        if bar then self:SkinBar(sample, style, g, state) else self:SkinIcon(sample, style, g, state) end
        self:StyleTexts(viewer, sample, style, g)
        Fill(sample, entry, index, viewer, style, demo, phase)
        PreviewGlow(view, sample, viewer, style)
        sample:SetAlpha(entry.hidden and HIDDEN_ALPHA or 1)
        sample:Show()
    end
    for _, list in ipairs({ view.icons, view.bars }) do
        for index = 1, #list do
            if list ~= (bar and view.bars or view.icons) or index > #entries then list[index]:Hide() end
        end
    end
    local label = L[self.viewerSpecs[viewer].label]
    local caption = style.show and label or string.format(L["%s is hidden"], label)
    if not real then caption = caption .. " · " .. L["no spells tracked yet"]
    elseif self:HiddenCount(viewer) > 0 then caption = caption .. " · " .. string.format(L["%d hidden"], self:HiddenCount(viewer)) end
    view.caption:SetText(caption)
    self:RefreshSpellMenu()
end

function M:CreateConfigPreview(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    local view = { frame = frame, icons = {}, bars = {} }
    self.previewView = view
    view.holder = CreateFrame("Frame", nil, frame)
    view.caption = W.Label(frame, "", nil, 0, 0, 320, T.muted)
    view.caption:ClearAllPoints(); view.caption:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 2); view.caption:SetJustifyH("LEFT")
    view.hint = W.Label(frame, L["Click a spell for its own switches"], nil, 0, 0, 220, T.faint or T.muted)
    view.hint:ClearAllPoints(); view.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2); view.hint:SetJustifyH("RIGHT")
    function view.Refresh() M:RenderPreview(view) end
    view.RenderSimulation = view.Refresh
    return view
end

-- The tracked spells change with talents and Blizzard's Cooldown Settings;
-- each time Blizzard lays the viewer out again, so does ModeUI, and the open
-- preview follows on the next frame.
function M:QueuePreview(viewer)
    local view, page = self.previewView, self.page
    if not view or not page or not page:IsShown() or viewer ~= self:PreviewViewer() or self.previewQueued then return end
    self.previewQueued = true
    local function Run() M.previewQueued = nil; if M.page and M.page:IsShown() then view.Refresh() end end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end

-- A preview click: show the settings it belongs to.
function M:JumpTo(target, part)
    local page = self.page
    if not page or not page.jumpTargets or not page.jumpTargets[target] then return false end
    if part and page.SetTextPart then page.SetTextPart(part) end
    page:Reveal(page.jumpTargets[target])
    return true
end
